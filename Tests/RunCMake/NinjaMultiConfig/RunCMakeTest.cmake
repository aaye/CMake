cmake_minimum_required(VERSION 3.16)

include(RunCMake)

set(RunCMake_GENERATOR "Ninja Multi-Config")
set(RunCMake_GENERATOR_IS_MULTI_CONFIG 1)

function(check_files dir)
  cmake_parse_arguments(_check_files "" "" "INCLUDE;EXCLUDE" ${ARGN})

  set(expected ${_check_files_INCLUDE})
  list(FILTER expected EXCLUDE REGEX "^$")
  list(REMOVE_DUPLICATES expected)
  list(SORT expected)

  file(GLOB_RECURSE actual "${dir}/*")
  list(FILTER actual EXCLUDE REGEX "/CMakeFiles/|\\.ninja$|/CMakeCache\\.txt$|/target_files[^/]*\\.cmake$|/\\.ninja_[^/]*$|/cmake_install\\.cmake$|\\.ilk$|\\.manifest$|\\.pdb$|\\.exp$|/install_manifest\\.txt$")
  foreach(f IN LISTS _check_files_INCLUDE _check_files_EXCLUDE)
    if(EXISTS ${f})
      list(APPEND actual ${f})
    endif()
  endforeach()
  list(REMOVE_DUPLICATES actual)
  list(SORT actual)

  if(NOT "${expected}" STREQUAL "${actual}")
    string(REPLACE ";" "\n  " expected_formatted "${expected}")
    string(REPLACE ";" "\n  " actual_formatted "${actual}")
    string(APPEND RunCMake_TEST_FAILED "Actual files did not match expected\nExpected:\n  ${expected_formatted}\nActual:\n  ${actual_formatted}\n")
  endif()

  set(RunCMake_TEST_FAILED "${RunCMake_TEST_FAILED}" PARENT_SCOPE)
endfunction()

function(check_file_contents filename expected)
  if(NOT EXISTS "${filename}")
    string(APPEND RunCMake_TEST_FAILED "File ${filename} does not exist\n")
  else()
    file(READ "${filename}" actual)
    if(NOT actual MATCHES "${expected}")
      string(REPLACE "\n" "\n  " expected_formatted "${expected}")
      string(REPLACE "\n" "\n  " actual_formatted "${actual}")
      string(APPEND RunCMake_TEST_FAILED "Contents of ${filename} do not match expected\nExpected:\n  ${expected_formatted}\nActual:\n  ${actual_formatted}\n")
    endif()
  endif()

  set(RunCMake_TEST_FAILED "${RunCMake_TEST_FAILED}" PARENT_SCOPE)
endfunction()

function(run_cmake_configure case)
  set(RunCMake_TEST_BINARY_DIR ${RunCMake_BINARY_DIR}/${case}-build)
  set(RunCMake_TEST_NO_CLEAN 1)
  file(REMOVE_RECURSE "${RunCMake_TEST_BINARY_DIR}")
  file(MAKE_DIRECTORY "${RunCMake_TEST_BINARY_DIR}")
  run_cmake(${case})
endfunction()

function(run_cmake_build case suffix config)
  set(RunCMake_TEST_BINARY_DIR ${RunCMake_BINARY_DIR}/${case}-build)
  set(RunCMake_TEST_NO_CLEAN 1)
  set(tgts)
  foreach(tgt IN LISTS ARGN)
    list(APPEND tgts --target ${tgt})
  endforeach()
  if(config)
    set(config_arg --config ${config})
  else()
    set(config_arg)
  endif()
  run_cmake_command(${case}-${suffix}-build "${CMAKE_COMMAND}" --build . ${config_arg} ${tgts})
endfunction()

function(run_ninja case suffix file)
  set(RunCMake_TEST_BINARY_DIR ${RunCMake_BINARY_DIR}/${case}-build)
  set(RunCMake_TEST_NO_CLEAN 1)
  run_cmake_command(${case}-${suffix}-ninja "${RunCMake_MAKE_PROGRAM}" -f "${file}" ${ARGN})
endfunction()

###############################################################################

