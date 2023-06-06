#include "global.h"

GdtInfo gGdtInfo = {0};
IdtInfo gIdtInfo = {0};
void (* const RunTask)(Task* pt) = NULL;

void (* const InitInterrupt)() = NULL;
void (* const EnableTimer)() = NULL;
void (* const SendEOI)(uint port) = NULL;