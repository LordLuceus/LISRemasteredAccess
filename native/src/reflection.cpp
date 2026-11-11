// Version-pinned property reader. Separate DLL; never includes the scalar speech Lua mirror.
#include "reflection_abi.h"
#include "reflection_protocol.h"
#include <windows.h>
#include <bcrypt.h>
#include <array>
#include <limits>
using RC::LuaMadeSimple::Lua;
namespace {
bool exact_loader() noexcept {
    // Verify the module owning the imported pusher, not another same-named file.
    HMODULE module{};
    if (!GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
            reinterpret_cast<LPCWSTR>(&RC::LuaType::push_arrayproperty), &module)) return false;
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
    constexpr unsigned char expected[] = {0xce,0x5e,0x3c,0x46,0xa9,0x20,0xcc,0x00,0xb2,0x81,0x7a,0xc6,0x1e,0x43,0x8c,0x91,0x62,0x83,0x02,0x90,0x37,0x9d,0x0b,0x5b,0x9c,0x4d,0xfc,0x2b,0x29,0x45,0x92,0x90};
    for (size_t i=0; ok && i<digest.size(); ++i) ok = digest[i] == expected[i];
    if (hash) BCryptDestroyHash(hash);
    if (algorithm) BCryptCloseAlgorithmProvider(algorithm, 0);
    CloseHandle(file);
    return ok;
}
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
