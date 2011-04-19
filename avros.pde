// $Id$

#include "WProgram.h"
#include "EEPROM.h"
#define SERVO 4
#define SPEED 115200
#if defined(SERVO)
#include "Servo.h"
#endif

#include "avros.h"


void setup()
{
    sp_setup();
// my init
}


void loop_my() {
// my loop
}

int stop = 0;

void loop()
{
    if (!stop) loop_my();

    int cmd = sp_loop();
    // your comands handler
    switch (cmd) {
    case 0 :
        break;
    case '.':
        pinMode(13, OUTPUT);
        digitalWrite(13, stop ? HIGH : LOW);
        stop = !stop;
        break;

    }
}
