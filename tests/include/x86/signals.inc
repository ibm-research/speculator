; Copyright 2019 IBM Corporation
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

%ifndef _ASM_SIGNALS_INC_
%define _ASM_SIGNALS_INC_     1

;Sigset constants

%define NSIG            64
%define NSIG_BPW        8
%define NSIG_WORDS      NSIG / NSIG_BPW

; Linux x86_64 signals

%define SIGHUP       1        ; Hangup
%define SIGINT       2        ; User interrupt requested from terminal, e.g. when Ctrl-C is pressed
%define SIGQUIT      3        ; Quit, e.g. when Ctrl-\ is pressed
%define SIGILL       4        ; Illegal instruction
%define SIGTRAP      5        ; Trace trap (used by debugger)
%define SIGABRT      6        ; abort
%define SIGBUS       7        ; Bus error
%define SIGFPE       8        ; Floating-point arithmetic exception
%define SIGKILL      9        ; Kill (Cannot be caught or ignored)
%define SIGUSR1      10       ; User-defined signal 1
%define SIGSEGV      11       ; Segmentation violation
%define SIGUSR2      12       ; User-defined signal 2
%define SIGPIPE      13       ; Broken pipe (attempt to write to a pipe without a process connected to the other end)
%define SIGALRM      14       ; Timer set by alarm or setitimer function expired
%define SIGTERM      15       ; Software termination signal from kill
%define SIGSTKFLT    16       ; x86 FPU stack fault
%define SIGCHLD      17       ; Child process status has changed
%define SIGCONT      18       ; The stopped process is continued
%define SIGSTOP      19       ; Stop (Cannot be caught or ignored)
%define SIGTSTP      20       ; User stop requested from terminal, e.g. when Ctrl-Z is pressed
%define SIGTTIN      21       ; Terminal read attempted when the process is in the background
%define SIGTTOU      22       ; Terminal write attempted when the process is in the background
%define SIGURG       23       ; Urgent condition on socket, e.g. out-of-band data is received on a network connection
%define SIGXCPU      24       ; CPU limit exceeded
%define SIGXFSZ      25       ; File size limit exceeded
%define SIGVTALRM    26       ; Virtual interval timer set by the setitimer function expired
%define SIGPROF      27       ; Profiling interval timer set by the setitimer function expired
%define SIGWINCH     28       ; Terminal window size change
%define SIGIO        29       ; Pollable or async I/O event occurred
%define SIGPWR       30       ; Power failure restart
%define SIGSYS       31       ; Illegal system call
%define SIGRTMIN     32
%define SIGRTMAX     64

%define SIGIOT       SIGABRT
%define SIGPOLL      SIGIO
%define SIGLOST      SIGIO
%define SIGIO        SIGPOLL
%define SIGINFO      SIGPWR
%define SIGUNUSED    SIGSYS
%define SIGCLD       SIGCHLD

; SA_FLAGS values:
;
; SA_ONSTACK indicates that a registered stack_t will be used.
; SA_RESTART flag to get restarting signals (which were the default long ago)
; SA_NOCLDSTOP flag to turn off SIGCHLD when children stop.
; SA_RESETHAND clears the handler when the signal is delivered.
; SA_NOCLDWAIT flag on SIGCHLD to inhibit zombies.
; SA_NODEFER prevents the current signal from being masked in the handler.
;
; SA_ONESHOT and SA_NOMASK are the historical Linux names for the Single
; Unix names RESETHAND and NODEFER respectively.

%define SA_NOCLDSTOP  0x00000001
%define SA_NOCLDWAIT  0x00000002
%define SA_SIGINFO    0x00000004
%define SA_ONSTACK    0x08000000
%define SA_RESTART    0x10000000
%define SA_NODEFER    0x40000000
%define SA_RESETHAND  0x80000000
%define SA_NOMASK     SA_NODEFER
%define SA_ONESHOT    SA_RESETHAND
%define SA_RESTORER   0x04000000

; sigaltstack controls

%define SS_ONSTACK   1
%define SS_DISABLE   2
%define MINSIGSTKSZ  2048
%define SIGSTKSZ     8192

; macros

STRUC SIGACTION_STRUC
    .sa_handler:      resq      1
    .sa_flags:        resq      1
    .sa_restorer:     resq      1
    .sa_mask:         resb      128
ENDSTRUC