set(RunCMake_TEST_BINARY_DIR ${RunCMake_BINARY_DIR}/Simple-build)
# IMPORTANT: Setting RelWithDebInfo as the first item in CMAKE_CONFIGURATION_TYPES
# generates a build.ninja file with that configuration
set(RunCMake_TEST_OPTIONS "-DCMAKE_CONFIGURATION_TYPES=RelWithDebInfo\\;Debug\\;Release\\;MinSizeRel;-DCMAKE_CROSS_CONFIGS=all")
run_cmake_configure(Simple)
unset(RunCMake_TEST_OPTIONS)
include(${RunCMake_TEST_BINARY_DIR}/target_files.cmake)
run_cmake_build(Simple debug-target Debug simpleexe)
run_ninja(Simple debug-target build-Debug.ninja simplestatic)
get_filename_component(simpleshared_Release "${TARGET_FILE_simpleshared_Release}" NAME)
run_cmake_build(Simple release-filename Release ${simpleshared_Release})
file(RELATIVE_PATH simpleexe_Release "${RunCMake_TEST_BINARY_DIR}" "${TARGET_FILE_simpleexe_Release}")
run_ninja(Simple release-file build-Release.ninja ${simpleexe_Release})
run_cmake_build(Simple all-configs Release simplestatic:all)
run_ninja(Simple default-build-file build.ninja simpleexe)
run_cmake_build(Simple all-clean Release clean:all)
run_cmake_build(Simple debug-subdir Debug SimpleSubdir/all)
run_ninja(Simple release-in-minsizerel-graph-subdir build-MinSizeRel.ninja SimpleSubdir/all:Release)
run_cmake_build(Simple all-subdir Release SimpleSubdir/all:all)
run_ninja(Simple minsizerel-top build-MinSizeRel.ninja all)
run_cmake_build(Simple debug-in-release-graph-top Release all:Debug)
run_ninja(Simple all-clean-again build-Debug.ninja clean:all)
run_ninja(Simple all-top build-RelWithDebInfo.ninja all:all)
# Leave enough time for the timestamp to change on second-resolution systems
execute_process(COMMAND ${CMAKE_COMMAND} -E sleep 1)
file(TOUCH "${RunCMake_TEST_BINARY_DIR}/empty.cmake")
run_ninja(Simple reconfigure-config build-Release.ninja simpleexe)
execute_process(COMMAND ${CMAKE_COMMAND} -E sleep 1)
file(TOUCH "${RunCMake_TEST_BINARY_DIR}/empty.cmake")
run_ninja(Simple reconfigure-noconfig build.ninja simpleexe)
run_ninja(Simple default-build-file-clean build.ninja clean)
run_ninja(Simple default-build-file-clean-minsizerel build.ninja clean:MinSizeRel)
run_ninja(Simple default-build-file-all build.ninja all)

set(RunCMake_TEST_BINARY_DIR ${RunCMake_BINARY_DIR}/SimpleDefaultBuildAlias-build)
set(RunCMake_TEST_OPTIONS "-DCMAKE_CONFIGURATION_TYPES=Debug\\;Release\\;MinSizeRel\\;RelWithDebInfo;-DCMAKE_DEFAULT_BUILD_TYPE=Release;-DCMAKE_DEFAULT_CONFIGS=all;-DCMAKE_CROSS_CONFIGS=all")
run_cmake_configure(SimpleDefaultBuildAlias)
unset(RunCMake_TEST_OPTIONS)
include(${RunCMake_TEST_BINARY_DIR}/target_files.cmake)
run_ninja(SimpleDefaultBuildAlias target build.ninja simpleexe)
run_ninja(SimpleDefaultBuildAlias all build.ninja all)
run_ninja(SimpleDefaultBuildAlias clean build.ninja clean)

set(RunCMake_TEST_BINARY_DIR ${RunCMake_BINARY_DIR}/SimpleDefaultBuildAliasList-build)
set(RunCMake_TEST_OPTIONS "-DCMAKE_DEFAULT_BUILD_TYPE=Release;-DCMAKE_DEFAULT_CONFIGS=Debug\\;Release;-DCMAKE_CROSS_CONFIGS=all")
run_cmake_configure(SimpleDefaultBuildAliasList)
unset(RunCMake_TEST_OPTIONS)
include(${RunCMake_TEST_BINARY_DIR}/target_files.cmake)
run_ninja(SimpleDefaultBuildAliasList target-configs build.ninja simpleexe)
# IMPORTANT: This tests cmake --build . with no config using build.ninja
run_cmake_build(SimpleDefaultBuildAliasList all-configs "" all)
run_ninja(SimpleDefaultBuildAliasList all-relwithdebinfo build.ninja all:RelWithDebInfo)
run_ninja(SimpleDefaultBuildAliasList clean-configs build.ninja clean)

