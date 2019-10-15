; Copyright 2019 IBM Corporation
;
; Licensed under the Apache License, Version 2.0 (the "License");
; you may not use this file except in compliance with the License.
; You may obtain a copy of the License at
;
;     http://www.apache.org/licenses/LICENSE-2.0
;
; Unless required by applicable law or agreed to in writing, software
; distributed under the License is distributed on an "AS IS" BASIS,
; WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
; See the License for the specific language governing permissions and
; limitations under the License.

%macro msr_seek 0
    mov rax, SYS_GETUID
    cmp rax, 0
    jne .skip
    mov rax, SYS_LSEEK
    mov rdi, [fd] ; fd
    mov rsi, 0x38F ; offset
    mov rdx, 0 ;SEEK_SET
    syscall
.skip:
%endmacro

%macro reset_counter 0
    mov rax, SYS_GETUID
    cmp rax, 0
    jne skip
    mov rcx, 8
    %%.reset_pr_counters:
    push rcx
    mov rax, SYS_PWRITE64
    mov rdi, [fd]
    mov QWORD[val], 0
    mov rsi, val
    mov rdx, len
    mov r10, 0xC1
    add r10, rcx
    sub r10, 1
    syscall
    pop rcx
    loopnz %%.reset_pr_counters

    mov rcx, 3
    %%.reset_fx_counters:
    push rcx
    mov rax, SYS_PWRITE64
    mov rdi, [fd]
    mov QWORD[val], 0
    mov rsi, val
    mov rdx, len
    mov r10, 0x309
    add r10, rcx
    sub r10, 1
    syscall
    pop rcx
    loopnz %%.reset_fx_counters
.skip:
%endmacro

%macro start_counter 0
    mov rax, SYS_GETUID
    cmp rax, 0
    jne .skip
    mov rax, SYS_WRITE
    mov rdi, [fd] ; fd
    mov QWORD[val], 7 ; 15 | (7 << 32)
    shl QWORD[val], 32
    or QWORD[val], 15

    mov rsi, val
    mov rdx, len ;len
    syscall
.skip:
%endmacro

%macro stop_counter 0
    mov rax, SYS_GETUID
    cmp rax, 0
    jne .skip
    mov rdi, [fd]
    mov rsi, val
    mov rdx, len
    mov rax, SYS_WRITE
    mov QWORD[val], 0
    syscall
.skip:
%endmacro

%macro jmpnext 0
    cmp rax, rax
    jle %%.label
    %%.label:
%endmacro

%macro jmpnext2 0
    jmpnext
    jmpnext
%endmacro

%macro jmpnext4 0
    jmpnext2
    jmpnext2
%endmacro

%macro jmpnext8 0
    jmpnext4
    jmpnext4
%endmacro

%macro jmpnext16 0
    jmpnext8
    jmpnext8
%endmacro

%macro jmpnext32 0
    jmpnext16
    jmpnext16
%endmacro

%macro jmpnext64 0
    jmpnext32
    jmpnext32
%endmacro

%macro jmpnext128 0
    jmpnext64
    jmpnext64
%endmacro

%macro jmpnext256 0
    jmpnext128
    jmpnext128
%endmacro

%macro callnext 0
    call %%.label
    ret
    %%.label:
%endmacro

%macro pushret 0
    push %%.label
    clflush[rsp]
    mfence
    ret
    %%.label:
%endmacro

