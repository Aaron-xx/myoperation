#ifndef FS_H
#define FS_H

#include "type.h"

enum
{
    FS_FAILED,
    FS_SUCCEED,
    FS_EXISTED,
    FS_NONEXISTED
};

uint FSFormat();
uint FSIsFormatted();

uint FCreate(const char* fn);
uint FExisted(const char* fn);
uint FDelete(const char* fn);
uint FRename(const char* ofn, const char* nfn);

#endif
