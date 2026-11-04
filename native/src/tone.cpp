#include "tone.h"
#include <Windows.h>
#include <xaudio2.h>
#include <algorithm>
#include <array>
#include <atomic>
#include <cmath>
#include <cstring>
#include <fstream>
#include <iterator>
#include <mutex>
#include <thread>
#include <vector>

namespace lisr::tone {
namespace {
constexpr float kPi = 3.14159265358979f;
constexpr int kSlots = 4; // stereo buffers in rotation per channel

struct Channel {
    std::mutex mutex;              // guards mono/rate/pending
    std::vector<int16_t> mono;
    int rate = 0;
    bool pending = false;          // a new sound needs a voice
    std::atomic<bool> on{false};
    std::atomic<float> pan{0}, volume{0.5f};
    std::atomic<int> interval{500};
    // Audio thread only:
    IXAudio2SourceVoice* voice = nullptr;
    int voiceRate = 0;
    std::array<std::vector<int16_t>, kSlots> stereo;
    int slot = 0;
    ULONGLONG next = 0;
};
std::array<Channel, kChannels> channels;
std::once_flag started;
std::atomic<bool> ready{false};
std::mutex statusMutex;
std::string status = "not started";

void SetStatus(const std::string& s) {
    std::lock_guard lock(statusMutex);
    status = s;
}

void Run() {
    if (FAILED(CoInitializeEx(nullptr, COINIT_MULTITHREADED))) { SetStatus("com failed"); return; }
    IXAudio2* engine = nullptr;
    IXAudio2MasteringVoice* master = nullptr;
    if (FAILED(XAudio2Create(&engine, 0, XAUDIO2_DEFAULT_PROCESSOR))) { SetStatus("xaudio2 create failed"); return; }
    if (FAILED(engine->CreateMasteringVoice(&master))) { SetStatus("mastering voice failed"); engine->Release(); return; }
    SetStatus("ok");
    ready = true;
    for (;;) {
        const ULONGLONG now = GetTickCount64();
        for (auto& c : channels) {
            std::vector<int16_t> mono;
            int rate = 0;
            {
                std::lock_guard lock(c.mutex);
                if (c.pending) {
                    c.pending = false;
                    if (c.voice && c.voiceRate != c.rate) { c.voice->DestroyVoice(); c.voice = nullptr; }
                    if (!c.voice && c.rate > 0) {
                        WAVEFORMATEX fmt{};
                        fmt.wFormatTag = WAVE_FORMAT_PCM;
                        fmt.nChannels = 2;
                        fmt.nSamplesPerSec = c.rate;
                        fmt.wBitsPerSample = 16;
                        fmt.nBlockAlign = 4;
                        fmt.nAvgBytesPerSec = c.rate * 4;
                        if (SUCCEEDED(engine->CreateSourceVoice(&c.voice, &fmt))) { c.voice->Start(0); c.voiceRate = c.rate; }
                        else SetStatus("source voice failed");
                    }
                }
                if (!c.on || !c.voice || c.mono.empty() || now < c.next) continue;
                mono = c.mono;
                rate = c.rate;
            }
            (void)rate;
            float gl = 0, gr = 0;
            Gains(c.pan.load(), gl, gr);
            const float vol = std::clamp(c.volume.load(), 0.0f, 1.0f);
            auto& buf = c.stereo[c.slot];
            c.slot = (c.slot + 1) % kSlots;
            buf.resize(mono.size() * 2);
            for (size_t i = 0; i < mono.size(); ++i) {
                buf[i * 2] = static_cast<int16_t>(mono[i] * gl * vol);
                buf[i * 2 + 1] = static_cast<int16_t>(mono[i] * gr * vol);
            }
            XAUDIO2_BUFFER xb{};
            xb.AudioBytes = static_cast<UINT32>(buf.size() * sizeof(int16_t));
            xb.pAudioData = reinterpret_cast<const BYTE*>(buf.data());
            c.voice->SubmitSourceBuffer(&xb);
            c.next = now + static_cast<ULONGLONG>(std::max(40, c.interval.load()));
        }
        Sleep(2);
    }
}
} // namespace

void Gains(float pan, float& left, float& right) {
    const float p = (std::clamp(pan, -1.0f, 1.0f) + 1) * 0.25f * kPi; // 0..pi/2
    left = std::cos(p);
    right = std::sin(p);
}

bool ParseWav(const std::string& b, int& rate, std::string& samples) {
    auto u16 = [&](size_t o) { return static_cast<uint16_t>(static_cast<uint8_t>(b[o]) | static_cast<uint8_t>(b[o + 1]) << 8); };
    auto u32 = [&](size_t o) { return static_cast<uint32_t>(u16(o)) | static_cast<uint32_t>(u16(o + 2)) << 16; };
    if (b.size() < 12 || b.compare(0, 4, "RIFF") != 0 || b.compare(8, 4, "WAVE") != 0) return false;
    bool fmtOk = false;
    for (size_t o = 12; o + 8 <= b.size();) {
        const std::string id = b.substr(o, 4);
        const uint32_t len = u32(o + 4);
        if (o + 8 + len > b.size()) return false;
        if (id == "fmt ") {
            if (len < 16 || u16(o + 8) != 1 || u16(o + 10) != 1 || u16(o + 22) != 16) return false;
            rate = static_cast<int>(u32(o + 12));
            fmtOk = true;
        } else if (id == "data" && fmtOk) {
            samples = b.substr(o + 8, len);
            return rate > 0 && !samples.empty();
        }
        o += 8 + len + (len & 1);
    }
    return false;
}

bool Start() {
    std::call_once(started, [] { std::thread(Run).detach(); });
    for (int i = 0; i < 50 && !ready; ++i) Sleep(2);
    return ready.load();
}

bool Load(int channel, const std::wstring& path) {
    if (channel < 0 || channel >= kChannels) return false;
    std::ifstream f(path, std::ios::binary);
    if (!f) return false;
    const std::string bytes((std::istreambuf_iterator<char>(f)), std::istreambuf_iterator<char>());
    int rate = 0;
    std::string raw;
    if (!ParseWav(bytes, rate, raw)) return false;
    auto& c = channels[channel];
    std::lock_guard lock(c.mutex);
    c.mono.assign(raw.size() / 2, 0);
    std::memcpy(c.mono.data(), raw.data(), c.mono.size() * 2);
    c.rate = rate;
    c.pending = true;
    return true;
}

void Set(int channel, bool on, float pan, int interval_ms, float volume) {
    if (channel < 0 || channel >= kChannels) return;
    auto& c = channels[channel];
    c.pan = pan;
    c.interval = interval_ms;
    c.volume = volume;
    c.on = on;
}

void StopAll() {
    for (auto& c : channels) c.on = false;
}

std::string Status() {
    std::lock_guard lock(statusMutex);
    return status;
}
} // namespace lisr::tone
