%include "common.asm"

global _start
global AppModInit

extern AppMain
extern GetAppToRun
extern GetAppNum

[section .text]
[bits 32]
_start:
AppModInit:
    push ebp
    mov ebp, esp
    
    mov dword [GetAppToRunEntry], GetAppToRun
    mov dword [GetAppNumEntry], GetAppNum

    call AppMain
    
    leave
    
    ret
    
