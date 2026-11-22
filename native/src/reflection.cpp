// Version-pinned property reader. Separate DLL; never includes the scalar speech Lua mirror.
#include "reflection_abi.h"
#include "reflection_protocol.h"
#include <windows.h>
#include <bcrypt.h>
#include <array>
#include <limits>
#include <cstring>
#include <locale>
#include <sstream>
#include <iomanip>
#include "rewind_snapshot.h"
#include "movie_time.h"
using RC::LuaMadeSimple::Lua;
namespace {
bool exact_module(HMODULE module, const unsigned char (&expected)[32]) noexcept {
    if (!module) return false;
    wchar_t path[32768]{};
    auto n = GetModuleFileNameW(module, path, 32768);
    if (!n || n >= 32768) return false;
    HANDLE file = CreateFileW(path, GENERIC_READ, FILE_SHARE_READ, nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (file == INVALID_HANDLE_VALUE) return false;
    BCRYPT_ALG_HANDLE algorithm{}; BCRYPT_HASH_HANDLE hash{};
    bool ok = BCryptOpenAlgorithmProvider(&algorithm, BCRYPT_SHA256_ALGORITHM, nullptr, 0) >= 0;
    if (ok) ok = BCryptCreateHash(algorithm, &hash, nullptr, 0, nullptr, 0, 0) >= 0;
    std::array<unsigned char, 65536> buffer{};
    DWORD count{};
    while (ok) {
        if (!ReadFile(file, buffer.data(), DWORD(buffer.size()), &count, nullptr)) { ok = false; break; }
        if (!count) break;
        ok = BCryptHashData(hash, buffer.data(), count, 0) >= 0;
    }
    std::array<unsigned char, 32> digest{};
    if (ok) ok = BCryptFinishHash(hash, digest.data(), DWORD(digest.size()), 0) >= 0;
    for (size_t i=0; ok && i<digest.size(); ++i) ok = digest[i] == expected[i];
    if (hash) BCryptDestroyHash(hash);
    if (algorithm) BCryptCloseAlgorithmProvider(algorithm, 0);
    CloseHandle(file);
    return ok;
}
bool exact_loader() noexcept {
    HMODULE module{};
    if (!GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
            reinterpret_cast<LPCWSTR>(&RC::LuaType::push_arrayproperty), &module)) return false;
    constexpr unsigned char expected[] = {0xce,0x5e,0x3c,0x46,0xa9,0x20,0xcc,0x00,0xb2,0x81,0x7a,0xc6,0x1e,0x43,0x8c,0x91,0x62,0x83,0x02,0x90,0x37,0x9d,0x0b,0x5b,0x9c,0x4d,0xfc,0x2b,0x29,0x45,0x92,0x90};
    return exact_module(module, expected);
}
bool guarded_copy(uintptr_t address, void* output, size_t size) noexcept {
    __try { std::memcpy(output, reinterpret_cast<const void*>(address), size); return true; }
    __except(EXCEPTION_EXECUTE_HANDLER) { return false; }
}
bool guarded_movie_getter(uintptr_t function, uintptr_t player, int64_t& ticks) noexcept {
    // MS x64 member convention established from the pinned execGetTime thunk.
    using Getter = int64_t* (__fastcall*)(void*, int64_t*);
    __try { return reinterpret_cast<Getter>(function)(reinterpret_cast<void*>(player), &ticks) == &ticks; }
    __except(EXCEPTION_EXECUTE_HANDLER) { return false; }
}
}
// Game-thread only, with freshly reacquired exact D9MediaPlayer and MediaPlayer
// class GetAddress() integers. Returns only a scalar protocol string. No cache.
extern "C" __declspec(dllexport) int lisr_movie_time(lua_State* state) noexcept {
    static const bool compatible = exact_loader();
    if (!compatible) return 0;
    try {
        Lua lua(state);
        if (lua.get_stack_size() != 2 || !lua.is_integer(1) || !lua.is_integer(2)) {
            lua.set_string("LISRMT1|status=arguments"); return 1;
        }
        const auto klass = lua.get_integer(-1), player = lua.get_integer(-1);
        if (klass <= 0 || player <= 0) { lua.set_string("LISRMT1|status=arguments"); return 1; }
        static HMODULE module = GetModuleHandleW(nullptr);
        static const bool game = [] {
            constexpr unsigned char expected[] = {0xc1,0x41,0xab,0x07,0xaa,0x9b,0x7f,0x77,0xad,0xde,0x73,0x3f,0xc0,0x48,0x10,0x42,0xfe,0x3e,0x63,0x72,0x46,0x39,0x70,0x13,0x22,0xe6,0x59,0xd6,0x11,0x51,0x9c,0xf2};
            return exact_module(module, expected);
        }();
        auto memory = [](uintptr_t p, void* out, size_t n) { return guarded_copy(p, out, n); };
        const auto result = lisr::movie::sample(memory, reinterpret_cast<uintptr_t>(module), game,
            static_cast<uintptr_t>(player), static_cast<uintptr_t>(klass), guarded_movie_getter);
        std::ostringstream out; out.imbue(std::locale::classic());
        out << "LISRMT1|status=" << result.status;
        if (std::strcmp(result.status, "ok") == 0) out << "|seconds=" << std::setprecision(17) << result.seconds;
        const auto text = out.str(); lua.set_string(std::string_view(text)); return 1;
    } catch (...) { return 0; }
}
extern "C" __declspec(dllexport) int lisr_reflection_read(lua_State* state) noexcept {
    // A mismatch returns no result without constructing a potentially wrong ABI wrapper.
    static const bool compatible = exact_loader();
    if (!compatible) return 0;
    try {
        Lua lua(state);
        return lisr::reflection::read(lua, [&](bool array, uintptr_t address, uintptr_t property, uintptr_t offset) {
            // Only trusted same-Tick resolver GetAddress values reach this boundary.
            // Never reinterpret failed numeric array elements as objects.
            RC::LuaType::PusherParams params{RC::LuaMadeSimple::Type::Operation::Get, lua,
                reinterpret_cast<RC::Unreal::UObject*>(address),
                reinterpret_cast<void*>(address + offset),
                reinterpret_cast<RC::Unreal::FProperty*>(property)};
            if (array) RC::LuaType::push_arrayproperty(params); else RC::LuaType::push_objectproperty(params);
        });
    } catch (...) { return 0; }
}

