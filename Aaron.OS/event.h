#ifndef EVENT_H
#define EVENT_H

#include "type.h"

enum
{
    NoneEvent,
    MutexEvent,
    KeyEvent,
    TaskEvent
};

typedef struct
{
    uint type;
    uint id;
    uint param1;
    uint param2;
} Event;

Event* CreateEvent(uint type, uint id, uint param1, uint param2);
void DestroyEvent(Event* event);


#endif
