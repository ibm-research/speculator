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
    stored_ret:  dq 0
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

    start_counter
    mov QWORD[counter], 10
    mov QWORD[target], perf_test_entry.back
.start:
    reset_counter
    call start
.back:
    cmp QWORD[counter], 0
    jl .exit
    jg .skip

    mov QWORD[target], hijacked ; target for overwrite

.skip:
    dec QWORD[counter]
    jmp .start
.exit:
    ret

start:
    ; save old ret
    mov rax,[rsp]
    mov [stored_ret], rax

    ; architectural overwrite
    mov rax, [target]
    mov [rsp], rax

    ; evicting original value
    clflush [stored_ret]
    lfence

    ; check current value with original
    ; to see if overwrite has happened
    mov rax, [rsp]
    cmp rax, [stored_ret]
    jne my_exit

    ; return speculate with the arch overwritten value
    ret

my_exit:
    stop_counter

    msr_close
    exit 0
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
