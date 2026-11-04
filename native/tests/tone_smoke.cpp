// Pan maths, WAV parsing, voice start-up, and (without --quiet) two seconds of
// ticks: a slow left tick speeding up, then a right one.
#include "../src/tone.h"
#include <Windows.h>
#include <cmath>
#include <cstdio>
#include <cstring>
#include <string>

int main(int argc, char** argv) {
    const bool quiet = argc > 1 && std::strcmp(argv[1], "--quiet") == 0;
    int fails = 0;
    auto close = [](float a, float b) { return std::fabs(a - b) < 0.001f; };
    float l = 0, r = 0;
    lisr::tone::Gains(0, l, r);
    if (!close(l, r) || !close(l * l + r * r, 1)) { std::printf("FAIL centre is not equal power\n"); ++fails; }
    lisr::tone::Gains(-1, l, r);
    if (!close(l, 1) || !close(r, 0)) { std::printf("FAIL full left\n"); ++fails; }
    // Minimal 16-bit mono WAV: 4 samples at 24000 Hz.
    std::string w = std::string("RIFF") + std::string(4, '\0') + "WAVEfmt ";
    auto le = [](uint32_t v, int bytes) { std::string s; for (int i = 0; i < bytes; ++i) s += static_cast<char>((v >> (8 * i)) & 0xff); return s; };
    w += le(16, 4) + le(1, 2) + le(1, 2) + le(24000, 4) + le(48000, 4) + le(2, 2) + le(16, 2) + "data" + le(8, 4) + std::string(8, '\1');
    int rate = 0; std::string pcm;
    if (!lisr::tone::ParseWav(w, rate, pcm) || rate != 24000 || pcm.size() != 8) { std::printf("FAIL wav parse\n"); ++fails; }
    std::string stereo = w; stereo[22] = 2;
    if (lisr::tone::ParseWav(stereo, rate, pcm)) { std::printf("FAIL stereo accepted\n"); ++fails; }
    if (!lisr::tone::Start()) { std::printf("FAIL voice: %s\n", lisr::tone::Status().c_str()); ++fails; }
    else if (!quiet && argc > 2) {
        std::wstring a(argv[2], argv[2] + std::strlen(argv[2]));
        if (lisr::tone::Load(0, a)) {
            for (int i = 0; i <= 20; ++i) { lisr::tone::Set(0, true, -0.4f, 700 - i * 30, 0.8f); Sleep(100); }
            lisr::tone::StopAll(); Sleep(200);
        } else { std::printf("FAIL load %s\n", argv[2]); ++fails; }
    }
    std::printf("tone_smoke %s status=%s\n", fails ? "FAILED" : "ok", lisr::tone::Status().c_str());
    return fails ? 1 : 0;
}
