[BITS 64]
    %include "common.inc"
    %include "intel.inc"

    section .data
    warmup_cnt: db 1
    fill: times 63 db 0

    warmup_cnt_fake: dw 2
    fill2: times 62 db 0
    address: dq 0
    address2: dq 0
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
    global func:function
    global func2:function
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
    cpuid
    lfence
    mov QWORD[address], func
    cmp DWORD[warmup_cnt], 12
    je .start
    mov QWORD[address], func2
.start:
    lfence
    reset_counter
    start_counter
    call [address]
    stop_counter

    inc DWORD[warmup_cnt]
    cmp DWORD[warmup_cnt], 13
    jl .data

    msr_close
    exit 0

func:
    xor eax, eax
    ret

func2:
    mov eax, 0
    ret
