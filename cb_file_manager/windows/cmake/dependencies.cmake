include_guard(GLOBAL)

# Dependency management helpers for Windows builds.

set(COOLBIRD_NUGET_URL "https://dist.nuget.org/win-x86-commandline/v6.0.0/nuget.exe")
set(COOLBIRD_NUGET_SHA256 "04eb6c4fe4213907e2773e1be1bbbd730e9a655a3c9c58387ce8d4a714a5b9e1")

option(COOLBIRD_FFMPEG_AUTO_DOWNLOAD "Download FFmpeg for Windows build when missing" ON)
set(
  COOLBIRD_FFMPEG_DOWNLOAD_URL
  "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl-shared.zip"
  CACHE STRING
  "FFmpeg archive URL used when local FFmpeg is not available"
)

function(coolbird_ensure_nuget)
  if(DEFINED NUGET AND EXISTS "${NUGET}")
    set(NUGET "${NUGET}" CACHE FILEPATH "Path to nuget.exe" FORCE)
    message(STATUS "Using configured NuGet: ${NUGET}")
    return()
  endif()

  find_program(_coolbird_system_nuget NAMES nuget.exe nuget)
  if(_coolbird_system_nuget)
    set(NUGET "${_coolbird_system_nuget}" CACHE FILEPATH "Path to nuget.exe" FORCE)
    message(STATUS "Using system NuGet: ${NUGET}")
    return()
  endif()

  set(_coolbird_nuget_dir "${CMAKE_BINARY_DIR}/_tools/nuget")
  set(_coolbird_nuget_exe "${_coolbird_nuget_dir}/nuget.exe")
  file(MAKE_DIRECTORY "${_coolbird_nuget_dir}")

  if(NOT EXISTS "${_coolbird_nuget_exe}")
    set(_coolbird_nuget_downloaded FALSE)
    foreach(_coolbird_attempt RANGE 1 3)
      file(
        DOWNLOAD
        "${COOLBIRD_NUGET_URL}"
        "${_coolbird_nuget_exe}"
        EXPECTED_HASH "SHA256=${COOLBIRD_NUGET_SHA256}"
        STATUS _coolbird_download_status
        SHOW_PROGRESS
        TLS_VERIFY ON
        INACTIVITY_TIMEOUT 60
      )
      list(GET _coolbird_download_status 0 _coolbird_download_code)
      if(_coolbird_download_code EQUAL 0)
        set(_coolbird_nuget_downloaded TRUE)
        break()
      endif()

      if(EXISTS "${_coolbird_nuget_exe}")
        file(REMOVE "${_coolbird_nuget_exe}")
      endif()
      message(WARNING "NuGet download attempt ${_coolbird_attempt} failed: ${_coolbird_download_status}")
    endforeach()

    if(NOT _coolbird_nuget_downloaded)
      message(FATAL_ERROR "Unable to download nuget.exe after multiple attempts.")
    endif()
  endif()

  set(NUGET "${_coolbird_nuget_exe}" CACHE FILEPATH "Path to nuget.exe" FORCE)
  message(STATUS "Using downloaded NuGet: ${NUGET}")
endfunction()