set(RunCMake_TEST_BINARY_DIR ${RunCMake_BINARY_DIR}/SimpleDefaultBuildAliasListCross-build)
set(RunCMake_TEST_OPTIONS "-DCMAKE_DEFAULT_BUILD_TYPE=RelWithDebInfo;-DCMAKE_DEFAULT_CONFIGS=all;-DCMAKE_CROSS_CONFIGS=Debug\\;Release")
run_cmake_configure(SimpleDefaultBuildAliasListCross)
unset(RunCMake_TEST_OPTIONS)
include(${RunCMake_TEST_BINARY_DIR}/target_files.cmake)
run_ninja(SimpleDefaultBuildAliasListCross target-configs build.ninja simpleexe)

unset(RunCMake_TEST_BINARY_DIR)

set(RunCMake_TEST_OPTIONS "-DCMAKE_CONFIGURATION_TYPES=Debug\\;Release;-DCMAKE_CROSS_CONFIGS=Debug\\;Release\\;RelWithDebInfo")
run_cmake(InvalidCrossConfigs)
unset(RunCMake_TEST_OPTIONS)

set(RunCMake_TEST_OPTIONS "-DCMAKE_CONFIGURATION_TYPES=Debug\\;Release;-DCMAKE_DEFAULT_BUILD_TYPE=RelWithDebInfo")
run_cmake(InvalidDefaultBuildFileConfig)
unset(RunCMake_TEST_OPTIONS)

set(RunCMake_TEST_OPTIONS "-DCMAKE_CROSS_CONFIGS=Debug\\;Release;-DCMAKE_DEFAULT_BUILD_TYPE=Release;-DCMAKE_DEFAULT_CONFIGS=Debug\\;Release\\;RelWithDebInfo")
run_cmake(InvalidDefaultConfigsCross)
unset(RunCMake_TEST_OPTIONS)

set(RunCMake_TEST_OPTIONS "-DCMAKE_DEFAULT_BUILD_TYPE=Release;-DCMAKE_DEFAULT_CONFIGS=all")
run_cmake(InvalidDefaultConfigsNoCross)
unset(RunCMake_TEST_OPTIONS)

set(RunCMake_TEST_OPTIONS "-DCMAKE_DEFAULT_BUILD_TYPE=Release")
run_cmake(DefaultBuildFileConfig)
unset(RunCMake_TEST_OPTIONS)

set(RunCMake_TEST_BINARY_DIR ${RunCMake_BINARY_DIR}/SimpleNoCross-build)
run_cmake_configure(SimpleNoCross)
include(${RunCMake_TEST_BINARY_DIR}/target_files.cmake)
run_cmake_build(SimpleNoCross debug-target Debug simpleexe)
run_ninja(SimpleNoCross debug-target build-Debug.ninja simplestatic:Debug)
run_ninja(SimpleNoCross relwithdebinfo-in-release-graph-target build-Release.ninja simplestatic:RelWithDebInfo)
run_cmake_build(SimpleNoCross relwithdebinfo-in-release-graph-all Release all:RelWithDebInfo)
run_cmake_build(SimpleNoCross relwithdebinfo-in-release-graph-clean Release clean:RelWithDebInfo)
run_ninja(SimpleNoCross all-target build-Debug.ninja simplestatic:all)
run_ninja(SimpleNoCross all-all build-Debug.ninja all:all)
run_cmake_build(SimpleNoCross all-clean Debug clean:all)

set(RunCMake_TEST_BINARY_DIR ${RunCMake_BINARY_DIR}/SimpleCrossConfigs-build)
set(RunCMake_TEST_OPTIONS "-DCMAKE_CROSS_CONFIGS=Debug\\;Release")
run_cmake_configure(SimpleCrossConfigs)
include(${RunCMake_TEST_BINARY_DIR}/target_files.cmake)
run_ninja(SimpleCrossConfigs release-in-release-graph build-Release.ninja simpleexe)
run_cmake_build(SimpleCrossConfigs debug-in-release-graph Release simpleexe:Debug)
run_cmake_build(SimpleCrossConfigs relwithdebinfo-in-release-graph Release simpleexe:RelWithDebInfo)
run_ninja(SimpleCrossConfigs relwithdebinfo-in-relwithdebinfo-graph build-RelWithDebInfo.ninja simpleexe:RelWithDebInfo)
run_ninja(SimpleCrossConfigs release-in-relwithdebinfo-graph build-RelWithDebInfo.ninja simplestatic:Release)
run_cmake_build(SimpleCrossConfigs all-in-relwithdebinfo-graph RelWithDebInfo simplestatic:all)
run_ninja(SimpleCrossConfigs clean-all-in-release-graph build-Release.ninja clean:all)
run_cmake_build(SimpleCrossConfigs all-all-in-release-graph Release all:all)
run_cmake_build(SimpleCrossConfigs all-relwithdebinfo-in-release-graph Release all:RelWithDebInfo)

