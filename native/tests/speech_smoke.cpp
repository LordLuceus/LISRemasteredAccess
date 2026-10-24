// Verifies Prism initializes, finds a backend, and SAPI accepts literal text.
// --quiet speaks nothing aloud; it checks registration and SAPI rendering to memory.
#include <prism.h>
#include <cstdio>
#include <cstring>
#include "../src/speech.h"

namespace {
void PRISM_CALL Capture(void* data, const float*, size_t samples, size_t, size_t) {
    *static_cast<size_t*>(data) += samples;
}
void Print(const std::string& line) { std::printf("%s\n", line.c_str()); }
}

int main(int argc, char** argv) {
    static_assert(sizeof(void*) == 8, "The remaster speech module must be x64");
    const bool quiet = argc > 1 && std::strcmp(argv[1], "--quiet") == 0;
    auto config = prism_config_init();
    PrismContext* context = prism_init(&config);
    if (!context) return 1;
    bool nvda = false, sapi = false;
    const size_t count = prism_registry_count(context);
    for (size_t i = 0; i < count; ++i) {
        const auto id = prism_registry_id_at(context, i);
        nvda |= id == PRISM_BACKEND_NVDA;
        sapi |= id == PRISM_BACKEND_SAPI;
    }
    std::printf("x64 registered_backends=%zu nvda=%d sapi=%d\n", count, nvda, sapi);
    if (!nvda || !sapi) return 2;
    PrismBackend* backend = prism_registry_acquire(context, PRISM_BACKEND_SAPI);
    const auto init = backend ? prism_backend_initialize(backend) : PRISM_ERROR_BACKEND_NOT_AVAILABLE;
    size_t samples = 0;
    // Literal text containing '<' must render, not be parsed as SAPI XML.
    const auto literal = init == PRISM_OK ? prism_backend_speak_to_memory(backend, "<not valid XML", Capture, &samples) : init;
    std::printf("sapi_initialize=%d sapi_literal_text=%d samples=%zu\n", (int)init, (int)literal, samples);
    if (backend) prism_backend_free(backend);
    prism_shutdown(context);
    if (init != PRISM_OK && init != PRISM_ERROR_ALREADY_INITIALIZED) return 3;
    if (literal != PRISM_OK || samples == 0) return 4;
    lisr::speech::SetLogSink(Print);
    if (!lisr::speech::Initialize()) return 5;
    std::printf("selected_backend=%s\n", lisr::speech::BackendName().c_str());
    if (!quiet && !lisr::speech::Speak("Life is Strange Remastered speech module test.", true)) return 6;
    lisr::speech::Shutdown();
    return 0;
}
