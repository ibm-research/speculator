[BITS 64]
    %include "common.inc"
    %include "pmc.inc"

    %define SYS_GETPPID 110
    %define SYS_GETPID 39

    section .data

    dev_file: db '/dev/cpu/',VICTIM_PROCESS_STR,'/msr',0
    fd: dq 0
    warmup_cnt_fake: dd 1
    offset: dq 0
    val: dq 0
    len: equ $-val
    array: times 128 db 0
    warmup_cnt: dd 1
    ;##### DATA STARTS HERE ########

    ;##### DATA ENDS HERE ########

    section .text
    global perf_test_entry:function
    global snippet:function

perf_test_entry:
    push rbp
    mov rbp, rsp
    sub rsp, len

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
    mov eax, SYS_GETPPID
    ;syscall
    ;##### SNIPPET STARTS HERE ######

    ;##### SNIPPET ENDS HERE ######
    lfence
.else:
    lfence
    stop_counter

    inc DWORD[warmup_cnt]
    cmp DWORD[warmup_cnt], 13
    jl .data

    msr_close
    exit 0
