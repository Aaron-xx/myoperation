#ifndef HDRAW_H
#define HDRAW_H

#include "type.h"

#define SECT_SIZE    512

void HDRawSetName(const char* name);
void HDRawModInit();
uint HDRawSectors();
uint HDRawWrite(uint si, byte* buf);
uint HDRawRead(uint si, byte* buf);
void HDRawFlush();

#endif
