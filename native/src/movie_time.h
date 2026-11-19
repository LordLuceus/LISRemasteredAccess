#pragma once
#include "rewind_snapshot.h"
#include <array>
#include <cstring>

namespace lisr::movie {
inline constexpr uintptr_t getter_rva = 0x1e5db30;
inline constexpr uintptr_t class_rva = 0x36c7fc0;
// Entire native getter: RCX=UMediaPlayer*, RDX=caller-owned FTimespan*,
// RAX=the same output pointer. execGetTime 0x1e66070 proves the convention.
inline constexpr unsigned char getter_bytes[] = {
    0x40,0x53,0x48,0x83,0xec,0x20,0x48,0x8b,0x89,0x10,0x01,0x00,0x00,
    0x48,0x8b,0xda,0xe8,0xcb,0xb0,0xfc,0xff,0x48,0x8b,0xc3,0x48,0x83,0xc4,0x20,0x5b,0xc3};
struct Result { const char* status; double seconds = 0; };
template<class Memory, class Invoke>
Result sample(Memory& memory, uintptr_t base, bool pinned_module, uintptr_t player, uintptr_t klass, Invoke&& invoke) {
    if (!pinned_module || !base) return {"module"};
    std::array<unsigned char, sizeof(getter_bytes)> bytes{};
    if (!memory(base + getter_rva, bytes.data(), bytes.size()) ||
        std::memcmp(bytes.data(), getter_bytes, bytes.size())) return {"signature"};
    // Addresses are raw live objects, not weak handles: serial zero is legal.
    constexpr uintptr_t max_address = 0x00007ffffffff000ULL;
    if (!player || !klass || player > max_address || klass > max_address || (player & 7) || (klass & 7)) return {"object"};
    rewind::Reader reader(memory, base);
    if (!reader.valid_object(player) || !reader.valid_object(klass)) return {"object"};
    uintptr_t expected{}, actual{}, facade{}, readable{};
    if (!memory(base + class_rva, &expected, 8) || expected != klass ||
        !memory(player + 16, &actual, 8) || actual != klass) return {"class"};
    if (!memory(player + 0x110, &facade, 8) || !facade || facade > max_address || (facade & 7) ||
        !memory(facade + 0x120, &readable, 8)) return {"facade"};
    int64_t ticks = -1; // scoped owned eight-byte result; no engine/Lua struct retained
    if (!invoke(base + getter_rva, player, ticks)) return {"getter"};
    const double seconds = static_cast<double>(ticks) * 1e-7;
    if (ticks < 0 || !std::isfinite(seconds)) return {"clock"};
    return {"ok", seconds};
}
} // namespace lisr::movie
