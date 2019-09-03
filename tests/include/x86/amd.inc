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

%macro reset_counter 0
    mov rcx, 4
    %%.reset_pr_counters:
    push rcx
    mov rax, SYS_PWRITE64
    mov rdi, [fd]
    mov QWORD[val], 0
    mov rsi, val
    mov rdx, len
    mov r10, 0xc0010004 ; offset - PerfCtr0 + loop iterator
    add r10, rcx
    sub r10, 1
    syscall
    pop rcx
    loopnz %%.reset_pr_counters
%endmacro

%macro msr_seek 0
%endmacro

%macro start_counter 0
%endmacro

%macro stop_counter 0
%endmacro

; don't use this, just reset counters
%macro save_mask_unused 0
    mov rcx, 4
    %%.read_eventsel:
    push rcx
    mov rax, SYS_PREAD64
    mov rdi, [fd] ; fd
    mov rsi, val
    mov rdx, len
    mov r10, 0xc0010000; offset - PerfSel0 + loop iterator
    add r10, rcx
    sub r10, 1
    syscall
    pop rcx
    mov r8, rcx
    sub r8, 1
    imul r8, len
    add r8, sel
    mov QWORD[r8], rax
    loopnz %%.read_eventsel

%endmacro

; don't use this, just reset counters
%macro start_counter_unused 0
    mov rcx, 4
    %%.enable_counters:
    push rcx
    mov rax, SYS_PWRITE64
    mov rdi, [fd]
    mov r8, rcx
    sub r8, 1
    imul r8, len
    add r8, sel
    or QWORD[r8], 0x400000 ; PERF_EN
    mov rsi, r8
    mov rdx, len
    mov r10, 0xc0010000 ; offset - PerfSel0 + loop iterator
    add r10, rcx
    sub r10, 1
    syscall
    pop rcx
    loopnz %%.enable_counters

%endmacro

; don't use this, just reset counters
%macro stop_counter_unused 0
    mov rcx, 4
    %%.disable_counters:
    push rcx
    mov rax, SYS_PWRITE64
    mov rdi, [fd]
    mov r8, rcx
    sub r8, 1
    imul r8, len
    add r8, sel
    and QWORD[r8], ~0x400000 ; PERF_EN
    mov rsi, r8
    mov rdx, len
    mov r10, 0xc0010000 ; offset - PerfSel0 + loop iterator
    add r10, rcx
    sub r10, 1
    syscall
    pop rcx
    loopnz %%.disable_counters
%endmacro
