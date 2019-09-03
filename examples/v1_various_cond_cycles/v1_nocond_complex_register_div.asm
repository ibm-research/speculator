[BITS 64]
    %include "common.inc"
    %include "intel.inc"

    section .data
    warmup_cnt: db 1
    fill: times 63 db 0

    warmup_cnt_fake: dq 2
    fill2: times 60 db 0

    dev_file: db '/dev/cpu/',VICTIM_PROCESS_STR,'/msr',0
    fd: dq 0
    val: dq 0
    len: equ $-val
    lea_array: times 40 db 0
    junk: db 1
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
    mov eax, 0
    mov r15d, DWORD[warmup_cnt_fake]
    mov r14d, 4096
    cpuid
    lfence
    reset_counter
    start_counter
    xor edx, edx
    mov eax, r15d

    ;##### SNIPPET STARTS HERE ######

    ;##### SNIPPET ENDS HERE ######
    ;lea rax, [lea_array+rax*2]

.else:
    lfence
    stop_counter
    mov ax, 2
    mul DWORD[warmup_cnt_fake]
    mov DWORD[warmup_cnt_fake], eax

    inc DWORD[warmup_cnt]
    cmp DWORD[warmup_cnt], 13
    jl .data

    msr_close
    exit 0
