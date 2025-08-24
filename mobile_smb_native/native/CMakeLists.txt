cmake_minimum_required(VERSION 3.10)

project(smb_bridge)

# Set C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Try to find libsmb2 via pkg-config (Linux/macOS) or use manual detection
find_package(PkgConfig QUIET)
if(PKG_CONFIG_FOUND)
    pkg_check_modules(LIBSMB2 QUIET libsmb2)
endif()

# Option to force building with libsmb2 (defaults to ON only if found)
option(BUILD_WITH_LIBSMB2 "Build smb_bridge with libsmb2 back-end" ${LIBSMB2_FOUND})

# Always include public headers
include_directories(include)

if(BUILD_WITH_LIBSMB2)
    message(STATUS "Building smb_bridge with libsmb2 implementation")

    # Source files - libsmb2 implementation (no FFmpeg dependency; thumbnail is stubbed)
    set(SOURCES
        src/smb_bridge.cpp
        src/smb_client.cpp
        src/thumbnail_generator.cpp
    )

    # Create shared library
    add_library(smb_bridge SHARED ${SOURCES})

    # Link/include libsmb2
    if(LIBSMB2_FOUND)
        include_directories(${LIBSMB2_INCLUDE_DIRS})
        target_link_libraries(smb_bridge ${LIBSMB2_LIBRARIES})
        target_compile_options(smb_bridge PRIVATE ${LIBSMB2_CFLAGS_OTHER})
    else()
        # Fallback: rely on default include/lib paths (e.g., vcpkg toolchain) and link library by name
        target_link_libraries(smb_bridge smb2)
    endif()

    # Platform-specific configurations
    if(WIN32)
        target_link_libraries(smb_bridge ws2_32)
    elseif(UNIX)
        target_link_libraries(smb_bridge pthread)
    endif()

else()
    message(STATUS "Building smb_bridge with stub implementation (no external dependencies)")

    # Stub implementation provides compatible C API without libsmb2/FFmpeg
    set(SOURCES
        src/stub_implementations.cpp
    )

    add_library(smb_bridge SHARED ${SOURCES})

    # Platform-specific minimal links
    if(WIN32)
        target_link_libraries(smb_bridge ws2_32)
    elseif(UNIX)
        target_link_libraries(smb_bridge pthread)
    endif()
endif()

# Set library properties
set_target_properties(smb_bridge PROPERTIES
    VERSION 1.0.0
    SOVERSION 1
    WINDOWS_EXPORT_ALL_SYMBOLS ON
)