#include "sysinfo.h"
#include "screen.h"
#include "fs.h"
#include "global.h"

void SysInfoCallHandler(uint cmd, uint param1, uint param2)
{
    if(cmd == 0)
    {
        uint* pRet = (uint*)param1;
        *pRet = gMemSize;
    }
}

void CmdCallHandler(uint cmd, uint param1, uint param2)
{
    if(cmd == 0)
    {
        uint* pRet = (uint*)param1;
        *pRet = FileInDir(param2);
    }
}