set(RunCMake_TEST_BINARY_DIR ${RunCMake_BINARY_DIR}/Framework-build)
set(RunCMake_TEST_OPTIONS "-DCMAKE_CROSS_CONFIGS=all")
run_cmake_configure(Framework)
unset(RunCMake_TEST_OPTIONS)
include(${RunCMake_TEST_BINARY_DIR}/target_files.cmake)
run_cmake_build(Framework framework Debug all)

set(RunCMake_TEST_BINARY_DIR ${RunCMake_BINARY_DIR}/FrameworkDependencyAutogen-build)
set(RunCMake_TEST_OPTIONS "-DCMAKE_CROSS_CONFIGS=all")
run_cmake_configure(FrameworkDependencyAutogen)
unset(RunCMake_TEST_OPTIONS)
include(${RunCMake_TEST_BINARY_DIR}/target_files.cmake)
run_cmake_build(FrameworkDependencyAutogen framework Release test2:Debug)

set(RunCMake_TEST_NO_CLEAN 1)
set(RunCMake_TEST_BINARY_DIR ${RunCMake_BINARY_DIR}/CustomCommandGenerator-build)
set(RunCMake_TEST_OPTIONS "-DCMAKE_CONFIGURATION_TYPES=Debug\\;Release\\;MinSizeRel\\;RelWithDebInfo;-DCMAKE_CROSS_CONFIGS=all")
run_cmake_configure(CustomCommandGenerator)
unset(RunCMake_TEST_OPTIONS)
include(${RunCMake_TEST_BINARY_DIR}/target_files.cmake)
run_cmake_build(CustomCommandGenerator debug Debug generated)
run_cmake_command(CustomCommandGenerator-debug-generated "${TARGET_FILE_generated_Debug}")
run_ninja(CustomCommandGenerator release build-Release.ninja generated)
run_cmake_command(CustomCommandGenerator-release-generated "${TARGET_FILE_generated_Release}")
run_ninja(CustomCommandGenerator debug-clean build-Debug.ninja clean)
run_cmake_build(CustomCommandGenerator release-clean Release clean)
run_cmake_build(CustomCommandGenerator debug-in-release-graph Release generated:Debug)
run_cmake_command(CustomCommandGenerator-debug-in-release-graph-generated "${TARGET_FILE_generated_Debug}")
run_ninja(CustomCommandGenerator debug-in-release-graph-clean build-Debug.ninja clean:Debug)
run_ninja(CustomCommandGenerator release-in-debug-graph build-Debug.ninja generated:Release)
run_cmake_command(CustomCommandGenerator-release-in-debug-graph-generated "${TARGET_FILE_generated_Release}")
unset(RunCMake_TEST_NO_CLEAN)

set(RunCMake_TEST_BINARY_DIR ${RunCMake_BINARY_DIR}/CustomCommandsAndTargets-build)
set(RunCMake_TEST_OPTIONS "-DCMAKE_CROSS_CONFIGS=all")
run_cmake_configure(CustomCommandsAndTargets)
unset(RunCMake_TEST_OPTIONS)
include(${RunCMake_TEST_BINARY_DIR}/target_files.cmake)
run_cmake_build(CustomCommandsAndTargets release-command Release SubdirCommand)
#FIXME Get this working
#run_ninja(CustomCommandsAndTargets minsizerel-command build-MinSizeRel.ninja CustomCommandsAndTargetsSubdir/SubdirCommand)
run_ninja(CustomCommandsAndTargets debug-command build-Debug.ninja TopCommand)
run_ninja(CustomCommandsAndTargets release-target build-Release.ninja SubdirTarget)
run_cmake_build(CustomCommandsAndTargets debug-target Debug TopTarget)
run_cmake_build(CustomCommandsAndTargets debug-in-release-graph-postbuild Release SubdirPostBuild:Debug)
run_ninja(CustomCommandsAndTargets release-postbuild build-Release.ninja SubdirPostBuild)
run_cmake_build(CustomCommandsAndTargets debug-targetpostbuild Debug TopTargetPostBuild)
run_ninja(CustomCommandsAndTargets release-targetpostbuild build-Release.ninja SubdirTargetPostBuild)

