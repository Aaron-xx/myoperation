#include "shell.h"
#include "syscall.h"
#include "const.h"

void AppMain()
{
    RegApp("Shell", Shell + BaseOfApp, 255);
}

