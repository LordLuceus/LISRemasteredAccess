cmake_minimum_required(VERSION 3.24)
project(LISRemasteredSpeech LANGUAGES C CXX)
set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
if(NOT CMAKE_SIZEOF_VOID_P EQUAL 8)
    message(FATAL_ERROR "The remaster is x64; configure with -A x64.")
endif()
# The DLL is loaded into the game alongside UE4SS: match its dynamic release CRT.
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreadedDLL" CACHE STRING "" FORCE)

# --- Prism (same pinned source and literal-SAPI patch as LISAccess) ---
include(FetchContent)
set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
foreach(option GDEXTENSION TESTS DEMOS LINTING VCPKG_SPECIFIC_OPTIONS LEGACY_BACKENDS SHIMS)
    set(PRISM_ENABLE_${option} OFF CACHE BOOL "" FORCE)
endforeach()
set(PRISM_BUILD_WINELIBS OFF CACHE BOOL "" FORCE)
set(LIB_TOOL "${CMAKE_AR}" CACHE FILEPATH "" FORCE)
FetchContent_Declare(prism
    URL https://codeload.github.com/ethindp/prism/zip/c30d865faf9b4c38769cc58c2f33cbac78fba3ef
    URL_HASH SHA256=c5d3f0be06bd34fea0478f1c38ce4de85cd3a21dbd2a1ed869b21c8a0a80ebaf
    DOWNLOAD_EXTRACT_TIMESTAMP FALSE)
FetchContent_MakeAvailable(prism)
include(cmake/prism-sapi-literal.cmake)
get_directory_property(prism_targets DIRECTORY "${prism_SOURCE_DIR}" BUILDSYSTEM_TARGETS)
foreach(target IN LISTS prism_targets)
    get_target_property(kind ${target} TYPE)
    if(kind MATCHES "^(OBJECT|STATIC|SHARED|INTERFACE)_LIBRARY$")
        set_target_properties(${target} PROPERTIES C_STANDARD_REQUIRED OFF INTERPROCEDURAL_OPTIMIZATION OFF)
        if(NOT kind STREQUAL "INTERFACE_LIBRARY")
            target_compile_options(${target} PRIVATE "$<$<COMPILE_LANGUAGE:C>:/std:clatest>")
        endif()
    endif()
endforeach()

# --- Import library for the exact UE4SS.dll exports we call ---
set(UE4SS_IMPLIB "${CMAKE_CURRENT_BINARY_DIR}/UE4SS.lib")
add_custom_command(OUTPUT "${UE4SS_IMPLIB}"
    COMMAND "${CMAKE_AR}" /nologo /machine:x64 /def:"${CMAKE_CURRENT_SOURCE_DIR}/cmake/UE4SS.def" /out:"${UE4SS_IMPLIB}"
    DEPENDS cmake/UE4SS.def
    COMMENT "Generate UE4SS import library from the pinned export list")
add_custom_target(ue4ss_implib DEPENDS "${UE4SS_IMPLIB}")

function(lisr_target target)
    target_compile_options(${target} PRIVATE /W4 /permissive- /utf-8 /EHsc /Zc:enumTypes)
    target_compile_definitions(${target} PRIVATE PRISM_STATIC WIN32_LEAN_AND_MEAN NOMINMAX)
endfunction()

add_library(lisr_speech_core STATIC src/speech.cpp)
lisr_target(lisr_speech_core)
target_link_libraries(lisr_speech_core PUBLIC prism::prism)

# Continuous panned guidance tone (XAudio2 2.9, part of Windows 10+).
add_library(lisr_tone STATIC src/tone.cpp)
lisr_target(lisr_tone)
target_link_libraries(lisr_tone PUBLIC xaudio2 ole32)

add_library(lisr_speech SHARED src/module.cpp)
lisr_target(lisr_speech)
add_dependencies(lisr_speech ue4ss_implib)
target_link_libraries(lisr_speech PRIVATE lisr_speech_core lisr_tone "${UE4SS_IMPLIB}" winmm)
set_target_properties(lisr_speech PROPERTIES OUTPUT_NAME lisr_speech)

# Speech core smoke test without the game or UE4SS.
add_executable(speech_smoke tests/speech_smoke.cpp)
lisr_target(speech_smoke)
target_link_libraries(speech_smoke PRIVATE lisr_speech_core)
# Tone: pan maths, and (unless --quiet) a short audible sweep left to right.
add_executable(tone_smoke tests/tone_smoke.cpp)
lisr_target(tone_smoke)
target_link_libraries(tone_smoke PRIVATE lisr_tone)
enable_testing()
add_test(NAME speech_smoke COMMAND speech_smoke --quiet)
add_test(NAME tone_smoke COMMAND tone_smoke --quiet)

# Version-pinned fresh property reader. Separate DLL/definition of Lua; never linked to speech.
option(LISR_REFLECTION_CANDIDATE "Build the version-pinned dialogue property reader" ON)
if(LISR_REFLECTION_CANDIDATE)
    FetchContent_Declare(reflection_fmt
        URL https://codeload.github.com/fmtlib/fmt/zip/40626af88bd7df9a5fb80be7b25ac85b122d6c21
        URL_HASH SHA256=9f80db8263c8607811f23db58c8eaffd85edc5f9f1f437e8279fc14875713e5f
        SOURCE_SUBDIR include # headers only; no duplicate fmt/Lua implementation
        DOWNLOAD_EXTRACT_TIMESTAMP FALSE)
    FetchContent_MakeAvailable(reflection_fmt)
    set(REFLECTION_IMPLIB "${CMAKE_CURRENT_BINARY_DIR}/UE4SS-reflection.lib")
    add_custom_command(OUTPUT "${REFLECTION_IMPLIB}"
        COMMAND "${CMAKE_AR}" /nologo /machine:x64 /def:"${CMAKE_CURRENT_SOURCE_DIR}/cmake/UE4SS-reflection.def" /out:"${REFLECTION_IMPLIB}"
        DEPENDS cmake/UE4SS-reflection.def)
    add_custom_target(reflection_implib DEPENDS "${REFLECTION_IMPLIB}")
    add_library(lisr_reflection SHARED src/reflection.cpp)
    add_executable(reflection_abi tests/reflection_abi.cpp)
    foreach(target lisr_reflection reflection_abi)
        lisr_target(${target})
        target_include_directories(${target} PRIVATE src third_party/ue4ss/include "${reflection_fmt_SOURCE_DIR}/include")
        target_compile_definitions(${target} PRIVATE _ITERATOR_DEBUG_LEVEL=0)
    endforeach()
    target_compile_options(reflection_abi PRIVATE /d1reportSingleClassLayoutPusherParams)
    add_dependencies(lisr_reflection reflection_implib)
    target_link_libraries(lisr_reflection PRIVATE "${REFLECTION_IMPLIB}" bcrypt)
    add_test(NAME reflection_abi COMMAND reflection_abi)
    # Shared protocol instantiated with a strict fake stack; no loader or Lua runtime.
    add_executable(reflection_protocol tests/reflection_protocol.cpp)
    lisr_target(reflection_protocol)
    target_include_directories(reflection_protocol PRIVATE src)
    add_test(NAME reflection_protocol COMMAND reflection_protocol)
endif()