%macro SIGACTION 1
    %1: ISTRUC SIGACTION_STRUC
        at  SIGACTION_STRUC.sa_handler,      dq 0
        at  SIGACTION_STRUC.sa_flags,        dq 0
        at  SIGACTION_STRUC.sa_restorer,     dq 0
        at  SIGACTION_STRUC.sa_mask,         times 128 db 0
    IEND
    %define %1.sa_handler     %1+SIGACTION_STRUC.sa_handler
    %define %1.sa_flags       %1+SIGACTION_STRUC.sa_flags
    %define %1.sa_restorer    %1+SIGACTION_STRUC.sa_restorer
    %define %1.sa_mask        %1+SIGACTION_STRUC.sa_mask
%endmacro

STRUC SIGINFO_T_STRUC
    .si_signo:         resd 1   ; Signal number */int
    .si_errno:         resd 1   ; An errno value */int
    .si_code:          resd 1   ; Signal code */int
    .si_trapno:        resd 1   ; Trap number that caused hardware-generated signal (unused on most architectures) */ int
    .si_pid:           resq 1   ; Sending process ID */pid_t
    .si_uid:           resd 1   ; Real user ID of sending process */uid_t
    .si_status:        resq 1   ; Exit value or signal */int
    .si_utime:         resq 1   ; User time consumed */ clock_t
    .si_stime:         resq 1   ; System time consumed */clock_t
    .si_value:         resq 1   ; Signal value */sigval_t
    .si_int:           resq 1   ; POSIX.1b signal */int
    .si_ptr:           resq 1   ; POSIX.1b signal */void
    .si_overrun:       resq 1   ; Timer overrun count; POSIX.1b timers */int
    .si_timerid:       resq 1   ; Timer ID; POSIX.1b timers */int
    .si_addr:          resq 1   ; Memory location which caused fault */void
    .si_band:          resq 1   ; Band event (was int in glibc 2.3.2 and earlier) */long     
    .si_fd:            resq 1   ; File descriptor */ int
    .si_addr_lsb:      resd 1   ; Least significant bit of address (since kernel 2.6.32) */ short
ENDSTRUC

%macro SIGINFO_T 1
    %1: ISTRUC SIGINFO_T_STRUC
        at SIGINFO_T_STRUC.si_signo,         dd 0   ; Signal number */int
        at SIGINFO_T_STRUC.si_errno,         dd 0   ; An errno value */int
        at SIGINFO_T_STRUC.si_code,          dd 0   ; Signal code */int
        at SIGINFO_T_STRUC.si_trapno,        dd 0   ; Trap number that caused hardware-generated signal (unused on most architectures) */ int
        at SIGINFO_T_STRUC.si_pid,           dq 0   ; Sending process ID */pid_t
        at SIGINFO_T_STRUC.si_uid,           dd 0   ; Real user ID of sending process */uid_t
        at SIGINFO_T_STRUC.si_status,        dq 0   ; Exit value or signal */int
        at SIGINFO_T_STRUC.si_utime,         dq 0   ; User time consumed */ clock_t
        at SIGINFO_T_STRUC.si_stime,         dq 0   ; System time consumed */clock_t
        at SIGINFO_T_STRUC.si_value,         dq 0   ; Signal value */sigval_t
        at SIGINFO_T_STRUC.si_int,           dq 0   ; POSIX.1b signal */int
        at SIGINFO_T_STRUC.si_ptr,           dq 0   ; POSIX.1b signal */void
        at SIGINFO_T_STRUC.si_overrun,       dq 0   ; Timer overrun count; POSIX.1b timers */int
        at SIGINFO_T_STRUC.si_timerid,       dq 0   ; Timer ID; POSIX.1b timers */int
        at SIGINFO_T_STRUC.si_addr,          dq 0   ; Memory location which caused fault */void
        at SIGINFO_T_STRUC.si_band,          dq 0   ; Band event (was int in glibc 2.3.2 and earlier) */long     
        at SIGINFO_T_STRUC.si_fd,            dq 0   ; File descriptor */ int
        at SIGINFO_T_STRUC.si_addr_lsb,      dd 0   ; Least significant bit of address (since kernel 2.6.32) */ short
    IEND
  
    %define %1.si_signo:         %1+SIGINFO_T_STRUC.si_signo            ; Signal number */int
    %define %1.si_errno:         %1+SIGINFO_T_STRUC.si_errno            ; An errno value */int
    %define %1.si_code:          %1+SIGINFO_T_STRUC.si_code             ; Signal code */int
    %define %1.si_trapno:        %1+SIGINFO_T_STRUC.si_trapno           ; Trap number that caused hardware-generated signal (unused on most architectures) */ int
    %define %1.si_pid:           %1+SIGINFO_T_STRUC.si_pid              ; Sending process ID */pid_t
    %define %1.si_uid:           %1+SIGINFO_T_STRUC.si_uid              ; Real user ID of sending process */uid_t
    %define %1.si_status:        %1+SIGINFO_T_STRUC.si_status           ; Exit value or signal */int
    %define %1.si_utime:         %1+SIGINFO_T_STRUC.si_utime            ; User time consumed */ clock_t
    %define %1.si_stime:         %1+SIGINFO_T_STRUC.si_stime            ; System time consumed */clock_t
    %define %1.si_value:         %1+SIGINFO_T_STRUC.si_value            ; Signal value */sigval_t
    %define %1.si_int:           %1+SIGINFO_T_STRUC.si_int              ; POSIX.1b signal */int
    %define %1.si_ptr:           %1+SIGINFO_T_STRUC.si_ptr              ; POSIX.1b signal */void
    %define %1.si_overrun:       %1+SIGINFO_T_STRUC.si_overrun          ; Timer overrun count; POSIX.1b timers */int
    %define %1.si_timerid:       %1+SIGINFO_T_STRUC.si_timerid          ; Timer ID; POSIX.1b timers */int
    %define %1.si_addr:          %1+SIGINFO_T_STRUC.si_addr             ; Memory location which caused fault */void
    %define %1.si_band:          %1+SIGINFO_T_STRUC.si_band             ; Band event (was int in glibc 2.3.2 and earlier) */long     
    %define %1.si_fd:            %1+SIGINFO_T_STRUC.si_fd               ; File descriptor */ int
    %define %1.si_addr_lsb:      %1+SIGINFO_T_STRUC.si_addr_lsb         ; Least significant bit of address (since kernel 2.6.32) */ short
