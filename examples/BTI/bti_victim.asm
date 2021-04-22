[BITS 64]
    %include "common.inc"
    %include "pmc.inc"

    section .data

    dev_file: db '/dev/cpu/',VICTIM_PROCESS_STR,'/msr',0
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

; HIJACKED CALLED IN THE VICTIM
bti_call:
    call [addr]
    ret

perf_test_entry:
    push rbp
    mov rbp, rsp
    sub rsp, 0
    check_pinning VICTIM_PROCESS
    msr_open
    msr_seek

    align 512

victim:
    ;jmpnext256
    ;jmpnext256
    mov QWORD[addr], correct
    clflush[addr]
    lfence

    reset_counter
    start_counter
    align 64
    .call:
        call bti_call

    stop_counter

    msr_close
    exit 0

lfence
align 1024
verify:
    ; 1 LD_BLOCK.STORE_FORWARD markers
    mov DWORD[array], eax
    mov DWORD[array+4], edx
    movq xmm0, QWORD[array]
    lfence
    ret

align 1024
correct:
    lfence
    ret

align 1024
verify2:
    ; 3 LD_BLOCK.STORE_FORWARD markers
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


fillerteststart: resb (0x1 << 14)
align 1024
verify3:
    ; 6 LD_BLOCK.STORE_FORWARD markers
    mov DWORD[array], eax
    mov DWORD[array+4], edx
    movq xmm0, QWORD[array]

    mov DWORD[array], eax
    mov DWORD[array+4], edx
    movq xmm0, QWORD[array]

    mov DWORD[array], eax
    mov DWORD[array+4], edx
    movq xmm0, QWORD[array]

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
