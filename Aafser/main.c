#include <stdio.h>
#include "fs.h"

int main(void)
{
    HDRawSetName("hd.img");

    HDRawModInit();

    printf("format: %d\n", FSFormat());
    printf("is_formatted: %d\n", FSIsFormatted());

    HDRawFlush();

    return 0;
}

