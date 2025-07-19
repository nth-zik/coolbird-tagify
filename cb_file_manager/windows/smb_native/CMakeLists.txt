cmake_minimum_required(VERSION 3.10)

project(smb_native LANGUAGES CXX)

add_library(smb_native SHARED
  "smb_native.cpp"
  "smb_native.h"
)

# Link against necessary Windows libraries
# Mpr.lib for WNet functions
# Ole32.lib for COM (for thumbnails)
# shlwapi.lib for Path* functions
# gdiplus.lib for GDI+ (thumbnails)
# netapi32.lib for NetShareEnum
target_link_libraries(smb_native PRIVATE 
  Mpr 
  Ole32 
  shlwapi
  gdiplus
  Shell32
  Comctl32
  netapi32
)

set_target_properties(smb_native PROPERTIES
  CXX_STANDARD 17
  CXX_STANDARD_REQUIRED ON
)

# Install the DLL next to the runner executable.
install(
  TARGETS smb_native
  RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}/"
) 