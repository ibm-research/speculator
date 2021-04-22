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

    %define BASE 0x10000000

    section .data
    passphrase: db 'Y0U_W1ll_N0t_G3t_M3!',0
    secret_len: equ $-passphrase
    input: dq 0
    dev_file: db '/dev/cpu/',VICTIM_PROCESS_STR,'/msr',0
    fd: dq 0
    val: dq 0
    len: equ $-val
    array: resb 2048
    secret: db 0
    addr: dq 0
    align 1024
    addr2: dq 0
    align 1024
    ;##### DATA STARTS HERE ########

    ;##### DATA ENDS HERE ########

    section .text
    global perf_test_entry:function
    global snippet:function
    global gadget:function
    global secret:function
    global correct:function
    global indirect:function

    extern usleep
    extern atoi
    extern set_write_code
    extern print_val
    extern no_arg_err
    extern out_of_bound

bti_call:
    call [addr]
    ret

perf_test_entry:
    push rbp
    mov rbp, rsp
    mov rax, [rsp+8] ; argc
    cmp rax, 2
    je .cont
    call no_arg_err
.cont:
    mov rax, [rsp+24] ; argv[1]
    mov QWORD[input], rax
    check_pinning VICTIM_PROCESS;# ATTACK_PROCESS
    msr_open
    msr_seek
.atoi:
    mov rax, QWORD[input]
    mov rdi, rax
    call atoi
    cmp rax, secret_len
    jle .cont2
    call out_of_bound
.cont2
    add rax, passphrase
    mov al, BYTE[rax]
    mov BYTE[secret], al
    xor rax, rax
    mov ax, WORD[secret]
    shl eax, 16
    add rax, BASE
    mov QWORD[addr2], rax
    mov rdi, rax
    mov rsi, rax
    call print_val
    ;mov QWORD[addr2], verify <- re-direct to verify to test reverseBTI with PMC
    align 512

victim:
    jmpnext256
    jmpnext256
    mov QWORD[addr], correct
    clflush[addr]
    lfence

    reset_counter
    start_counter
    .call:
        call bti_call

    stop_counter

    msr_close
    exit 0

align 1024
gadget:
    nop
    call [addr2]
    ret
    lfence


align 1024
verify:
    mov DWORD[array], eax
    mov DWORD[array+4], edx
    movq xmm0, QWORD[array]
    ret

align 1024
correct:
    ret

