#include "shell.h"
#include "syscall.h"
#include "const.h"
#include "screen.h"
#include "demo1.h"

void AppMain()
{
    RegApp("Shell", Shell + BaseOfApp, 255);
}

