// LISRemasteredAccess native speech module.
// Loaded from Lua with package.loadlib; each export is a lua_CFunction.
// Prism runs on one dedicated worker thread: Lua may call from the game thread
// or UE4SS's async thread, and a stalled screen-reader RPC must never block the game.
#include "lua_bridge.h"
#include "speech.h"
#include <Windows.h>
#include <Xinput.h>
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
    using GetState = DWORD(WINAPI*)(DWORD, XINPUT_STATE*);
    static GetState get = [] {
        for (const wchar_t* name : {L"xinput1_4.dll", L"xinput1_3.dll", L"xinput9_1_0.dll"}) {
            if (HMODULE m = LoadLibraryExW(name, nullptr, LOAD_LIBRARY_SEARCH_SYSTEM32))
                if (auto f = reinterpret_cast<GetState>(GetProcAddress(m, "XInputGetState"))) return f;
        }
        return static_cast<GetState>(nullptr);
    }();
    int64_t buttons = -1;
    if (get) {
        for (DWORD i = 0; i < 4; ++i) {
            XINPUT_STATE pad{};
            if (get(i, &pad) == ERROR_SUCCESS) { buttons = pad.Gamepad.wButtons; break; }
        }
    }
    Lua(state).set_integer(buttons);
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
