# Preserve LISAccess's literal-text SAPI contract. Build a modified copy rather
# than dirtying the SHA-256-pinned upstream snapshot used for licence validation.
file(READ "${prism_SOURCE_DIR}/source/backends/sapi.cpp" sapi_source)
set(before [=[      flags |= SPF_IS_XML;
    }
    return SapiSpeakParams{.text = std::move(wtext), .flags = flags};]=])
set(after [=[      flags |= SPF_IS_XML;
    } else {
      // LISAccess: plain announcements must not be autodetected as XML.
      flags |= SPF_IS_NOT_XML;
    }
    return SapiSpeakParams{.text = std::move(wtext), .flags = flags};]=])
string(FIND "${sapi_source}" "${before}" location)
if(location LESS 0)
    message(FATAL_ERROR "Pinned Prism SAPI text contract changed; audit the literal-text patch.")
endif()
string(REPLACE "${before}" "${after}" patched "${sapi_source}")
set(destination "${CMAKE_CURRENT_BINARY_DIR}/prism-sapi.cpp")
set(previous "")
if(EXISTS "${destination}")
    file(READ "${destination}" previous)
endif()
if(NOT previous STREQUAL patched)
    file(WRITE "${destination}" "${patched}")
endif()
get_target_property(sapi_inputs prism_backend_sapi SOURCES)
list(LENGTH sapi_inputs input_count)
if(NOT input_count EQUAL 1)
    message(FATAL_ERROR "Prism SAPI source inventory changed; audit before replacing its source.")
endif()
set_property(TARGET prism_backend_sapi PROPERTY SOURCES "${destination}")
