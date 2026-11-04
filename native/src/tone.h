// Repeating, panned ticks for guidance, such as the focus minigame: each of a
// few channels holds one short mono sound and plays it every `interval` ms
// (faster = closer). Timing runs on a private XAudio2 thread, so the game
// thread only stores numbers and the rhythm stays even.
#pragma once
#include <string>

namespace lisr::tone {
constexpr int kChannels = 2;
// Starts the audio thread on first use. Returns false when XAudio2 is unavailable.
bool Start();
// Loads a 16-bit mono PCM WAV into a channel. Returns false when unreadable.
bool Load(int channel, const std::wstring& path);
// pan: -1 (left) .. 1 (right); interval_ms: time between ticks; volume 0..1.
void Set(int channel, bool on, float pan, int interval_ms, float volume);
void StopAll();
std::string Status();
// Pure, for tests: equal-power gains for a pan value.
void Gains(float pan, float& left, float& right);
// Pure, for tests: parses a 16-bit mono PCM WAV. rate is set; false on failure.
bool ParseWav(const std::string& bytes, int& rate, std::string& samples);
} // namespace lisr::tone