%endmacro

STRUC SIGCONTEXT_STRUC
    .r8:         resq 1
    .r9:         resq 1
    .r10:        resq 1
    .r11:        resq 1
    .r12:        resq 1
    .r13:        resq 1
    .r14:        resq 1
    .r15:        resq 1
    .rdi:        resq 1
    .rsi:        resq 1
    .rbp:        resq 1
    .rbx:        resq 1
    .rdx:        resq 1
    .rax:        resq 1
    .rcx:        resq 1
    .rsp:        resq 1
    .rip:        resq 1
    .rflags:     resq 1
    .cs:         resw 1
    .gs:         resw 1
    .fs:         resw 1
    .__pad0:     resw 1
    .err:        resq 1
    .trapno:     resq 1
    .oldmask:    resq 1
    .cr2:        resq 1
    .fpstate:    resq 1
    .reserved:   resq 8
    .size:       equ    $-.r8
ENDSTRUC

%macro SIGCONTEXT 1
    %1: ISTRUC SIGCONTEXT_STRUC
        at SIGCONTEXT_STRUC.r8,       dq 0
        at SIGCONTEXT_STRUC.r9,       dq 0
        at SIGCONTEXT_STRUC.r10,      dq 0
        at SIGCONTEXT_STRUC.r11,      dq 0
        at SIGCONTEXT_STRUC.r12,      dq 0
        at SIGCONTEXT_STRUC.r13,      dq 0
        at SIGCONTEXT_STRUC.r14,      dq 0
        at SIGCONTEXT_STRUC.r15,      dq 0
        at SIGCONTEXT_STRUC.rdi,      dq 0
        at SIGCONTEXT_STRUC.rsi,      dq 0
        at SIGCONTEXT_STRUC.rbp,      dq 0
        at SIGCONTEXT_STRUC.rbx,      dq 0
        at SIGCONTEXT_STRUC.rdx,      dq 0
        at SIGCONTEXT_STRUC.rax,      dq 0
        at SIGCONTEXT_STRUC.rcx,      dq 0
        at SIGCONTEXT_STRUC.rsp,      dq 0
        at SIGCONTEXT_STRUC.rip,      dq 0
        at SIGCONTEXT_STRUC.rflags,   dq 0
        at SIGCONTEXT_STRUC.cs,       dw 0
        at SIGCONTEXT_STRUC.gs,       dw 0
        at SIGCONTEXT_STRUC.fs,       dw 0
        at SIGCONTEXT_STRUC.__pad0,   dw 0
        at SIGCONTEXT_STRUC.err,      dq 0
        at SIGCONTEXT_STRUC.trapno,   dq 0
        at SIGCONTEXT_STRUC.oldmask,  dq 0
        at SIGCONTEXT_STRUC.cr2,      dq 0
        at SIGCONTEXT_STRUC.fpstate,  dq 0
        at SIGCONTEXT_STRUC.reserved, times 8 dq 0 
    IEND
  
    %define %1.r8:         %1+SIGINFO_T_STRUC.r8
    %define %1.r9:         %1+SIGINFO_T_STRUC.r9
    %define %1.r10:        %1+SIGINFO_T_STRUC.r10
    %define %1.r11:        %1+SIGINFO_T_STRUC.r11
    %define %1.r12:        %1+SIGINFO_T_STRUC.r12
    %define %1.r13:        %1+SIGINFO_T_STRUC.r13
    %define %1.r14:        %1+SIGINFO_T_STRUC.r14
    %define %1.r15:        %1+SIGINFO_T_STRUC.r15
    %define %1.rdi:        %1+SIGINFO_T_STRUC.rdi
    %define %1.rsi:        %1+SIGINFO_T_STRUC.rsi
    %define %1.rbp:        %1+SIGINFO_T_STRUC.rbp
    %define %1.rbx:        %1+SIGINFO_T_STRUC.rbx
    %define %1.rdx:        %1+SIGINFO_T_STRUC.rdx
    %define %1.rax:        %1+SIGINFO_T_STRUC.rax
    %define %1.rcx:        %1+SIGINFO_T_STRUC.rcx
    %define %1.rsp:        %1+SIGINFO_T_STRUC.rsp
    %define %1.rip:        %1+SIGINFO_T_STRUC.rip
    %define %1.rflags:     %1+SIGINFO_T_STRUC.rflags
    %define %1.cs:         %1+SIGINFO_T_STRUC.cs
    %define %1.gs:         %1+SIGINFO_T_STRUC.gs
    %define %1.fs:         %1+SIGINFO_T_STRUC.fs
    %define %1.err:        %1+SIGINFO_T_STRUC.err
    %define %1.trapno:     %1+SIGINFO_T_STRUC.trapno
    %define %1.oldmask:    %1+SIGINFO_T_STRUC.oldmask
    %define %1.cr2:        %1+SIGINFO_T_STRUC.cr2
    %define %1.fpstate:    %1+SIGINFO_T_STRUC.fpstate
