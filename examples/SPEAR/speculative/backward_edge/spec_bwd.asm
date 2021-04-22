; Copyright 2021 IBM Corporation
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

[BITS 64]
    %include "common.inc"
    %include "pmc.inc"

    section .data

    dev_file: db '/dev/cpu/',VICTIM_PROCESS_STR,'/msr',0
    ;dev_file: db '/dev/cpu/',ATTACKER_PROCESS_STR,'/msr',0
    fd: dq 0
    warmup_cnt_fake: dd 1
    offset: dq 0
    val: dq 0
    len: equ $-val
    array: resb 128
    warmup_cnt: dd 1
    filler: resb 256
    target: dq 0
    ;##### DATA STARTS HERE ########

    ;##### DATA ENDS HERE ########

    section .text
    global perf_test_entry:function
    global snippet:function
    global victim:function

    extern set_write_code

perf_test_entry:
    push rbp
    mov rbp, rsp
    sub rsp, len

    mov QWORD[target], correct

    check_pinning VICTIM_PROCESS
    ;check_pinning ATTACKER_PROCESS
    msr_open
    msr_seek
.data:
    clflush [warmup_cnt]
    mov eax, 0
    cpuid
    lfence
    reset_counter
    start_counter
    mov ebx, DWORD[warmup_cnt]
    cmp ebx, 12
    je .else
    ;##### SNIPPET STARTS HERE ######
    call victim
.back
    ;##### SNIPPET ENDS HERE ######
    lfence
.else:
    lfence
    stop_counter

    inc DWORD[warmup_cnt]
    cmp DWORD[warmup_cnt], 12
    jl .again
    jg .skip
    mov QWORD[target], hijacked
.again
    jmp .data
.skip:
    msr_close
    exit 0

victim:
    mov rax, QWORD[target]
    mov QWORD[rsp], rax
    ret
    lfence

hijacked:
    mov DWORD[array], eax
    mov DWORD[array+4], edx
    movq xmm0, QWORD[array]

    mov DWORD[array], eax
    mov DWORD[array+4], edx
    movq xmm0, QWORD[array]

    mov DWORD[array], eax
    mov DWORD[array+4], edx
    movq xmm0, QWORD[array]


    lfence
    ret

correct:
    jmp perf_test_entry.back
    ret
