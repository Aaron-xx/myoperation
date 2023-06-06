#ifndef GLOBAL_H
#define GLOBAL_H

#include "kernel.h"
#include "const.h"

extern GdtInfo gGdtInfo;
extern IdtInfo gIdtInfo;
extern void (* const RunTask)(Task* pt);

extern void (* const InitInterrupt)();
extern void (* const EnableTimer)();
extern void (* const SendEOI)(uint port);

#endif