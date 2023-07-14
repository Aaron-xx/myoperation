#ifndef INTERRUPT_H
#define INTERRUPT_H

#include "kernel.h"


void IntModInit();
int SetIntHandler(Gate* pGate, uint ifunc);
int GetIntHandler(Gate* pGate, uint* pIFunc);

#endif