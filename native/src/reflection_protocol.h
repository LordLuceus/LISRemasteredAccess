#pragma once
// The actual native stack/error algorithm. Instantiated with the real Lua wrapper
// in reflection.cpp and a strict fake stack in engine-free protocol tests.
#include <cstdint>
#include <limits>
#include <stdexcept>
#include <string>
namespace lisr::reflection {
inline constexpr char resolver[] = "__lisr_reflection_resolve_83330635";
inline constexpr char rewind_resolver[] = "__lisr_rewind_view_resolve_v1";
template<class Stack, class Push>
int read(Stack& lua, Push&& push, bool rewind_view = false) {
    const int top = lua.get_stack_size();
    try {
        if (top != 2 || !lua.is_userdata(1) || !lua.is_string(2)) throw std::runtime_error("reflection arguments");
        lua.insert_value(2, top+1); // duplicate; getter removes only the copy
        const std::string name(lua.get_string(-1));
        const bool array = !rewind_view && name == "DialogButtons_Array";
        const bool view_field = name == "RewindBarMaterialInstance" || name == "Overlay_Rewind" ||
            name == "CanvasPanel_Rewind" || name == "Button_RewindIndicator" || name == "Image_RewindButtonIndicator";
        if (rewind_view ? !view_field : (!array && name != "DialogText")) throw std::runtime_error("reflection whitelist");
        lua.prepare_function_call(rewind_view ? rewind_resolver : resolver);
        lua.insert_value(1, lua.get_stack_size()+1);
        lua.insert_value(2, lua.get_stack_size()+1);
        lua.call_function(2, 4);
        if (lua.get_stack_size() != top+4) throw std::runtime_error("reflection result count");
        for (int i=top+1; i<=top+4; ++i) if (!lua.is_integer(i)) throw std::runtime_error("reflection result types");
        const auto kind = lua.get_integer(-1);
        const auto offset = lua.get_integer(-1);
        const auto property = lua.get_integer(-1);
        const auto owner = lua.get_integer(-1);
        if (kind != (array ? 1 : 2) || owner <= 0 || property <= 0 || offset < 0 || offset > INT32_MAX)
            throw std::runtime_error("reflection provenance rejected");
        const auto address = static_cast<uintptr_t>(owner);
        if (address > std::numeric_limits<uintptr_t>::max() - static_cast<uintptr_t>(offset))
            throw std::runtime_error("reflection address overflow");
        push(array, address, static_cast<uintptr_t>(property), static_cast<uintptr_t>(offset));
        if (lua.get_stack_size() != top+1) throw std::runtime_error("reflection pusher stack");
        return 1;
    } catch (...) {
        while (lua.get_stack_size() > top) lua.discard_value(-1);
        lua.set_nil(); lua.set_string("uncached reflection rejected");
        return 2;
    }
}
// Deliberately separate from read(): padlocks require positive offsets and a
// third (scalar) kind, neither of which changes the older entry points.
inline constexpr char padlock_resolver[] = "__lisr_padlock_resolve_v1";
template<class Stack, class Push>
int read_padlock(Stack& lua, Push&& push) {
    const int top = lua.get_stack_size();
    try {
        if (top != 2 || !lua.is_userdata(1) || !lua.is_string(2)) throw std::runtime_error("padlock arguments");
        lua.insert_value(2, top+1);
        const std::string name(lua.get_string(-1));
        const int expected = name == "DigitWidgets_Array" ? 1 : name == "TextBlock_Digit" ? 2 : name == "Digit" ? 3 : 0;
        if (!expected) throw std::runtime_error("padlock whitelist");
        lua.prepare_function_call(padlock_resolver);
        lua.insert_value(1, lua.get_stack_size()+1);
        lua.insert_value(2, lua.get_stack_size()+1);
        lua.call_function(2, 4);
        if (lua.get_stack_size() != top+4) throw std::runtime_error("padlock result count");
        for (int i=top+1; i<=top+4; ++i) if (!lua.is_integer(i)) throw std::runtime_error("padlock result types");
        const auto kind = lua.get_integer(-1);
        const auto offset = lua.get_integer(-1);
        const auto property = lua.get_integer(-1);
        const auto owner = lua.get_integer(-1);
        if (kind != expected || owner <= 0 || property <= 0 || offset <= 0 || offset > INT32_MAX)
            throw std::runtime_error("padlock provenance rejected");
        constexpr auto maximum = std::numeric_limits<uintptr_t>::max();
        if (static_cast<uint64_t>(owner) > maximum || static_cast<uint64_t>(property) > maximum)
            throw std::runtime_error("padlock pointer overflow");
        const auto address = static_cast<uintptr_t>(owner);
        const auto displacement = static_cast<uintptr_t>(offset);
        if (address > maximum - displacement ||
            (expected == 3 && address + displacement > maximum - (sizeof(int32_t)-1)))
            throw std::runtime_error("padlock address overflow");
        push(expected, address, static_cast<uintptr_t>(property), displacement);
        if (lua.get_stack_size() != top+1) throw std::runtime_error("padlock pusher stack");
        return 1;
    } catch (...) {
        while (lua.get_stack_size() > top) lua.discard_value(-1);
        lua.set_nil(); lua.set_string("uncached padlock reflection rejected");
        return 2;
    }
}
} // namespace lisr::reflection
