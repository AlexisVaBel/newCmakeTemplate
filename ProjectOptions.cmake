include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(newCmakeTemplate_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(newCmakeTemplate_setup_options)
  option(newCmakeTemplate_ENABLE_HARDENING "Enable hardening" ON)
  option(newCmakeTemplate_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    newCmakeTemplate_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    newCmakeTemplate_ENABLE_HARDENING
    OFF)

  newCmakeTemplate_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR newCmakeTemplate_PACKAGING_MAINTAINER_MODE)
    option(newCmakeTemplate_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(newCmakeTemplate_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(newCmakeTemplate_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(newCmakeTemplate_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(newCmakeTemplate_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(newCmakeTemplate_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(newCmakeTemplate_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(newCmakeTemplate_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(newCmakeTemplate_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(newCmakeTemplate_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(newCmakeTemplate_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(newCmakeTemplate_ENABLE_PCH "Enable precompiled headers" OFF)
    option(newCmakeTemplate_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(newCmakeTemplate_ENABLE_IPO "Enable IPO/LTO" ON)
    option(newCmakeTemplate_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(newCmakeTemplate_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(newCmakeTemplate_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(newCmakeTemplate_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(newCmakeTemplate_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(newCmakeTemplate_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(newCmakeTemplate_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(newCmakeTemplate_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(newCmakeTemplate_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(newCmakeTemplate_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(newCmakeTemplate_ENABLE_PCH "Enable precompiled headers" OFF)
    option(newCmakeTemplate_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      newCmakeTemplate_ENABLE_IPO
      newCmakeTemplate_WARNINGS_AS_ERRORS
      newCmakeTemplate_ENABLE_USER_LINKER
      newCmakeTemplate_ENABLE_SANITIZER_ADDRESS
      newCmakeTemplate_ENABLE_SANITIZER_LEAK
      newCmakeTemplate_ENABLE_SANITIZER_UNDEFINED
      newCmakeTemplate_ENABLE_SANITIZER_THREAD
      newCmakeTemplate_ENABLE_SANITIZER_MEMORY
      newCmakeTemplate_ENABLE_UNITY_BUILD
      newCmakeTemplate_ENABLE_CLANG_TIDY
      newCmakeTemplate_ENABLE_CPPCHECK
      newCmakeTemplate_ENABLE_COVERAGE
      newCmakeTemplate_ENABLE_PCH
      newCmakeTemplate_ENABLE_CACHE)
  endif()

  newCmakeTemplate_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (newCmakeTemplate_ENABLE_SANITIZER_ADDRESS OR newCmakeTemplate_ENABLE_SANITIZER_THREAD OR newCmakeTemplate_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(newCmakeTemplate_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(newCmakeTemplate_global_options)
  if(newCmakeTemplate_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    newCmakeTemplate_enable_ipo()
  endif()

  newCmakeTemplate_supports_sanitizers()

  if(newCmakeTemplate_ENABLE_HARDENING AND newCmakeTemplate_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR newCmakeTemplate_ENABLE_SANITIZER_UNDEFINED
       OR newCmakeTemplate_ENABLE_SANITIZER_ADDRESS
       OR newCmakeTemplate_ENABLE_SANITIZER_THREAD
       OR newCmakeTemplate_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${newCmakeTemplate_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${newCmakeTemplate_ENABLE_SANITIZER_UNDEFINED}")
    newCmakeTemplate_enable_hardening(newCmakeTemplate_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(newCmakeTemplate_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(newCmakeTemplate_warnings INTERFACE)
  add_library(newCmakeTemplate_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  newCmakeTemplate_set_project_warnings(
    newCmakeTemplate_warnings
    ${newCmakeTemplate_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(newCmakeTemplate_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    configure_linker(newCmakeTemplate_options)
  endif()

  include(cmake/Sanitizers.cmake)
  newCmakeTemplate_enable_sanitizers(
    newCmakeTemplate_options
    ${newCmakeTemplate_ENABLE_SANITIZER_ADDRESS}
    ${newCmakeTemplate_ENABLE_SANITIZER_LEAK}
    ${newCmakeTemplate_ENABLE_SANITIZER_UNDEFINED}
    ${newCmakeTemplate_ENABLE_SANITIZER_THREAD}
    ${newCmakeTemplate_ENABLE_SANITIZER_MEMORY})

  set_target_properties(newCmakeTemplate_options PROPERTIES UNITY_BUILD ${newCmakeTemplate_ENABLE_UNITY_BUILD})

  if(newCmakeTemplate_ENABLE_PCH)
    target_precompile_headers(
      newCmakeTemplate_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(newCmakeTemplate_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    newCmakeTemplate_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(newCmakeTemplate_ENABLE_CLANG_TIDY)
    newCmakeTemplate_enable_clang_tidy(newCmakeTemplate_options ${newCmakeTemplate_WARNINGS_AS_ERRORS})
  endif()

  if(newCmakeTemplate_ENABLE_CPPCHECK)
    newCmakeTemplate_enable_cppcheck(${newCmakeTemplate_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(newCmakeTemplate_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    newCmakeTemplate_enable_coverage(newCmakeTemplate_options)
  endif()

  if(newCmakeTemplate_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(newCmakeTemplate_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(newCmakeTemplate_ENABLE_HARDENING AND NOT newCmakeTemplate_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR newCmakeTemplate_ENABLE_SANITIZER_UNDEFINED
       OR newCmakeTemplate_ENABLE_SANITIZER_ADDRESS
       OR newCmakeTemplate_ENABLE_SANITIZER_THREAD
       OR newCmakeTemplate_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    newCmakeTemplate_enable_hardening(newCmakeTemplate_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
