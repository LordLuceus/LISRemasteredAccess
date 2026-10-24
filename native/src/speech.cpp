#include "speech.h"
#include <prism.h>
#include <Windows.h>
#include <algorithm>
#include <vector>

namespace lisr::speech {
static_assert(sizeof(PrismBackendFeature) == 8, "Prism feature enum requires /Zc:enumTypes");
namespace {
// Screen-reader RPC backends can disappear mid-call. Keep structured exception
// handling outside frames that own C++ objects, and never let it reach the game.
template <class R, class F, class... Args> R Guard(R failure, F function, Args... args) {
    __try { return function(args...); }
    __except (EXCEPTION_EXECUTE_HANDLER) { return failure; }
}
template <class F, class... Args> void GuardVoid(F function, Args... args) {
    __try { function(args...); }
    __except (EXCEPTION_EXECUTE_HANDLER) {}
}
PrismContext* InitContext() {
    auto config = prism_config_init();
    return Guard(static_cast<PrismContext*>(nullptr), prism_init, &config);
}
const char* SafeName(PrismBackend* b) {
    const char* n = Guard(static_cast<const char*>(nullptr), prism_backend_name, b);
    return n ? n : "unknown";
}

struct Backend {
    PrismBackendId id = PRISM_BACKEND_INVALID;
    int priority = 0;
    PrismBackend* handle = nullptr;
    uint64_t features = 0;
    bool ready = false;
    PrismError speechError = PRISM_OK, brailleError = PRISM_OK;
};
PrismContext* context = nullptr;
std::vector<Backend> backends;
PrismBackendId active = PRISM_BACKEND_INVALID;
std::string activeName;
bool initialized = false;
DWORD ownerThread = 0;
LogSink sink = nullptr;

void Log(const std::string& line) {
    if (sink) sink(line);
}
void Release(Backend& b) {
    if (b.handle) GuardVoid(prism_backend_free, b.handle);
    b.handle = nullptr;
    b.ready = false;
    b.features = 0;
}
bool Ready(Backend& b) {
    if (!b.handle) b.handle = Guard(static_cast<PrismBackend*>(nullptr), prism_registry_acquire, context, b.id);
    if (!b.handle) return false;
    b.features = Guard(uint64_t{0}, prism_backend_get_features, b.handle);
    constexpr uint64_t required = PRISM_BACKEND_IS_SUPPORTED_AT_RUNTIME | PRISM_BACKEND_SUPPORTS_SPEAK;
    if ((b.features & required) != required) {
        // Drop stale RPC bindings when a reader exits, so a restart gets a fresh one.
        Release(b);
        return false;
    }
    if (!b.ready) {
        const auto r = Guard(PRISM_ERROR_BACKEND_NOT_AVAILABLE, prism_backend_initialize, b.handle);
        if (r != PRISM_OK && r != PRISM_ERROR_ALREADY_INITIALIZED) {
            Release(b);
            return false;
        }
        b.ready = true;
    }
    return true;
}
void Selected(Backend& b) {
    if (active == b.id) return;
    active = b.id;
    activeName = SafeName(b.handle);
    Log("event=speech_backend provider=prism backend=" + activeName + " braille=" +
        std::to_string((b.features & PRISM_BACKEND_SUPPORTS_BRAILLE) != 0));
}
void Report(Backend& b, const char* channel, PrismError result, PrismError& last) {
    if (result != PRISM_OK && result != last)
        Log(std::string("event=") + channel + "_failed backend=" + SafeName(b.handle) +
            " code=" + std::to_string(static_cast<int>(result)));
    last = result;
}
bool Owner() { return initialized && ownerThread == GetCurrentThreadId(); }
} // namespace

void SetLogSink(LogSink s) { sink = s; }

bool Initialize() {
    if (initialized) return ownerThread == GetCurrentThreadId();
    initialized = true;
    ownerThread = GetCurrentThreadId();
    context = InitContext();
    if (!context) {
        Log("event=speech_failed reason=initialization");
        return false;
    }
    const size_t count = Guard(size_t{0}, prism_registry_count, context);
    for (size_t i = 0; i < count && i < 64; ++i) {
        const auto id = Guard(PRISM_BACKEND_INVALID, prism_registry_id_at, context, i);
        if (id != PRISM_BACKEND_INVALID) backends.push_back({id, Guard(0, prism_registry_priority, context, id)});
    }
    std::stable_sort(backends.begin(), backends.end(), [](const Backend& a, const Backend& b) {
        if (a.priority != b.priority) return a.priority > b.priority;
        // Keep SAPI as the preferred system-speech fallback on a priority tie.
        return a.id == PRISM_BACKEND_SAPI && b.id != PRISM_BACKEND_SAPI;
    });
    for (auto& b : backends)
        if (Ready(b)) {
            Selected(b);
            return true;
        }
    Log("event=speech_failed reason=no_available_backend");
    return true; // A reader may start later; Speak re-checks availability each time.
}

bool Speak(std::string_view utf8, bool interrupt) {
    if (!Owner() || !context || utf8.empty()) return false;
    const std::string text(utf8);
    for (auto& b : backends) {
        if (!Ready(b)) continue;
        if (interrupt && active != b.id)
            for (auto& previous : backends)
                if (previous.id == active && previous.ready && previous.handle)
                    (void)Guard(PRISM_ERROR_BACKEND_NOT_AVAILABLE, prism_backend_stop, previous.handle);
        // Speech and braille results are separate: a braille failure after
        // successful speech must not cause the next backend to speak it again.
        const auto speech = Guard(PRISM_ERROR_BACKEND_NOT_AVAILABLE, prism_backend_speak, b.handle, text.c_str(), interrupt);
        Report(b, "speech", speech, b.speechError);
        if (b.features & PRISM_BACKEND_SUPPORTS_BRAILLE) {
            const auto braille = Guard(PRISM_ERROR_BACKEND_NOT_AVAILABLE, prism_backend_braille, b.handle, text.c_str());
            Report(b, "braille", braille, b.brailleError);
        }
        if (speech == PRISM_OK) {
            Selected(b);
            return true;
        }
        Release(b);
    }
    active = PRISM_BACKEND_INVALID;
    activeName.clear();
    Log("event=speech_failed reason=all_backends_failed");
    return false;
}

void Stop() {
    if (!Owner()) return;
    for (auto& b : backends)
        if (b.id == active && b.ready && b.handle)
            (void)Guard(PRISM_ERROR_BACKEND_NOT_AVAILABLE, prism_backend_stop, b.handle);
}

std::string BackendName() { return Owner() ? activeName : std::string(); }

void Shutdown() {
    if (!Owner()) return;
    for (auto& b : backends) {
        if (b.ready && b.handle) (void)Guard(PRISM_ERROR_BACKEND_NOT_AVAILABLE, prism_backend_stop, b.handle);
        Release(b);
    }
    backends.clear();
    active = PRISM_BACKEND_INVALID;
    activeName.clear();
    if (context) GuardVoid(prism_shutdown, context);
    context = nullptr;
    initialized = false;
    ownerThread = 0;
}
} // namespace lisr::speech
