#pragma once
// Minimal mirror of UE4SS's exported LuaMadeSimple::Lua wrapper (pinned commit
// 83330635, native/third_party/ue4ss). We only call non-virtual exported members
// that read the wrapper's FIRST member, m_lua_state. So the mirror needs only
// that member; the declarations below reproduce the exported mangled names.
// The loader statically links Lua and exports no lua_* C API, so this is the
// supported way for a loadlib'd C function to read arguments and return values.
#include <cstddef>
#include <cstdint>
#include <string_view>

struct lua_State;

namespace RC::LuaMadeSimple {
class Lua {
  public:
    explicit Lua(lua_State* state) : m_lua_state(state) {}
    __declspec(dllimport) auto get_stack_size() const -> int32_t;
    __declspec(dllimport) auto is_string(int32_t force_index = 1) const -> bool;
    __declspec(dllimport) auto get_string(int32_t force_index = 1) const -> std::string_view;
    __declspec(dllimport) auto is_bool(int32_t force_index = 1) const -> bool;
    __declspec(dllimport) auto get_bool(int32_t force_index = 1) const -> bool;
    __declspec(dllimport) auto set_bool(bool value) const -> void;
    __declspec(dllimport) auto set_string(std::string_view value) const -> void;
    __declspec(dllimport) auto set_integer(int64_t number) const -> void;

    // Public only so the layout check below can see it; never touch directly.
    lua_State* m_lua_state;
    // Padding: imported members never touch anything past m_lua_state, but keep
    // the object at least as large as the real wrapper's leading fields.
    char m_reserved[256]{};
};
static_assert(offsetof(Lua, m_lua_state) == 0, "UE4SS reads m_lua_state at offset 0");
} // namespace RC::LuaMadeSimple