unset(RunCMake_TEST_BINARY_DIR)

run_cmake(CustomCommandDepfile)

set(RunCMake_TEST_BINARY_DIR ${RunCMake_BINARY_DIR}/PostfixAndLocation-build)
set(RunCMake_TEST_OPTIONS "-DCMAKE_CONFIGURATION_TYPES=Debug\\;Release;-DCMAKE_CROSS_CONFIGS=all")
run_cmake_configure(PostfixAndLocation)
unset(RunCMake_TEST_OPTIONS)
include(${RunCMake_TEST_BINARY_DIR}/target_files.cmake)
run_cmake_build(PostfixAndLocation release-in-release-graph Release mylib:Release)
run_cmake_build(PostfixAndLocation debug-in-release-graph Release mylib:Debug)

set(RunCMake_TEST_BINARY_DIR ${RunCMake_BINARY_DIR}/Clean-build)
run_cmake_configure(Clean)
include(${RunCMake_TEST_BINARY_DIR}/target_files.cmake)
run_cmake_build(Clean release Release)
run_ninja(Clean release-notall build-Release.ninja exenotall)
run_cmake_build(Clean release-clean Release clean)

set(RunCMake_TEST_BINARY_DIR ${RunCMake_BINARY_DIR}/AdditionalCleanFiles-build)
set(RunCMake_TEST_OPTIONS "-DCMAKE_CONFIGURATION_TYPES=Debug\\;Release\\;MinSizeRel\\;RelWithDebInfo;-DCMAKE_CROSS_CONFIGS=all")
run_cmake_configure(AdditionalCleanFiles)
unset(RunCMake_TEST_OPTIONS)
run_cmake_build(AdditionalCleanFiles release-clean Release clean)
run_ninja(AdditionalCleanFiles all-clean build-Debug.ninja clean:all)

set(RunCMake_TEST_BINARY_DIR ${RunCMake_BINARY_DIR}/Install-build)
set(RunCMake_TEST_OPTIONS "-DCMAKE_INSTALL_PREFIX=${RunCMake_TEST_BINARY_DIR}/install;-DCMAKE_CROSS_CONFIGS=all")
run_cmake_configure(Install)
unset(RunCMake_TEST_OPTIONS)
include(${RunCMake_TEST_BINARY_DIR}/target_files.cmake)
run_cmake_build(Install release-install Release install)
run_ninja(Install debug-in-release-graph-install build-Release.ninja install:Debug)

# FIXME Get this working
#set(RunCMake_TEST_BINARY_DIR ${RunCMake_BINARY_DIR}/AutoMocExecutable-build)
#run_cmake_configure(AutoMocExecutable)
#run_cmake_build(AutoMocExecutable debug-in-release-graph Release exe)

# Need to test this manually because run_cmake() adds --no-warn-unused-cli
set(RunCMake_TEST_BINARY_DIR ${RunCMake_BINARY_DIR}/NoUnusedVariables-build)
run_cmake_command(NoUnusedVariables ${CMAKE_COMMAND} ${CMAKE_CURRENT_LIST_DIR}
  -G "Ninja Multi-Config"
  "-DRunCMake_TEST=NoUnusedVariables"
  "-DCMAKE_CROSS_CONFIGS=all"
  "-DCMAKE_DEFAULT_BUILD_TYPE=Debug"
  "-DCMAKE_DEFAULT_CONFIGS=all"
  )

if(CMake_TEST_CUDA)
  set(RunCMake_TEST_BINARY_DIR ${RunCMake_BINARY_DIR}/CudaSimple-build)
  run_cmake_configure(CudaSimple)
  include(${RunCMake_TEST_BINARY_DIR}/target_files.cmake)
  run_cmake_build(CudaSimple debug-target Debug simplecudaexe)
  run_ninja(CudaSimple all-clean build-Debug.ninja clean:Debug)
endif()

if(CMake_TEST_Qt5)
  set(RunCMake_TEST_BINARY_DIR ${RunCMake_BINARY_DIR}/Qt5-build)
  set(RunCMake_TEST_OPTIONS "-DCMAKE_CROSS_CONFIGS=all")
  run_cmake_configure(Qt5)
  unset(RunCMake_TEST_OPTIONS)
  include(${RunCMake_TEST_BINARY_DIR}/target_files.cmake)
  run_cmake_build(Qt5 debug-in-release-graph Release exe:Debug)
endif()
