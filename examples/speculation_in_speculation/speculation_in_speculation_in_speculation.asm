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
    warmup_cnt: db 1 ; first cache line
    fill: times 63 db 0

    warmup_cnt_fake: dw 2 ; second cache line
    fill2: times 62 db 0

    warmup_cnt_fake2: db 1 ; third cache line
    fill3: times 63 db 0

    dev_file: db '/dev/cpu/',VICTIM_PROCESS_STR,'/msr',0 ; rest of the data
    fd: dq 0
    val: dq 0
    len: equ $-val
    lea_array: times 40 db 0
    ;##### DATA STARTS HERE ########

    ;##### DATA ENDS HERE ########

    section .text
    global perf_test_entry:function
    global snippet:function

perf_test_entry:
    push rbp
    mov rbp, rsp
    sub rsp, len

    check_pinning VICTIM_PROCESS
    msr_open
    msr_seek
.data:
    clflush [warmup_cnt]
    clflush [warmup_cnt_fake]
    mov eax, 0
    cpuid
    lfence
    reset_counter
    start_counter
    mov edx, 0
    mov ecx, 2048
    mov eax, DWORD[warmup_cnt_fake]
    div ecx
    mov ecx, 2
    xor edx, edx
    div ecx
    cmp eax, 1
    je .else
    .data2:
        mov ebx, DWORD[warmup_cnt]
        cmp ebx, 12
        je .else2
        .data3:
            mov ebx, DWORD[warmup_cnt_fake2]
            cmp ebx, 12
            je .else3
            mov rax, 10
            lea rax, [lea_array+rax*2]
            ;##### SNIPPET STARTS HERE ######

            ;##### SNIPPET ENDS HERE ######
        .else3:
            mov rax, 10
            lea rax, [lea_array+rax*2]
    .else2:
        mov rax, 10
        lea rax, [lea_array+rax*2]
.else:
    mov rax, 10
    lea rax, [lea_array+rax*2]
    lfence
    stop_counter

    mov ax, 2
    mul DWORD[warmup_cnt_fake]
    mov DWORD[warmup_cnt_fake], eax
    inc DWORD[warmup_cnt_fake2]
    inc DWORD[warmup_cnt]
    cmp DWORD[warmup_cnt], 13
    jl .data

    msr_close
    exit 0
