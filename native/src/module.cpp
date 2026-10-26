// LISRemasteredAccess native speech module.
// Loaded from Lua with package.loadlib; each export is a lua_CFunction.
// Prism runs on one dedicated worker thread so that a stalled screen-reader RPC
// never blocks the game thread, where all of the mod's Lua runs.
#include "lua_bridge.h"
#include "speech.h"
#include <Windows.h>
#include <Xinput.h>
#include <mmsystem.h>
#include <atomic>
#include <condition_variable>
#include <cstdio>
#include <deque>
#include <mutex>
#include <string>
#include <thread>

using RC::LuaMadeSimple::Lua;

namespace {
struct Item {
    std::string text;
    bool interrupt;
    bool stop;
};
std::mutex mutex;
std::condition_variable wake;
std::deque<Item> queue;
std::once_flag started;
std::string backend; // guarded by mutex
std::atomic<uint64_t> spoken{0}, failed{0};
std::wstring logPath;

void AppendLog(const std::string& line) {
    if (logPath.empty()) return;
    FILE* f = nullptr;
    if (_wfopen_s(&f, logPath.c_str(), L"a") == 0 && f) {
        SYSTEMTIME t;
        GetLocalTime(&t);
        std::fprintf(f, "%02u:%02u:%02u.%03u %s\n", t.wHour, t.wMinute, t.wSecond, t.wMilliseconds, line.c_str());
        std::fclose(f);
    }
}
void Worker() {
    lisr::speech::SetLogSink(AppendLog);
    lisr::speech::Initialize();
    {
        std::lock_guard lock(mutex);
        backend = lisr::speech::BackendName();
    }
    AppendLog("event=worker_ready backend=" + lisr::speech::BackendName());
    for (;;) {
        Item item;
        {
            std::unique_lock lock(mutex);
            wake.wait(lock, [] { return !queue.empty(); });
            item = std::move(queue.front());
            queue.pop_front();
        }
        if (item.stop) {
            lisr::speech::Stop();
            continue;
        }
        const bool ok = lisr::speech::Speak(item.text, item.interrupt);
        (ok ? spoken : failed).fetch_add(1);
        std::lock_guard lock(mutex);
        backend = lisr::speech::BackendName();
    }
}
void EnsureWorker() {
    std::call_once(started, [] { std::thread(Worker).detach(); });
}
void Enqueue(Item item) {
    EnsureWorker();
    {
        std::lock_guard lock(mutex);
        // An interrupting readout replaces everything still waiting.
        if (item.interrupt || item.stop) queue.clear();
        if (queue.size() >= 64) queue.pop_front(); // bound memory if output stalls
        queue.push_back(std::move(item));
    }
    wake.notify_one();
}
} // namespace

// XInput state of the first connected controller; false when none.
namespace {
bool ReadPad(XINPUT_STATE& out) {
    using GetState = DWORD(WINAPI*)(DWORD, XINPUT_STATE*);
    static GetState get = [] {
        for (const wchar_t* name : {L"xinput1_4.dll", L"xinput1_3.dll", L"xinput9_1_0.dll"}) {
            if (HMODULE m = LoadLibraryExW(name, nullptr, LOAD_LIBRARY_SEARCH_SYSTEM32))
                if (auto f = reinterpret_cast<GetState>(GetProcAddress(m, "XInputGetState"))) return f;
        }
        return static_cast<GetState>(nullptr);
    }();
    if (!get) return false;
    for (DWORD i = 0; i < 4; ++i) {
        out = {};
        if (get(i, &out) == ERROR_SUCCESS) return true;
    }
    return false;
}
} // namespace