function(coolbird_resolve_ffmpeg_dir OUT_VAR)
  if(DEFINED FFMPEG_DIR AND EXISTS "${FFMPEG_DIR}/include/libavcodec/avcodec.h")
    set(${OUT_VAR} "${FFMPEG_DIR}" PARENT_SCOPE)
    message(STATUS "Using configured FFmpeg directory: ${FFMPEG_DIR}")
    return()
  endif()

  set(_coolbird_repo_ffmpeg "${CMAKE_SOURCE_DIR}/ffmpeg")
  if(EXISTS "${_coolbird_repo_ffmpeg}/include/libavcodec/avcodec.h")
    set(${OUT_VAR} "${_coolbird_repo_ffmpeg}" PARENT_SCOPE)
    message(STATUS "Using repository FFmpeg directory: ${_coolbird_repo_ffmpeg}")
    return()
  endif()

  if(NOT COOLBIRD_FFMPEG_AUTO_DOWNLOAD)
    message(FATAL_ERROR "FFmpeg directory not found. Set FFMPEG_DIR or enable COOLBIRD_FFMPEG_AUTO_DOWNLOAD.")
  endif()

  set(_coolbird_ffmpeg_deps_dir "${CMAKE_BINARY_DIR}/_deps")
  set(_coolbird_ffmpeg_root "${_coolbird_ffmpeg_deps_dir}/ffmpeg")
  set(_coolbird_ffmpeg_archive "${_coolbird_ffmpeg_deps_dir}/ffmpeg-windows-shared.zip")
  file(MAKE_DIRECTORY "${_coolbird_ffmpeg_deps_dir}")

  if(NOT EXISTS "${_coolbird_ffmpeg_archive}")
    set(_coolbird_ffmpeg_downloaded FALSE)
    foreach(_coolbird_attempt RANGE 1 3)
      file(
        DOWNLOAD
        "${COOLBIRD_FFMPEG_DOWNLOAD_URL}"
        "${_coolbird_ffmpeg_archive}"
        STATUS _coolbird_download_status
        SHOW_PROGRESS
        TLS_VERIFY ON
        INACTIVITY_TIMEOUT 120
      )
      list(GET _coolbird_download_status 0 _coolbird_download_code)
      if(_coolbird_download_code EQUAL 0)
        set(_coolbird_ffmpeg_downloaded TRUE)
        break()
      endif()

      if(EXISTS "${_coolbird_ffmpeg_archive}")
        file(REMOVE "${_coolbird_ffmpeg_archive}")
      endif()
      message(WARNING "FFmpeg download attempt ${_coolbird_attempt} failed: ${_coolbird_download_status}")
    endforeach()

    if(NOT _coolbird_ffmpeg_downloaded)
      message(FATAL_ERROR "Unable to download FFmpeg archive after multiple attempts.")
    endif()
  endif()

  if(NOT EXISTS "${_coolbird_ffmpeg_root}/.ready")
    file(REMOVE_RECURSE "${_coolbird_ffmpeg_root}")
    file(MAKE_DIRECTORY "${_coolbird_ffmpeg_root}")
    execute_process(
      COMMAND "${CMAKE_COMMAND}" -E tar xf "${_coolbird_ffmpeg_archive}"
      WORKING_DIRECTORY "${_coolbird_ffmpeg_root}"
      RESULT_VARIABLE _coolbird_extract_result
      ERROR_VARIABLE _coolbird_extract_error
    )
    if(NOT _coolbird_extract_result EQUAL 0)
      message(FATAL_ERROR "Unable to extract FFmpeg archive: ${_coolbird_extract_error}")
    endif()
    file(WRITE "${_coolbird_ffmpeg_root}/.ready" "${COOLBIRD_FFMPEG_DOWNLOAD_URL}\n")
  endif()

  set(_coolbird_ffmpeg_candidates "${_coolbird_ffmpeg_root}")
  file(GLOB _coolbird_ffmpeg_children LIST_DIRECTORIES true "${_coolbird_ffmpeg_root}/*")
  list(APPEND _coolbird_ffmpeg_candidates ${_coolbird_ffmpeg_children})

  set(_coolbird_ffmpeg_resolved "")
  foreach(_coolbird_candidate IN LISTS _coolbird_ffmpeg_candidates)
    if(
      EXISTS "${_coolbird_candidate}/include/libavcodec/avcodec.h"
      AND EXISTS "${_coolbird_candidate}/lib/avcodec.lib"
    )
      set(_coolbird_ffmpeg_resolved "${_coolbird_candidate}")
      break()
    endif()
  endforeach()

  if(NOT _coolbird_ffmpeg_resolved)
    message(FATAL_ERROR "Could not locate extracted FFmpeg directory in ${_coolbird_ffmpeg_root}.")
  endif()

  set(${OUT_VAR} "${_coolbird_ffmpeg_resolved}" PARENT_SCOPE)
  message(STATUS "Using downloaded FFmpeg directory: ${_coolbird_ffmpeg_resolved}")
endfunction()
