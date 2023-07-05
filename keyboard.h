
#ifndef KEYBOARD_H
#define KEYBOARD_H

#include "type.h"

void KeyboardModInit();
void PutScanCode(byte sc);
uint FetchKeyCode();

#endif
