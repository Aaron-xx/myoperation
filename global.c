#include "global.h"

Task* gCTaskAddr = NULL;

GdtInfo gGdtInfo = {0};
IdtInfo gIdtInfo = {0};
void (* const RunTask)(volatile Task* pt) = NULL;
void (* const LoadTask)(volatile Task* pt) = NULL;

void (* const InitInterrupt)() = NULL;
void (* const EnableTimer)() = NULL;
void (* const SendEOI)(uint port) = NULL;