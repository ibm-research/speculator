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
    %define SYS_MMAP 9
    %define SYS_MPROT 10
    %define SYS_EXIT 60
    %define SYS_WRITE 1
    %define SYS_OPEN 2
    %define SYS_CLOSE 3
    %define SYS_LSEEK 8
    %define SYS_GETCPU 309
    %define SYS_PREAD64 17
    %define SYS_PWRITE64 18
    %define SYS_RT_SIGACTION 13
    %define SYS_RT_SIGRETURN 15
    %define PROT_READ       0x1
    %define PROT_WRITE      0x2
    %define PROT_EXEC       0x4
    %define CHILD_PROCESS 0

    %include "signals.inc"
    %include "common.inc"
    %include "pmc.inc"

    ; clobbers rax, rdi, rsi, rdx, r8-10
    ; params: address + length
    %macro allocate 3
        mov rax, SYS_MMAP ; mmap
        mov rdi, %1 ; address
        mov rsi, %2 ; len
        mov rdx, %3 ; prot
        mov r10, 0x22 ; flags MAP_ANONYMOUS|MAP_PRIVATE
        mov r8, -1 ; fd
        mov r9, 0 ; offset
        syscall
        cmp rax, -1
        je perf_test_entry.exit
    %endmacro

    %macro mprot 3
        mov rax, SYS_MPROT
        mov rdi, %1
        mov rsi, %2
        mov rdx, %3
        syscall
        cmp rax, -1
        je perf_test_entry.exit
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


    section .data
    warmup_cnt: dq 1
    fill1: times 62 db 0
    array: times 64 db 0
    dev_file: db '/dev/cpu/',VICTIM_PROCESS_STR,'/msr',0
    trap_msg: db "trap", 0xA, 0
    fd: dq 0
    val: dq 0
    len: equ $-val
    target: dq 0
    ALIGN 64
    xstate: times 0x1000 db 0
    SIGACTION sigaction
    ;##### DATA STARTS HERE ########

    ;##### DATA ENDS HERE ########

    section .bss

    section .note.GNU-stack noalloc noexec nowrite progbits

    section .text
    global perf_test_entry:function
    global snippet:function
    global handler:function
    global restorer:function

perf_test_entry:
    push rbp
    mov rbp, rsp
    sub rsp, len

    check_pinning VICTIM_PROCESS

    msr_open
    msr_seek

    allocate 0x0, 0x1000, PROT_READ | PROT_WRITE | PROT_EXEC
    ; save the target
    mov [target], rax

    copy rax, snippet, snippet.end-snippet

    ; get data into cache
    mov rax, [target+0x8]
    ; execute once
    call [target]

    ; remove exec + write permissions
    mprot [target], 0x1000, PROT_READ

    setup_signal_handler

.data:
    clflush [warmup_cnt]
    lfence
    reset_counter
    start_counter
    mov ebx, DWORD[warmup_cnt]
    cmp ebx, 12
    je .else
    call [target]

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
    mov r10,[rdx+UCONTEXT_STRUC.uc_mcontext+SIGCONTEXT_STRUC.trapno]
    cmp r10, 14
    jne .exit

    ; set RIP to continue after the fault
    print trap_msg, 5
    mov r10, QWORD(perf_test_entry.else)
    mov [rdx+UCONTEXT_STRUC.uc_mcontext+SIGCONTEXT_STRUC.rip], r10
    .exit:
    ret

restorer:
    mov     rax, SYS_RT_SIGRETURN 
    syscall

snippet:
    mulps xmm2, xmm1; marker instruction
    lea r8, [rel trap_msg] ; marker instruction
    ret
    .end:
    nop
    ;##### SNIPPET STARTS HERE ######

    ;##### SNIPPET ENDS HERE ######
