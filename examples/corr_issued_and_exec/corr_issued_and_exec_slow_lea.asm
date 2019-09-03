[BITS 64]
    %include "common.inc"
    %include "intel.inc"

    section .data
    warmup_cnt: dd 1
    fill: times 128 db 0

    warmup_cnt_fake: dd 1
    fill2: times 128 db 0

    dev_file: db '/dev/cpu/',VICTIM_PROCESS_STR,'/msr',0
    fd: dq 0
    lea_array times 128 db 0
    offset: dq 0
    val: dq 0
    len: equ $-val
    array: times 128 db 0
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
    mov eax, 0
    cpuid
    lfence
    reset_counter
    start_counter
    cmp DWORD[warmup_cnt], 12
    je .else
    ;##### SNIPPET STARTS HERE ######

    ;##### SNIPPET ENDS HERE ######
.else:
    lfence
    stop_counter

    inc DWORD[warmup_cnt]
    cmp DWORD[warmup_cnt], 13
    jl .data

    msr_close
    exit 0