extern "C" {
// lisr_speak(text [, interrupt=true]) -> true when queued.
__declspec(dllexport) int lisr_speak(lua_State* state) {
    Lua lua(state);
    if (lua.get_stack_size() < 1 || !lua.is_string(1)) {
        lua.set_bool(false);
        return 1;
    }
    std::string text(lua.get_string(1)); // copy before any further Lua call
    bool interrupt = true;
    if (lua.get_stack_size() >= 1 && lua.is_bool(1)) interrupt = lua.get_bool(1);
    const bool queued = !text.empty();
    if (queued) Enqueue({std::move(text), interrupt, false});
    lua.set_bool(queued);
    return 1;
}
// lisr_stop() -> true.
__declspec(dllexport) int lisr_stop(lua_State* state) {
    Enqueue({{}, true, true});
    Lua(state).set_bool(true);
    return 1;
}
// lisr_pad() -> XInput button bits of the first connected controller, or -1
// when none is connected or XInput is unavailable. Read-only hardware polling,
// the same way the original mod read controller buttons; the game is unaffected.
__declspec(dllexport) int lisr_pad(lua_State* state) {
    XINPUT_STATE pad{};
    Lua(state).set_integer(ReadPad(pad) ? static_cast<int64_t>(pad.Gamepad.wButtons) : -1);
    return 1;
}
// lisr_move() -> true while the player is giving movement input to the game:
// W, A, S, D or an arrow key held, or the left stick pushed past XInput's own
// dead zone. Only while the game window is in the foreground, so typing in
// another window never counts. Read-only.
__declspec(dllexport) int lisr_move(lua_State* state) {
    bool moving = false;
    DWORD pid = 0;
    if (HWND fg = GetForegroundWindow()) GetWindowThreadProcessId(fg, &pid);
    if (pid == GetCurrentProcessId()) {
        static const int keys[] = {'W', 'A', 'S', 'D', VK_UP, VK_DOWN, VK_LEFT, VK_RIGHT};
        for (int vk : keys)
            if (GetAsyncKeyState(vk) & 0x8000) { moving = true; break; }
        XINPUT_STATE pad{};
        if (!moving && ReadPad(pad)) {
            const int x = pad.Gamepad.sThumbLX, y = pad.Gamepad.sThumbLY;
            const int dz = XINPUT_GAMEPAD_LEFT_THUMB_DEADZONE;
            moving = x > dz || x < -dz || y > dz || y < -dz;
        }
    }
    Lua(state).set_bool(moving);
    return 1;
}
// lisr_keys(vk1, vk2, ...) -> a bit mask of which listed virtual keys are held
// (bit 0 for vk1), plus bit 30 Shift and bit 31 Ctrl. Zero unless the game
// window is in the foreground, so typing elsewhere never counts. Read-only.
// The Lua side turns these into presses on its own game-thread loop: keys are
// polled there instead of using UE4SS key binds, whose callbacks run Lua on
// the loader's event thread without the game-thread lock (a cross-thread race
// on the Lua state).
__declspec(dllexport) int lisr_keys(lua_State* state) {
    Lua lua(state);
    int64_t mask = 0;
    DWORD pid = 0;
    if (HWND fg = GetForegroundWindow()) GetWindowThreadProcessId(fg, &pid);
    if (pid == GetCurrentProcessId()) {
        // get_integer removes the value it reads, so always read argument 1.
        const int n = lua.get_stack_size();
        for (int i = 0; i < n && i < 30; ++i) {
            if (!lua.is_integer(1)) break;
            const int64_t vk = lua.get_integer(1);
            // 0x8000: held now; 0x0001: pressed since the previous call, so a
            // tap shorter than the 50 ms poll is not lost.
            if (vk > 0 && vk < 256 && (GetAsyncKeyState(static_cast<int>(vk)) & 0x8001)) mask |= (int64_t{1} << i);
        }
        if (GetAsyncKeyState(VK_SHIFT) & 0x8000) mask |= int64_t{1} << 30;
        if (GetAsyncKeyState(VK_CONTROL) & 0x8000) mask |= int64_t{1} << 31;
    }
    lua.set_integer(mask);
    return 1;
}
// lisr_play(path) -> true when playback started. Plays a WAV file
// asynchronously through the default output device (PlaySound), replacing any
// cue still playing. Never blocks the game thread.
__declspec(dllexport) int lisr_play(lua_State* state) {
    Lua lua(state);
    bool ok = false;
    if (lua.get_stack_size() >= 1 && lua.is_string(1)) {
        std::string path(lua.get_string(1));
        const int n = MultiByteToWideChar(CP_UTF8, 0, path.c_str(), static_cast<int>(path.size()), nullptr, 0);
        std::wstring wide(n, L'\0');
        MultiByteToWideChar(CP_UTF8, 0, path.c_str(), static_cast<int>(path.size()), wide.data(), n);
        ok = PlaySoundW(wide.c_str(), nullptr, SND_FILENAME | SND_ASYNC | SND_NODEFAULT) != FALSE;
    }
    lua.set_bool(ok);
    return 1;
}
// lisr_status() -> "backend=<name> spoken=<n> failed=<n>" (diagnostics only).
__declspec(dllexport) int lisr_status(lua_State* state) {
    EnsureWorker();
    std::string name;
    {
        std::lock_guard lock(mutex);
        name = backend;
    }
    const std::string s = "backend=" + (name.empty() ? std::string("none") : name) +
                          " spoken=" + std::to_string(spoken.load()) + " failed=" + std::to_string(failed.load());
    Lua(state).set_string(s);
    return 1;
}
}

BOOL APIENTRY DllMain(HMODULE module, DWORD reason, LPVOID) {
    if (reason == DLL_PROCESS_ATTACH) {
        DisableThreadLibraryCalls(module);
        wchar_t path[MAX_PATH];
        const DWORD n = GetModuleFileNameW(module, path, MAX_PATH);
        if (n > 0 && n < MAX_PATH) {
            logPath.assign(path, n);
            const auto slash = logPath.find_last_of(L"\\/");
            logPath = logPath.substr(0, slash + 1) + L"lisr_speech.log";
        }
    }
    return TRUE;
}