// Separate allowlist/resolver: never widens the existing dialogue entry point.
extern "C" __declspec(dllexport) int lisr_rewind_view_read(lua_State* state) noexcept {
    static const bool compatible = exact_loader();
    if (!compatible) return 0;
    try {
        Lua lua(state);
        return lisr::reflection::read(lua, [&](bool, uintptr_t address, uintptr_t property, uintptr_t offset) {
            RC::LuaType::PusherParams params{RC::LuaMadeSimple::Type::Operation::Get, lua,
                reinterpret_cast<RC::Unreal::UObject*>(address),
                reinterpret_cast<void*>(address + offset), reinterpret_cast<RC::Unreal::FProperty*>(property)};
            RC::LuaType::push_objectproperty(params);
        }, true);
    } catch (...) { return 0; }
}

// Hook-local only: resolver validates current class metadata, inner type and
// owner scope. No owner, descriptor or reflected offset survives this call.
extern "C" __declspec(dllexport) int lisr_padlock_read(lua_State* state) noexcept {
    static const bool compatible = exact_loader();
    if (!compatible) return 0; // Do not construct a mismatched Lua ABI wrapper.
    try {
        Lua lua(state);
        return lisr::reflection::read_padlock(lua, [&](int kind, uintptr_t address, uintptr_t property, uintptr_t offset) {
            if (kind == 3) {
                int32_t digit{};
                if (!guarded_copy(address + offset, &digit, sizeof(digit)))
                    throw std::runtime_error("padlock scalar unreadable");
                lua.set_integer(static_cast<int64_t>(digit));
                return;
            }
            RC::LuaType::PusherParams params{RC::LuaMadeSimple::Type::Operation::Get, lua,
                reinterpret_cast<RC::Unreal::UObject*>(address),
                reinterpret_cast<void*>(address + offset), reinterpret_cast<RC::Unreal::FProperty*>(property)};
            if (kind == 1) RC::LuaType::push_arrayproperty(params); else RC::LuaType::push_objectproperty(params);
        });
    } catch (...) { return 0; }
}

// ABI: ASCII whitespace-delimited, classic locale, floats round-trip at precision 9.
// r2 status index serial state reference range marker_known marker_present marker_time
//    visibility_known visible writer_gate_known writer_gate writer_widget writer_material
// status: 0 ready, 1 acquisition failure, 2 invalid state, 3 invalid timeline,
//         4 executable mismatch. Loader mismatch returns no Lua values.
// Caller MUST run on game thread. Widget/material numeric identities may only
// be compared to same-sample live wrappers; they convey no later object validity.
extern "C" __declspec(dllexport) int lisr_rewind(lua_State* state) noexcept {
    static const bool compatible = exact_loader();
    if (!compatible) return 0;
    try {
        Lua lua(state);
        if (lua.get_stack_size() != 0) { lua.set_string("r2 1 -1 0 -1 0 0 0 0 0 0 0 0 0 0 0"); return 1; }
        static HMODULE module = GetModuleHandleW(nullptr);
        static const bool game = [] {
            constexpr unsigned char expected[] = {0xc1,0x41,0xab,0x07,0xaa,0x9b,0x7f,0x77,0xad,0xde,0x73,0x3f,0xc0,0x48,0x10,0x42,0xfe,0x3e,0x63,0x72,0x46,0x39,0x70,0x13,0x22,0xe6,0x59,0xd6,0x11,0x51,0x9c,0xf2};
            return exact_module(module, expected);
        }();
        lisr::rewind::Snapshot s;
        if (!game) s.status = 4;
        else {
            auto memory = [](uintptr_t p, void* out, size_t n) { return guarded_copy(p, out, n); };
            s = lisr::rewind::Reader(memory, reinterpret_cast<uintptr_t>(module)).sample();
        }
        // Invalid samples never expose NaN/Inf or stale fields.
        if (s.status != 0) {
            const int status = s.status, index = s.index, serial = s.serial, rewind_state = s.state;
            s = {}; s.status = status;
            // An invalid gauge is not an unknown manager state. Preserve only
            // revalidated identity/state so control-cue suppression still works.
            if (status == 3) { s.index = index; s.serial = serial; s.state = rewind_state; }
        }
        std::ostringstream out;
        out.imbue(std::locale::classic());
        out << std::setprecision(9) << "r2 " << s.status << ' ' << s.index << ' ' << s.serial << ' ' << s.state
            << ' ' << s.reference << ' ' << s.range << ' ' << int(s.marker_known) << ' ' << int(s.marker_present)
            << ' ' << (s.marker_known ? s.marker_time : 0) << ' ' << int(s.visibility_known) << ' ' << int(s.visible)
            << ' ' << int(s.writer_gate_known) << ' ' << int(s.writer_gate)
            << ' ' << s.writer_widget << ' ' << s.writer_material;
        const auto text = out.str();
        lua.set_string(std::string_view(text));
        return 1;
    } catch (...) { return 0; }
}
