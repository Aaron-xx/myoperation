#include "global.h"
#include "type.h"

Task* gCTaskAddr = NULL;
uint gMemSize = 0;

void (* const InitInterrupt)() = NULL;
void (* const SendEOI)(uint port) = NULL;

void (* const RunTask)(volatile Task* pt) = NULL;
void (* const LoadTask)(volatile Task* pt) = NULL;
