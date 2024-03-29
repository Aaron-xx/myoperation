#include "task.h"
#include "interrupt.h"
#include "screen.h"
#include "global.h"
#include "memory.h"
#include "mutex.h"
#include "keyboard.h"
#include "hdraw.h"
#include "fs.h"

void KMain()
{
    void (*AppModInit)() = (void *)BaseOfApp;
    byte* pn = (byte*)0x475;

    PrintString("Aaron.OS\n");

    PrintString("GDT Entry: ");
    PrintIntHex((uint)gGdtInfo.entry);
    PrintChar('\n');

    PrintString("GDT Size: ");
    PrintIntDec((uint)gGdtInfo.size);
    PrintChar('\n');

    PrintString("IDT Entry: ");
    PrintIntHex((uint)gIdtInfo.entry);
    PrintChar('\n');

    PrintString("IDT Size: ");
    PrintIntDec((uint)gIdtInfo.size);
    PrintChar('\n');

    PrintString("Number of Hard Disk: ");
    PrintIntDec(*pn);
    PrintChar('\n');

    MemModInit((byte*)KernelHeapBase, HeapSize);

    KeyboardModInit();

    MutexModInit();

    FSModInit();

    AppModInit();

    TaskModInit();

    IntModInit();

    ConfigPageTable();

    LaunchTask();
}