%endmacro

STRUC SIGNALSTACK_STRUC
   .ss_sp:      resq 1
   .ss_flags:   resq 1
   .ss_size:    resq 1
   .size:       equ $-.ss_sp
ENDSTRUC

%macro SIGNALSTACK 1
    %1 ISTRUC SIGNALSTACK_STRUC
        at  .ss_sp,     dq  0
        at  .ss_flags,  dq  0
        at  .ss_size:   dq  0
    ENDSTRUC
    %define %1.ss_sp:       %1+SIGNALSTACK_STRUC.ss_sp
    %define %1.ss_flags:    %1+SIGNALSTACK_STRUC.ss_flags
    %define %1.ss_size:     %1+SIGNALSTACK_STRUC.ss_size
%endmacro

STRUC SIGSET_T_STRUC
    .sig:       resq NSIG_WORDS
    .size:      equ $-.sig
ENDSTRUC

%macro SIGSET_T 1
    %1 ISTRUC SIGSET_T_STRUC
        at  .sig,       times NSIG_WORDS dq  0
    ENDSTRUC
    %define %1.sig:         %1+SIGSET_T_STRUC.sig
%endmacro

STRUC UCONTEXT_STRUC
   .uc_flags:    resq 1
   .uc_link:     resq 1
   .uc_stack:    resb SIGNALSTACK_STRUC.size
   .uc_mcontext: resb SIGCONTEXT_STRUC.size
   .uc_sigmask:  resb SIGSET_T_STRUC.size
ENDSTRUC

