# Copyright 2021 IBM Corporation
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

# Define speculator_mon executable target
add_executable (speculator_mon speculator_monitor.c)

target_include_directories(speculator_mon PRIVATE ${CMAKE_BINARY_DIR})

IF (${VENDOR} STREQUAL "AuthenticAMD")
    target_compile_definitions(speculator_mon PRIVATE AMD)
ELSEIF (${VENDOR} STREQUAL "GenuineIntel")
    target_compile_definitions(speculator_mon PRIVATE INTEL)
ENDIF()

# Add link options for speculator_mon
target_link_libraries(speculator_mon json-c pfm pthread)

target_compile_options(speculator_mon PRIVATE "-Wall")
target_compile_options(speculator_mon PRIVATE "-Werror")
target_compile_options(speculator_mon PRIVATE "--pedantic-errors")

set_property(TARGET speculator_mon PROPERTY C_STANDARD 11)

#### DEBUG OPTION
IF (DEBUG)
    message(STATUS "Debug Mode ON")
    unset(DEBUG CACHE)
    target_compile_definitions(speculator_mon PRIVATE DEBUG)
ELSE()
    message(STATUS "Debug Mode OFF")
    unset(DEBUG CACHE)
ENDIF()
####

#### DUMMY OPTION
IF (DUMMY)
    message(STATUS "Dummy Load Mode ON -- " ${DUMMY})
    target_compile_definitions(speculator_mon PRIVATE DUMMY)
    set(DUMMY_NAME ${DUMMY})
    unset(DUMMY CACHE)
ELSE()
    message(STATUS "Dummy Load Mode OFF")
    unset(DUMMY CACHE)
ENDIF()
####

#### VICTIM
IF (VICTIM)
    message(STATUS "Victim specified core -- " ${VICTIM})
    set(VICTIM_CORE ${VICTIM})
    unset(VICTIM CACHE)
ELSE()
    message(STATUS "Victim core set to default -- " 0)
    set(VICTIM_CORE 0)
    unset(VICTIM CACHE)
ENDIF()
####

#### ATTACKER
IF (ATTACKER)
    message(STATUS "Attacker specified core -- " ${ATTACKER})
    set(ATTACKER_CORE ${ATTACKER})
    unset(ATTACKER CACHE)
ELSE()
    message(STATUS "Attacker core set to default -- " 4)
    set(ATTACKER_CORE 4)
    unset(ATTACKER CACHE)
ENDIF()
####


install(TARGETS speculator_mon
        RUNTIME DESTINATION . )

configure_file (${CMAKE_SOURCE_DIR}/include/config.h.in ${CMAKE_BINARY_DIR}/config.h)
configure_file (${CMAKE_SOURCE_DIR}/tests/common.inc.in ${CMAKE_SOURCE_DIR}/tests/common.inc)
unset(DUMMY_NAME CACHE)
unset(VICTIM_CORE CACHE)
unset(ATTACKER_CORE CACHE)
