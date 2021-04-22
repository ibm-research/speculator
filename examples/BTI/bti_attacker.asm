[BITS 64]
    %include "common.inc"
    %include "pmc.inc"

    section .data

    dev_file: db '/dev/cpu/',ATTACKER_PROCESS_STR,'/msr',0
    iteration: dq 1
    fd: dq 0
    val: dq 0
    len: equ $-val
    array: times 2048 db 0
    addr: dq 0
    align 1024
    ;##### DATA STARTS HERE ########

    ;##### DATA ENDS HERE ########

    section .text
    global perf_test_entry:function

; INDIRECT CALL TRAINED BY ATTACKER
bti_call:
    call [addr]
    ret

perf_test_entry:
    push rbp
    mov rbp, rsp
    sub rsp, 0
    check_pinning ATTACKER_PROCESS
    msr_open
    msr_seek
    mov QWORD[iteration], 1
    align 512

attacker:
    ; Train code for BTI
    .train:
        ;jmpnext256
        ;jmpnext256
        mov QWORD[addr], verify
        lfence

        reset_counter
        start_counter
        align 64
        .call:
            call bti_call
        stop_counter

        dec QWORD[iteration]
        cmp QWORD[iteration], 0
        jge .train
    .exit:
        msr_close
        exit 0

align 1024
verify:
    ret

align 1024
correct:
    ret

align 1024
verify2:
    ret

fillerteststart: resb (0x1 << 14)
align 1024
verify3:
    ret
