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

    if(FSFormat() && FSIsFormatted() )
    {
        const char* fn = "test.txt";
        char str[] = "Aaron.OS";
        char buf[512] = {0};

        if( FExisted(fn) == FS_EXISTED )
        {
            FDelete(fn);
        }

        PrintString("create =  ");
        PrintIntDec(FCreate(fn));

        PrintChar('\n');

        uint fd = FOpen(fn);

        PrintString("fd = ");
        PrintIntDec(fd);
        PrintChar('\n');

        PrintString("write bytes =  ");
        PrintIntDec(FWrite(fd, str, sizeof(str)));
        PrintChar('\n');

        FClose(fd);

        fd = FOpen(fn);

        PrintString("fd =  ");
        PrintIntDec(fd);
        PrintChar('\n');

        PrintString("pos =  ");
        PrintIntDec(FTell(fd));
        PrintChar('\n');

        PrintString("seek =  ");
        PrintIntDec(FSeek(fd, 200));
        PrintChar('\n');

        PrintString("pos =  ");
        PrintIntDec(FTell(fd));
        PrintChar('\n');

        // PrintString("erase =  ");
        // PrintIntDec(FErase(fd, 400));
        // PrintChar('\n');

        // PrintString("len =  ");
        // PrintIntDec(FLength(fd));
        // PrintChar('\n');

        // PrintString("pos =  ");
        // PrintIntDec(FTell(fd));
        // PrintChar('\n');

        PrintString("seek =  ");
        PrintIntDec(FSeek(fd, 0));
        PrintChar('\n');

        PrintString("read bytes =  ");
        PrintIntDec(FRead(fd, buf, sizeof(buf)));
        PrintChar('\n');

        PrintString("content =  ");
        PrintString(buf);
        PrintChar('\n');

        FClose(fd);
    }

    // AppModInit();

    TaskModInit();

    IntModInit();

    ConfigPageTable();

    while(1);

    LaunchTask();
}