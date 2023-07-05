#include "task.h"
#include "global.h"
#include "screen.h"
#include "mutex.h"
#include "keyboard.h"

extern byte ReadPort(ushort port);

void TimerHandler()
{
    static uint i = 0;

    i = (i + 1) % 5;

    if(i == 0)
    {
        Schedule();
    }

    SendEOI(MASTER_EOI_PORT);
}

void KeyboardHandler()
{
    byte sc = ReadPort(0x60);

    PutScanCode(sc);
    
    SendEOI(MASTER_EOI_PORT);
}

void SysCallHandler(uint type, uint cmd, uint param1, uint param2)
{
    switch(type)
    {
        case 0:
            TaskCallHandler(cmd, param1, param2);
            break;
        case 1:
            MutexCallHandler(cmd, param1, param2);
            break;
        default:
            break;
    }
}

void PageFaultHandler()
{
    SetPrintPos(0, 6);

    PrintString("Page Fault: kill ");
    PrintString(gCTaskAddr->name);
    
    KillTask();
}

void SegmentFaultHandler()
{
    SetPrintPos(0, 6);

    PrintString("Segment Fault: kill ");
    PrintString(gCTaskAddr->name);

    KillTask();
}
