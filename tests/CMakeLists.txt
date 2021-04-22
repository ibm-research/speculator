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

cmake_minimum_required (VERSION 2.6)

enable_language(ASM_NASM)
if (CMAKE_ASM_NASM_COMPILER_LOADED)
    set(CAN_USE_ASSEMBLER TRUE)
endif(CMAKE_ASM_NASM_COMPILER_LOADED)

# Information for libc
set(LIBC
    ${CMAKE_CURRENT_SOURCE_DIR}/musl/libc.a)

set(LIBCDYN
    ${CMAKE_CURRENT_SOURCE_DIR}/musl/libc.so)

# Look for .asm file inside the asm folder
file(GLOB_RECURSE asmFiles RELATIVE ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/*.asm)

list(LENGTH asmFiles asmFilesN)
message(STATUS "Found ${asmFilesN} asm files")

file(GLOB_RECURSE allcFiles RELATIVE ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/*.c)

list(LENGTH allcFiles allcFilesN)
message(STATUS "Found ${allcFilesN} c files")

add_compile_options(-I ${CMAKE_CURRENT_SOURCE_DIR}/ )


# Set compiler flags to remove optimizations
set (CMAKE_C_FLAGS ${CMAKE_C_FLAGS} -O0)

# For each .asm file and possible .c respectively, compile and link them together
# in different targets
# NOTE .asm and .c file should have the same name
foreach (asmFileName ${asmFiles})
    string(REPLACE ".asm" ".c" cFileName ${asmFileName})
    string(REPLACE ".asm" "" DirName ${asmFileName})
    string(REGEX REPLACE ".*/" "" TargetName ${DirName})

    set_source_files_properties(${asmFileName} PROPERTIES COMPILE_FLAGS
    "-f elf64")


    if(EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/${cFileName})
        message (STATUS "Found test " ${asmFileName} " " ${cFileName})

        list (REMOVE_ITEM allcFiles ${cFileName})

        if (CANARY)
            add_executable(${TargetName} ${asmFileName} ${LIBCDYN} ${cFileName})
            message("\tSetting full stack protection")
            set_source_files_properties(${cFileName} PROPERTIES COMPILE_FLAGS
                "-fstack-protector-all")
        else()
            message("\tNO full stack protection")
            add_executable(${TargetName} ${asmFileName} ${LIBC} ${cFileName})
            set_source_files_properties(${cFileName} PROPERTIES COMPILE_FLAGS
            "-fno-stack-protector")
        endif()

    else()
        message (STATUS "Found test " ${asmFileName})
        add_executable(${TargetName} ${asmFileName} ${LIBC})
        set_target_properties(${TargetName} PROPERTIES LINKER_LANGUAGE "C" )
    endif()

    set_property(TARGET ${TargetName} PROPERTY C_STANDARD 11)

    if (NOT CANARY)
        message("\tlinking with libc.a")
        target_link_libraries(${TargetName} -lrt -static -nostartfiles -nostdlib
        -fno-asynchronous-unwind-tables -fno-exceptions -Wl,-eperf_test_entry
        -Wl,--build-id=none -Wl,--as-needed ${LIBC})
    else ()
        message("\tlinking with libc.so")
        target_link_libraries(${TargetName} -lrt -nostartfiles -no-pie -Wl,-eperf_test_entry)
    endif()

    # Set target installation
    install(TARGETS ${TargetName}
        RUNTIME DESTINATION tests/${DirName})
endforeach(asmFileName)

# Scan .c files and compile them as separate targets
foreach (cFileName ${allcFiles})
    message(STATUS "Found test " ${cFileName})
    string(REPLACE ".c" "" DirName ${cFileName})
    string(REGEX REPLACE ".*/" "" TargetName ${DirName})

    add_executable(${TargetName} ${cFileName})
    set_target_properties(${TargetName} PROPERTIES C_STANDARD 11)
    install(TARGETS ${TargetName}
        RUNTIME DESTINATION tests/${DirName})
endforeach(cFileName)
