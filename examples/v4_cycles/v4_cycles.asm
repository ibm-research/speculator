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
    warmup_cnt: db 1
    fill: times 63 db 0

    warmup_cnt_fake: dq 1 
    fill2: times 60 db 0

    array: times 64 db 0

    dev_file: db '/dev/cpu/',VICTIM_PROCESS_STR,'/msr',0
    fd: dq 0
    offset: dq 0
    val: dq 0
    len: equ $-val
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
    lfence
    pipeline_flush
    reset_counter
    start_counter
    mov rsi, fill2
    mov rdi, fill2
    mov rax, rdi
    xor rdx, rdx
    mov rcx, 2
    div rcx
    mov rdi, rax
    mov rax, 2
    mov rcx, 10
    mul rdi
    mov rdi, rax
    mov rdx, fill
    mov al, 0x10
    mov [rdi+rcx], al
    movzx r8, byte[rsi+rcx]
    shl r8, byte 0x1
    ;##### SNIPPET STARTS HERE ######

    ;##### SNIPPET ENDS HERE ######

    ; UNCOMMENT TO TEST CYCLES span for speculation

    mov QWORD[warmup_cnt_fake], rdx
    mov DWORD[warmup_cnt_fake + 4], edx
    mov rax, QWORD[warmup_cnt_fake]

    ; OR

    ;mulps xmm0,xmm1

    stop_counter

    msr_close
    exit 0
