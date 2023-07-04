#include "mutex.h"
#include "memory.h"
#include "screen.h"
#include "task.h"
#include "global.h"

enum
{
    Normal,
    Strict
};

typedef struct 
{
    ListNode head;
    uint type;
    uint lock;
} Mutex;

static List gMList = {0};

static Mutex* SysCreateMutex(uint type)
{
    Mutex* ret = Malloc(sizeof(Mutex));
    
    if(ret)
    {
        ret->lock = 0;
        ret->type = type;
        List_Add(&gMList, (ListNode*)ret);
    }

    return ret;
}

static uint IsMutexValid(Mutex* mutex)
{
    uint ret = 0;
    ListNode* pos = NULL;
    
    List_ForEach(&gMList, pos)
    {
        if( IsEqual(pos, mutex) )
        {
            ret = 1;
            break;
        }
    }

    return ret;
}

static void SysDestroyMutex(Mutex* mutex, uint* result)
{
    if(mutex)
    {
        ListNode* pos = NULL;

        *result = 0;

        List_ForEach(&gMList, pos)
        {
            if(IsEqual(pos, mutex))
            {
                if(IsEqual(mutex->lock, 0))
                {
                    List_DelNode(pos);
                    Free(pos);

                    *result = 1;
                }

                break;
            }
        }
    }
}

static void SysNormalEnter(Mutex* mutex, uint* wait)
{
    if(mutex->lock)
    {
        *wait = 1;
        MtxSchedule(WAIT);
    }
    else
    {
        mutex->lock = 1;
        *wait = 0;
    }
}

static void SysStrictEnter(Mutex* mutex, uint* wait)
{
    if(mutex->lock)
    {
        if( IsEqual(mutex->lock, gCTaskAddr) )
        {
            *wait = 0;
        }
        else
        {
            *wait = 1;
            MtxSchedule(WAIT);
        }
    }
    else
    {
        mutex->lock = (uint)gCTaskAddr;
        *wait = 0;
    }
}

static void SysEnterCritical(Mutex* mutex, uint* wait)
{
    if(mutex && IsMutexValid(mutex))
    {
        switch(mutex->type)
        {
            case Normal:
                SysNormalEnter(mutex, wait);
                break;
            case Strict:
                SysStrictEnter(mutex, wait);
                break;
            default:
                break;
        }
    }
}

static void SysNormalExit(Mutex* mutex)
{
    mutex->lock = 0;
    MtxSchedule(NOTIFY);
}

static void SysStrictExit(Mutex* mutex)
{
    if(IsEqual(mutex->lock, gCTaskAddr))
    {
        mutex->lock = 0;  
        MtxSchedule(NOTIFY);
    }
    else
    {   
        KillTask();
    }
}

void SysExitCritical(Mutex* mutex)
{
    if(mutex && IsMutexValid(mutex))
    {
        switch(mutex->type)
        {
            case Normal:
                SysNormalExit(mutex);
                break;
            case Strict:
                SysStrictExit(mutex);
                break;
            default:
                break;
        }
    }
}

void MutexModInit()
{
    List_Init(&gMList);
}

void MutexCallHandler(uint cmd, uint param1, uint param2)
{
    if( cmd == 0 )
    {
        uint* pRet = (uint*)param1;

        *pRet = (uint)SysCreateMutex(param2);
    }
    else if( cmd == 1 )
    {
        SysEnterCritical((Mutex*)param1, (uint*)param2);
    }
    else if( cmd == 2 )
    {
        SysExitCritical((Mutex*)param1);
    }
    else 
    {
        SysDestroyMutex((Mutex*)param1, (uint*)param2);
    }
}
