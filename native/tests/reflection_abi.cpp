#include "reflection_abi.h"
#include <cstdio>
// No DLL calls or game dependency; checks execute under NDEBUG too.
int main(int argc, char** argv) {
    int failures = 0;
    if (argc == 2 && std::string_view(argv[1]) == "--force-failure") ++failures;
    if (sizeof(RC::LuaMadeSimple::Lua) != 0xa8) ++failures;
    if (sizeof(RC::LuaType::PusherParams) != 0x30) ++failures;
    if (alignof(RC::LuaType::PusherParams) != 8) ++failures;
    if (int(RC::LuaMadeSimple::Type::Operation::Get) != 0) ++failures;
    if (int(RC::LuaMadeSimple::Type::Operation::GetParam) != 3) ++failures;
    std::printf("reflection ABI: 5 executed checks; failures=%d\n", failures);
    return failures ? 1 : 0;
}