%macro UCONTEXT 1
    %1 ISTRUC UCONTEXT_STRUC
        at  .uc_flags,     dq  0
        at  .uc_link,      dq  0
        at  .uc_stack,     times SIGNALSTACK_STRUC.size db 0
        at  .uc_mcontext:  times SIGCONTEXT_STRUC.size db 0
        at  .uc_sigmask:   times SIGSET_T_STRUC.size db 0
    ENDSTRUC
    %define %1.uc_flags:               %1+UCONTEXT_STRUC.uc_flags
    %define %1.uc_link:                %1+UCONTEXT_STRUC.uc_link
    %define %1.uc_stack.ss_sp:         %1+UCONTEXT_STRUC.uc_stack+SIGNALSTACK_STRUC.ss_sp
    %define %1.uc_stack.ss_flags:      %1+UCONTEXT_STRUC.uc_stack+SIGNALSTACK_STRUC.ss_flags
    %define %1.uc_stack.ss_size:       %1+UCONTEXT_STRUC.uc_stack+SIGNALSTACK_STRUC.ss_size
    %define %1.uc_mcontext.r8:         %1+UCONTEXT_STRUC.uc_mcontext+SIGCONTEXT_STRUC.r8
    %define %1.uc_mcontext.r9:         %1+UCONTEXT_STRUC.uc_mcontext+SIGCONTEXT_STRUC.r9
    %define %1.uc_mcontext.r10:        %1+UCONTEXT_STRUC.uc_mcontext+SIGCONTEXT_STRUC.r10
    %define %1.uc_mcontext.r11:        %1+UCONTEXT_STRUC.uc_mcontext+SIGCONTEXT_STRUC.r11
    %define %1.uc_mcontext.r12:        %1+UCONTEXT_STRUC.uc_mcontext+SIGCONTEXT_STRUC.r12
    %define %1.uc_mcontext.r13:        %1+UCONTEXT_STRUC.uc_mcontext+SIGCONTEXT_STRUC.r13
    %define %1.uc_mcontext.r14:        %1+UCONTEXT_STRUC.uc_mcontext+SIGCONTEXT_STRUC.r14
    %define %1.uc_mcontext.r15:        %1+UCONTEXT_STRUC.uc_mcontext+SIGCONTEXT_STRUC.r15
    %define %1.uc_mcontext.rdi:        %1+UCONTEXT_STRUC.uc_mcontext+SIGCONTEXT_STRUC.rdi
    %define %1.uc_mcontext.rsi:        %1+UCONTEXT_STRUC.uc_mcontext+SIGCONTEXT_STRUC.rsi
    %define %1.uc_mcontext.rbp:        %1+UCONTEXT_STRUC.uc_mcontext+SIGCONTEXT_STRUC.rbp
    %define %1.uc_mcontext.rbx:        %1+UCONTEXT_STRUC.uc_mcontext+SIGCONTEXT_STRUC.rbx
    %define %1.uc_mcontext.rdx:        %1+UCONTEXT_STRUC.uc_mcontext+SIGCONTEXT_STRUC.rdx
    %define %1.uc_mcontext.rax:        %1+UCONTEXT_STRUC.uc_mcontext+SIGCONTEXT_STRUC.rax
    %define %1.uc_mcontext.rcx:        %1+UCONTEXT_STRUC.uc_mcontext+SIGCONTEXT_STRUC.rcx
    %define %1.uc_mcontext.rsp:        %1+UCONTEXT_STRUC.uc_mcontext+SIGCONTEXT_STRUC.rsp
    %define %1.uc_mcontext.rip:        %1+UCONTEXT_STRUC.uc_mcontext+SIGCONTEXT_STRUC.rip
    %define %1.uc_mcontext.rflags:     %1+UCONTEXT_STRUC.uc_mcontext+SIGCONTEXT_STRUC.rflags
    %define %1.uc_mcontext.cs:         %1+UCONTEXT_STRUC.uc_mcontext+SIGCONTEXT_STRUC.cs
    %define %1.uc_mcontext.gs:         %1+UCONTEXT_STRUC.uc_mcontext+SIGCONTEXT_STRUC.gs
    %define %1.uc_mcontext.fs:         %1+UCONTEXT_STRUC.uc_mcontext+SIGCONTEXT_STRUC.fs
    %define %1.uc_mcontext.err:        %1+UCONTEXT_STRUC.uc_mcontext+SIGCONTEXT_STRUC.err
    %define %1.uc_mcontext.trapno:     %1+UCONTEXT_STRUC.uc_mcontext+SIGCONTEXT_STRUC.trapno
    %define %1.uc_mcontext.oldmask:    %1+UCONTEXT_STRUC.uc_mcontext+SIGCONTEXT_STRUC.oldmask
    %define %1.uc_mcontext.cr2:        %1+UCONTEXT_STRUC.uc_mcontext+SIGCONTEXT_STRUC.cr2
    %define %1.uc_mcontext.fpstate:    %1+UCONTEXT_STRUC.uc_mcontext+SIGCONTEXT_STRUC.fpstate
    %define %1.uc_sigmask.sig:         %1++UCONTEXT_STRUC.uc_sigmask+SIGSET_T_STRUC.sig
%endmacro

%endif
