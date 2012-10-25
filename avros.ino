// $Id$

//for more detailed description read avros.h

//includes for your bunny processing - must include files here, not in .h
//if you use Makefile - you can delete #include's from here
//#include "WProgram.h" //before arduino 1.0
#include "Arduino.h" // auto by makefile?
//#define EPROM 0 // disable
//#define EPROM 128 // allow to use only first 128 bytes, default 512
#if EPROM || !defined(EPROM)
#include "EEPROM.h"
#endif

#define SERVO 4 // enable servo lib, allocate 4 servos
#if SERVO
#include "Servo.h"
#endif

//#define SPEED 9600 // serial speed, default 115200


//#define DEBUG 1

/* // disable functions to reduce binary size
#define EPROM 0         // e, E
#define MONITOR 0	// M
#define TONE 0          // t, T
#define PULSE 0		// p, P
#define REPORT 0	// silent mode
#define TEST 0		// l, L
*/

//#define PIN_ANALOG_FROM 14  // A0 error: for old version of arduino lib (0018)
//#define PIN_LAST 21  // A7, A14 error

//#define MONITOR_FIRST 10 //smaller and faster monitor check loop, only for 5 pin
//#define MONITOR_LAST 14

#include "avros.h"

void setup()
{
    sp_setup();
// my init
}

int blink = 0;
int bdelay = 100;

void loop_my()
{
// my loop
    pinMode(13, OUTPUT);
    digitalWrite(13, blink = !blink ? HIGH : LOW);
    delay(bdelay);
}

int stop = 0;

void loop()
{
    if (!stop) loop_my();
    // variant 1: with lib first parse:
    int cmd = sp_loop();
    // your comands handler
    switch (cmd) {
        case 0 :
            break;
        case '.': // press . to start-stop your program
            stop = !stop;
            break;
        case '+': // press + to increase delay
            bdelay *= 2;
            break;
        case '-': // press - to decrease delay
            bdelay /= 2;
            break;
        case '=': // press =123 to set delay
            bdelay = read_num(4);
            break;
    }
    /* //variant2 with your parser first
    int cmd = read_chr(READ_TIMEOUT_FIRST);
    switch (cmd) {
        case 'c'
            // your command code
            break;
        default:
    	    cmd_parse(cmd);
            break;
    }
    */
    /* //variant3 with command prefix $
    int cmd = read_chr(READ_TIMEOUT_FIRST);
    switch (cmd) {
        //case 'x': // your commands
        //    break;
        case '$': // lib commands starting from $: example:  $w13,1
        cmd_parse( read_chr() );
            break;
    }
    */
}
