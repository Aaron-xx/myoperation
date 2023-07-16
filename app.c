#include "shell.h"
#include "syscall.h"
#include "const.h"
#include "screen.h"

void AppMain()
{
    RegApp("Shell", Shell + BaseOfApp, 255);
}

