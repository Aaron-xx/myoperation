#include "utility.h"
#include "task.h"
#include "screen.h"
#include "global.h"
#include "app.h"

#define MAX_TASK_NUM        4
#define MAX_RUNNING_TASK    2
#define MAX_READY_TASK      (MAX_TASK_NUM - MAX_RUNNING_TASK)
#define PID_BASE            0x10

static AppInfo* (*GetAppToRun)(uint index) = NULL;
static uint (*GetAppNum)() = NULL;

static TaskNode gTaskBuff[MAX_TASK_NUM] = {0};

static Queue gFreeTaskNode = {0};
static Queue gReadyTask = {0};
static Queue gRunningTask = {0};
static Queue gWaittingTask = {0};

static TSS gTSS = {0};
static TaskNode gIdleTask = {0};
static uint gAppToRunIndex = 0;
static uint gPid = PID_BASE;

static void TaskEntry()
{
    if(gCTaskAddr)
    {
        gCTaskAddr->tmain();
    }
    // to destory current task here
    asm volatile(
        "movw  $0,  %ax \n"
        "int   $0x80    \n"
    );
    
    while(1);  // TODO: schedule next task to run
}

static void IdleTask()
{
    int i = 0;
    
    SetPrintPos(0, 10);
    
    PrintString(__FUNCTION__);
    
    while( 1 )
    {
        SetPrintPos(10, 10);
        PrintChar('A' + i);
        i = (i + 1) % 26;
        Delay(1);
    }
}

void InitTask(Task* pt, uint id,const char* name, void(*entry)(), ushort pri)
{
    pt->rv.cs = LDT_CODE32_SELECTOR;
    pt->rv.gs = LDT_VIDEO_SELECTOR;
    pt->rv.ds = LDT_DATA32_SELECTOR;
    pt->rv.es = LDT_DATA32_SELECTOR;
    pt->rv.fs = LDT_DATA32_SELECTOR;
    pt->rv.ss = LDT_DATA32_SELECTOR;
    
    pt->rv.esp = (uint)pt->stack + sizeof(pt->stack);
    pt->rv.eip = (uint)TaskEntry;
    pt->rv.eflags = 0x3202;

    pt->tmain = entry;
    pt->id = id;
    pt->current = 0;
    pt->total = 256 - pri;

    StrCpy(pt->name, name, sizeof(pt->name) - 1);

    SetDescValue(pt->ldt + LDT_VIDEO_INDEX,  0xB8000, 0x07FFF, DA_DRWA + DA_32 + DA_DPL3);
    SetDescValue(pt->ldt + LDT_CODE32_INDEX, 0x00,    0xFFFFF, DA_C + DA_32 + DA_DPL3);
    SetDescValue(pt->ldt + LDT_DATA32_INDEX, 0x00,    0xFFFFF, DA_DRW + DA_32 + DA_DPL3);
    
    pt->ldtSelector = GDT_TASK_LDT_SELECTOR;
    pt->tssSelector = GDT_TASK_TSS_SELECTOR;

}

static void PrepareForRun(volatile Task* pt)
{
    pt->current++;

    gTSS.ss0 = GDT_DATA32_FLAT_SELECTOR;
    gTSS.esp0 = (uint)&pt->rv + sizeof(pt->rv);
    gTSS.iomb = sizeof(TSS);
    
    SetDescValue(AddrOff(gGdtInfo.entry, GDT_TASK_LDT_INDEX), (uint)&pt->ldt, sizeof(pt->ldt)-1, DA_LDT + DA_DPL0);
}

static void CreateTask()
{
    uint num = GetAppNum();
    
    while((gAppToRunIndex < num) && (Queue_Length(&gReadyTask) < MAX_READY_TASK))
    {
        TaskNode* tn = (TaskNode*)Queue_Remove(&gFreeTaskNode);
        
        if(tn)
        {
            AppInfo* app = GetAppToRun(gAppToRunIndex);
            InitTask(&tn->task, gPid++, app->name, app->tmain, app->priority);

            
            Queue_Add(&gReadyTask, (QueueNode*)tn);
        }
        else
        {
            break;
        }
        
        gAppToRunIndex++;
    }
}

static void CheckRunningTask()
{
    if(Queue_Length(&gRunningTask) == 0)
    {
        Queue_Add(&gRunningTask, (QueueNode*)&gIdleTask);
    }
    else if(Queue_Length(&gRunningTask) > 1)
    {
        if(IsEqual(Queue_Front(&gRunningTask), (QueueNode*)&gIdleTask))
        {
            Queue_Remove(&gRunningTask);
        }
    }
}

static void ReadyToRunning()
{
    QueueNode* node = NULL;
    
    if(Queue_Length(&gReadyTask) < MAX_READY_TASK)
    {
        CreateTask();
    }
    
    while((Queue_Length(&gReadyTask) > 0) && (Queue_Length(&gRunningTask) < MAX_RUNNING_TASK))
    {
        node = Queue_Remove(&gReadyTask);

        ((TaskNode*)node)->task.current = 0;
        
        Queue_Add(&gRunningTask, node);
    }
}

static void RunningToReady()
{
    TaskNode* tn = (TaskNode*)Queue_Front(&gRunningTask);
    
    if( !IsEqual(tn, (QueueNode*)&gIdleTask) )
    {
        if( tn->task.current == tn->task.total )
        {
            Queue_Remove(&gRunningTask);
            Queue_Add(&gReadyTask, (QueueNode*)tn);
        }
    }
}

void TaskModInit()
{
    int i = 0;

    GetAppToRun = (void*)(*((uint*)GetAppToRunEntry) + BaseOfApp);
    GetAppNum = (void*)(*((uint*)GetAppNumEntry) + BaseOfApp);

    Queue_Init(&gFreeTaskNode);
    Queue_Init(&gRunningTask);
    Queue_Init(&gReadyTask);
    Queue_Init(&gWaittingTask);

    for(i=0; i<MAX_TASK_NUM; i++)
    {
        Queue_Add(&gFreeTaskNode, (QueueNode*)AddrOff(gTaskBuff, i));
    }

    SetDescValue(AddrOff(gGdtInfo.entry, GDT_TASK_TSS_INDEX), (uint)&gTSS, sizeof(gTSS)-1, DA_386TSS + DA_DPL0);

    InitTask(&gIdleTask.task,0 ,"IdleTask", IdleTask, 255);
    
    ReadyToRunning();
    
    CheckRunningTask();
}

void LaunchTask()
{
    gCTaskAddr = &((TaskNode*)Queue_Front(&gRunningTask))->task;
    
    PrepareForRun(gCTaskAddr);
    
    RunTask(gCTaskAddr);
}

void Schedule()
{
    RunningToReady();
    
    ReadyToRunning();

    CheckRunningTask();

    Queue_Rotate(&gRunningTask);

    gCTaskAddr = &((TaskNode*)Queue_Front(&gRunningTask))->task;

    PrepareForRun(gCTaskAddr);
    
    LoadTask(gCTaskAddr);
}

void KillTask()
{
    QueueNode* node = Queue_Remove(&gRunningTask);
    
    Queue_Add(&gFreeTaskNode, node);
    
    Schedule();
}
