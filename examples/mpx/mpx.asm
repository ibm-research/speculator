i; Copyright 2021 IBM Corporation
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
    %include "signals.inc"
    %include "pmc.inc"

    %macro setup_mpx 0
        ; read cpu state first
        mov eax, DWORD(0x18) ; lower 32bit of mask
        mov edx, 0 ; higher 32bit of mask
        mov rdi, xstate
        xrstor64 [rdi]
        ; set mpx params in memory
        mov rdx, 0x10
        mov [xstate+0x200], rdx ; xsave_buf->xsave_hdr.xstate_bv = 0x10;
        mov rdx, 0x1 ; 1 << MPX_ENABLE_BIT_NO
        or rdx, 0x2 ; 1 << BNDPRESERVE_BIT_NO
        mov [xstate+0x400], rdx ; // enable mpx xsave_buf->bndcsr.cfg_reg_u = ...
        xor rdx, rdx
        mov [xstate+0x408], rdx ; xsave_buf->bndcsr.status_reg = 0;
        ; write cpu state
        mov eax, DWORD(0x10) ; lower 32bit of mask we want to write
        mov edx, 0 ; higher 32bit
        mov rdi, xstate
        xrstor64 [rdi]
    %endmacro

    ; sys_rt_sigaction - alter an action taken by a process
    ; @sig: signal to be sent
    ; @act: new sigaction
    ; @oact: used to save the previous sigaction
    ; @sigsetsize: size of sigset_t type

    %macro setup_signal_handler 0
        mov     QWORD [sigaction.sa_handler], handler
        mov     QWORD [sigaction.sa_restorer], restorer
        mov     eax, SA_RESTART | SA_RESTORER | SA_SIGINFO
        mov     DWORD [sigaction.sa_flags], eax
        mov     rax, SYS_RT_SIGACTION ; system call number
        mov     rdi, SIGSEGV ; signal number
        lea     rsi, [sigaction] ; sigaction struct
        xor     rdx, rdx ; save previous sigaction (no)
        mov     r10, NSIG_WORDS ; sigsetsize
        syscall
        cmp     eax, 0
    %endmacro

    %macro print 2
        mov rax, SYS_WRITE
        mov rdi, 1 ; stdout
        mov rsi, %1
        mov rdx, %2 ;len
        syscall
    %endmacro
 
    section .data
    warmup_cnt: dq 1

    dev_file: db '/dev/cpu/',VICTIM_PROCESS_STR,'/msr',0
    msg_bounds: db "mpx bounds", 0xA, 0
    fd: dq 0
    val: dq 0
    len: equ $-val
    array: times 40 db 0
    ALIGN 64
    xstate: times 0x1000 db 0
    SIGACTION sigaction
    ;##### DATA STARTS HERE ########

    ;##### DATA ENDS HERE ########

    section .bss

    section .text
    global perf_test_entry:function

perf_test_entry:
    push rbp
    mov rbp, rsp
    sub rsp, len

    check_pinning VICTIM_PROCESS
    ; signal handler
    setup_signal_handler
    jne .exit

    msr_open
    msr_seek

    ; mpx setup
    setup_mpx
    ; setup bounds
    lea rax, [array]
    bndmk bnd1, [rax+10] ; make bounds

.data:
    clflush [warmup_cnt]
    lfence
    reset_counter
    start_counter

    ; mpx stuff below
    lea r11, [array]
    add r11, [warmup_cnt]
    bndcl bnd1, [r11] ; check lower
    bndcu bnd1, [r11] ; check upper
    ;##### SNIPPET STARTS HERE ######

    ;##### SNIPPET ENDS HERE ######
    lea r8, [rel msg_bounds]

.else:
    lfence
    stop_counter

    inc QWORD[warmup_cnt]
    cmp QWORD[warmup_cnt], 13
    jl .data
.exit:
    msr_close
    exit 0

; rdi=signum, rsi=siginfo_t*, rdx=sigcontext*
handler:
    ; trap number should be 5 for TRAP_BR
    mov r10,[rdx+UCONTEXT_STRUC.uc_mcontext+SIGCONTEXT_STRUC.trapno]
    cmp r10, 5
    jne .exit
    push rdx
    print msg_bounds, 12
    ; set RIP to continue after the fault
    pop rdx
    mov r10, QWORD(perf_test_entry.else)
    mov [rdx+UCONTEXT_STRUC.uc_mcontext+SIGCONTEXT_STRUC.rip], r10
    .exit:
    ret

restorer:
    mov     rax, SYS_RT_SIGRETURN 
    syscall
