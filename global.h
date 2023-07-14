#ifndef GLOBAL_H
#define GLOBAL_H

#include "type.h"
#include "task.h"

// ========Interrupt=========
extern void (* const InitInterrupt)();
extern void (* const SendEOI)(uint port);

// ========Task=========
extern Task* gCTaskAddr;
extern uint gMemSize;

extern void (* const RunTask)(volatile Task* pt);
extern void (* const LoadTask)(volatile Task* pt);

#endif