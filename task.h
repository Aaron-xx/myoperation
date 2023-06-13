#ifndef TASK_H
#define TASK_H

#include "kernel.h"
#include "queue.h"

typedef struct {
    uint gs;
    uint fs;
    uint es;
    uint ds;
    uint edi;
    uint esi;
    uint ebp;
    uint kesp;
    uint ebx;
    uint edx;
    uint ecx;
    uint eax;
    uint raddr;
    uint eip;
    uint cs;
    uint eflags;
    uint esp;
    uint ss;
} RegValue;

typedef struct
{
    uint   previous;
    uint   esp0;
    uint   ss0;
    uint   unused[22];
    ushort reserved;
    ushort iomb;
} TSS;

typedef struct
{
    RegValue   rv;          // 任务执行状态，即各个寄存器的值
    Descriptor ldt[3];
    TSS        tss;
    ushort     ldtSelector;
    ushort     tssSelector;
    uint       id;
    char       name[8]; 
    byte       stack[512];  // 任务执行使用的栈
} Task;

typedef struct
{
    QueueNode head;
    Task task;
} TaskNode;

void TaskModInit();
void LaunchTask();
void Schedule();

#endif
