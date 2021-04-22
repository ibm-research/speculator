# Copyright 2019 IBM Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

cmake_minimum_required (VERSION 3.1)
project (SPECULATOR VERSION 1.1.0 LANGUAGES C ASM)

cmake_policy(SET CMP0048 NEW)

include_directories(${CMAKE_CURRENT_SOURCE_DIR}/include)

message(STATUS "Quering CPU type")
execute_process (COMMAND cat /proc/cpuinfo
                 COMMAND grep vendor_id
                 COMMAND head -n 1
                 COMMAND cut -d " " -f 2
                 OUTPUT_VARIABLE VENDOR
                 OUTPUT_STRIP_TRAILING_WHITESPACE)
message(STATUS "CPU Detected -- ${VENDOR}")

IF (NOT EXISTS speculator.json)
    IF(${VENDOR} STREQUAL "AuthenticAMD")
        configure_file(${CMAKE_CURRENT_SOURCE_DIR}/confs/speculator.json.amd.template ${CMAKE_CURRENT_SOURCE_DIR}/speculator.json @ONLY)
        message (STATUS "Generated default AMD counters config file")
    ELSEIF(${VENDOR} STREQUAL "GenuineIntel")
        configure_file(${CMAKE_CURRENT_SOURCE_DIR}/confs/speculator.json.intel.template ${CMAKE_CURRENT_SOURCE_DIR}/speculator.json @ONLY)
        message (STATUS "Generated default Intel counters config file")
    ELSE()
        message(FATAL_ERROR "CPU not yet supported: ${VENDOR}")
    ENDIF()
ENDIF()

configure_file(speculator.json speculator.json @ONLY)

IF (${VENDOR} STREQUAL "AuthenticAMD")
    message(STATUS "Generating templates header for " ${VENDOR})
    execute_process(
        COMMAND ${CMAKE_COMMAND} -E create_symlink
        ${CMAKE_CURRENT_SOURCE_DIR}/tests/include/x86/common.inc.in
        ${CMAKE_CURRENT_SOURCE_DIR}/tests/common.inc.in
        )
    execute_process(
        COMMAND ${CMAKE_COMMAND} -E create_symlink
        ${CMAKE_CURRENT_SOURCE_DIR}/tests/include/x86/amd.inc
        ${CMAKE_CURRENT_SOURCE_DIR}/tests/amd.inc
        )
    execute_process(
        COMMAND ${CMAKE_COMMAND} -E create_symlink
        ${CMAKE_CURRENT_SOURCE_DIR}/tests/include/x86/signals.inc
        ${CMAKE_CURRENT_SOURCE_DIR}/tests/signals.inc
        )

ELSEIF (${VENDOR} STREQUAL "GenuineIntel")
    message(STATUS "Generating templates header for " ${VENDOR})
    execute_process(
        COMMAND ${CMAKE_COMMAND} -E create_symlink
        ${CMAKE_CURRENT_SOURCE_DIR}/tests/include/x86/common.inc.in
        ${CMAKE_CURRENT_SOURCE_DIR}/tests/common.inc.in
        )
    execute_process(
        COMMAND ${CMAKE_COMMAND} -E create_symlink
        ${CMAKE_CURRENT_SOURCE_DIR}/tests/include/x86/intel.inc
        ${CMAKE_CURRENT_SOURCE_DIR}/tests/intel.inc
        )
    execute_process(
        COMMAND ${CMAKE_COMMAND} -E create_symlink
        ${CMAKE_CURRENT_SOURCE_DIR}/tests/include/x86/signals.inc
        ${CMAKE_CURRENT_SOURCE_DIR}/tests/signals.inc
        )

ENDIF()

# Adding CMake Clean target
if(${CMAKE_GENERATOR} STREQUAL "Ninja")
  add_custom_target(Clean COMMAND ninja clean)
else()
  add_custom_target(Clean COMMAND ${MAKE} clean)
endif()

add_custom_command(TARGET Clean COMMAND rm -f
    ${CMAKE_CURRENT_SOURCE_DIR}/tests/*.in ${CMAKE_CURRENT_SOURCE_DIR}/tests/*.inc )


add_subdirectory(tests)
add_subdirectory(src)

install(FILES speculator.json
        DESTINATION . )

install(DIRECTORY "scripts"
        DESTINATION .
        USE_SOURCE_PERMISSIONS)

install(DIRECTORY
        DESTINATION "results")
