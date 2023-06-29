#include "task.h"
#include "interrupt.h"
#include "screen.h"
#include "global.h"
#include "memory.h"

void KMain()
{
    void (*AppModInit)() = (void *)BaseOfApp;

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

    MemModInit((byte*)KernelHeapBase, HeapSize);

    AppModInit();

    TaskModInit();

    IntModInit();

    ConfigPageTable();

    LaunchTask();
}