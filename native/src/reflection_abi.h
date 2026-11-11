#pragma once
// Version-locked ABI carrier from RE-UE4SS 83330635 LuaUObject.hpp:237-250.
// Only public data layout is reproduced; Unreal objects remain opaque.
#include <cstddef>
#include <cstdint>
#include <string>
#include <string_view>
#include <vector>
#include <stdexcept>
#include <LuaMadeSimple/LuaMadeSimple.hpp>
namespace RC::Unreal { class UObject; class FProperty; }
namespace RC::LuaMadeSimple::Type {
enum class Operation { Get, GetNonTrivialLocal, Set, GetParam };
}
namespace RC::LuaType {
struct PusherParams {
    const LuaMadeSimple::Type::Operation operation;
    const LuaMadeSimple::Lua& lua;
    Unreal::UObject* base;
    void* data;
    Unreal::FProperty* property;
    int32_t stored_at_index = 1;
    bool create_new_if_get_non_trivial_local = true;
};
__declspec(dllimport) void push_arrayproperty(const PusherParams&);
__declspec(dllimport) void push_objectproperty(const PusherParams&);
}
static_assert(sizeof(void*) == 8);
static_assert(sizeof(RC::LuaMadeSimple::Lua) == 0xa8);
static_assert(alignof(RC::LuaMadeSimple::Lua) == 8);
static_assert(sizeof(RC::LuaType::PusherParams) == 0x30);
static_assert(alignof(RC::LuaType::PusherParams) == 8);
static_assert(sizeof(RC::LuaMadeSimple::Type::Operation) == 4);
static_assert(int(RC::LuaMadeSimple::Type::Operation::Get) == 0);
// offsetof(reference-member) does not report its storage offset in MSVC.
// Verify lua at +8 using /d1reportSingleClassLayoutPusherParams in the ABI gate;
// the remaining ordinary members are checked here.
static_assert(offsetof(RC::LuaType::PusherParams, base) == 0x10);
static_assert(offsetof(RC::LuaType::PusherParams, data) == 0x18);
static_assert(offsetof(RC::LuaType::PusherParams, property) == 0x20);
static_assert(offsetof(RC::LuaType::PusherParams, stored_at_index) == 0x28);
static_assert(offsetof(RC::LuaType::PusherParams, create_new_if_get_non_trivial_local) == 0x2c);
