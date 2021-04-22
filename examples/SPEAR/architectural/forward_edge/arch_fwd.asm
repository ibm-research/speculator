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
    offset: dq 0
    val: dq 0
    len: equ $-val
    array: resb 128
    warmup_cnt: dd 11
    filler: resb 256
    stored_target: dq 0
    filler2: resb 256
    counter: dq 0
    target: dq 0
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
    ;check_pinning ATTACKER_PROCESS
    msr_open
    msr_seek

    reset_counter
    start_counter

    mov QWORD[counter], 10
    mov QWORD[target], correct
    mov QWORD[stored_target], correct
.start:
    reset_counter
    ; Flush valued used for checking forward edge integrity
    clflush [stored_target]
    lfence
    ; Check if forward edge has been modified and fail if it is
    mov rax, QWORD[target]
    cmp rax, QWORD[stored_target]
    jne my_exit
    ; Perform the indirect call
    call QWORD[target]
.back:
    cmp QWORD[counter], 0
    jl .exit
    jg .skip

    mov QWORD[target], hijacked
.skip:
    dec QWORD[counter]
    jmp .start
.exit:
    ret

correct:
    lfence
    ret

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

    hlt
    lfence
    ret

my_exit:
    msr_close
    exit 0

