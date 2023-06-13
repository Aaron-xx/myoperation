#include "interrupt.h"
#include "task.h"
#include "global.h"

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