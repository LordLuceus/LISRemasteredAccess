#pragma once
#include <cstdint>
#include <string>
#include <string_view>

// Prism speech/braille output, ported from LISAccess's output layer.
// All calls must come from one thread (the thread that called Initialize).
namespace lisr::speech {
bool Initialize();
// Speaks UTF-8 text and mirrors it to braille when the backend supports it.
// Returns false when no backend could speak it.
bool Speak(std::string_view utf8, bool interrupt);
void Stop();
void Shutdown();
// The active backend's name, or empty when none is ready.
std::string BackendName();
// Called for diagnostics: one stable key=value line per event, never the text.
using LogSink = void (*)(const std::string& line);
void SetLogSink(LogSink sink);
}
