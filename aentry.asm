%include "common.asm"

global _start
global AppModInit

extern AppMain
extern GetAppToRun
extern GetAppNum
extern MemModInit

[section .text]
[bits 32]
_start:
AppModInit:
    push ebp
    mov ebp, esp
    
    mov dword [AppMainEntry], AppMain + BaseOfApp

    push HeapSize
    push AppHeapBase

    call MemModInit

    add esp, 8
    
    leave
    
    ret
