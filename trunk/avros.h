/* $Id$
 Arduino serial protocol v0.1
 <Oleg Alexeenkov> proler@gmail.com http://pro.setun.net

 -
 - Human/script readable-writeable (via terminal like putty (char-by-char input) or.. os command line)
 - Serial or eprom command source (upload simple program via terminal/script)
 - enable by pin automatc execution from eprom
 -


 Serial protocol description:

 values:
 P - coded pin [0-9A-L] or [a-z]
 B - binary 0 or 1 or '0' or '1'
 V - numeric value { or binary for '0'-'9' started from \x00 }-todo

 commands: [command byte][pin byte][value?]
 mPB	pinMode(pin, mode) mode: either INPUT=0 or OUTPUT=1.

 rP	int digitalRead(pin) Returns Either HIGH=1 or LOW=0
 answer: rPB

 wPB	digitalWrite(pin, value) value: HIGH=1 or LOW=0

 RP	int analogRead(pin) values go from 0 to 1023
 answer: RPV

 WPV	analogWrite(pin, value) - PWM  values from 0 to 255

 pP	pulseIn(pin, HIGH);

 PPv	pulseOut - dirty emulation


 dV	delay(ms)

 DV	delayMicroseconds(us)

 MPV	monitor  changes [with min step] V=0 - off bin V=1 - on analog: V=1-1024
 answer: rPB
 answer: RPV

 e	print eprom (512 bytes)
 answer: e<DATA>E

 E<DATA>E	write data while !=E or 512 bytes E<DATA512bytes>

 s	set cmd src to eprom

 S	set cmd src to serial

 o	ignore src pin

 O	unignore src pin


 examples:
 send:	m31w31RE
 recv:	Ro100

 send:
 mn1wn1	- led on  13 pin = n
 mD1wD1	- led on  13 pin = D  pin   numbering variant2

 mo0Mo10	-monitor analog0 step 10 (pin 14 = o = E)


 test eprom src - on wait off pin 13 (led)
 E o mn1 wn1 d1000 wn0 d1000 O S E s
 \--prog-----------------------+-/ |
 .                             |    \run
 .                              \only once, remove to blink forever

 Arduino Duemilanove pins numbering:
 n	v1	v2	Duemilanove	 Mega
 0	0	a	RX               RX
 1	1	b	TX               TX
 2 	2	c		int      PWM
 3	3	d	PWM	int      -/-
 4	4	e
 5	5	f	PWM
 6	6	g	PWM
 7	7       h
 8	8       i
 9	9	j	PWM
 10	A	k	PWM
 11	B	l	PWM
 12	C       m                        -/-
 13	D	n	led              PWM
 14	E	o	a0	analogs  COM
 15	F	p	a1               -/-
 16	G	q	a2
 17	H	r	a3
 18	I	s	a4
 19	J	t	a5
 20	K	u	a6               -/-
 21	L	v	a7               COM
 Mega:
 22	M	w                        DGT
 23	N       x                        -/-
 24	O       y
 25	P       z
 26	Q
 27 	R
 28	S
 29	T
 30	U
 31	V
 32	W
 33	X
 34	Y
 35	Z
 36
 37
 38
 39
 40
 41
 42
 43
 44
 45
 46
 47
 48
 49
 50
 51
 52                                      -/-
 53                                      DGT
 54                                      ANL
 55                                      -/-
 56
 57
 58
 59
 60
 61
 62
 63
 64
 65
 66
 67
 68
 69                                       -/-
 60                                       ANL


 variant3 : binary byte // not tested

 all functions always return variant2 a-v
 // todo binary return or variant1

 a
 b
 c
 d delay
 e eprom
 f
 g
 h
 i
 j
 k
 l // test lamp example
 m mode
 M monitor
 n
 o ignore src pin
 p pulse read
 q
 r digital read
 R analog read
 s cmd src
 t
 u
 v
 w write
 x
 y servo attach
 z servo read
 Z servo write






 todo:
 interrupts() noInterrupts()
 finish binary values


 test winxp cmdline: mode com1: baud=9600 data=8 stop=1 parity=n

 */
#if !defined(avros_h)
#define avros_h


//extern "C" void __cxa_pure_virtual() {}



#if !defined(SPEED)
#define SPEED 9600
//#define SPEED 115200 // 300, 1200, 2400, 4800, 9600, 14400, 19200, 28800, 38400, 57600, 115200,
#endif

#if !defined(EPROM_SIZE)
#define EPROM_SIZE 512
#endif

#if !defined(PIN_LAST)
//#define PIN_LAST 21 // 0-21
#if defined(__AVR_ATmega1280__) || defined(__AVR_ATmega2560__)
#define PIN_LAST A15
#else
#define PIN_LAST A7
#endif
#endif

#if !defined(PIN_ANALOG_FROM)
//#define PIN_ANALOG_FROM 14 //due
//#define PIN_ANALOG_FROM 54 //mega
#define PIN_ANALOG_FROM A0 //auto from WProgram.h

#endif
//#define PIN_SRC 2  //execute from eprom if pin HIGH=1 // pin MUST be connected to gnd(0) or +(1)
#if !defined(REPORT)
#define REPORT 1 //print to serial about command executions
#endif
//#define DEBUG
//#define DELAY 100

#if !defined(READ_TIMEOUT)
#define READ_TIMEOUT 100 //for typing from console set to 500-1000, for scripts - 1-50
#endif

#if !defined(READ_TIMEOUT_FIRST)
#define READ_TIMEOUT_FIRST 0
#endif

//#define BINARY // TODO NOT FINISHED
#if !defined(AUTO_MONITOR)
#define AUTO_MONITOR 1
#endif


#include "WProgram.h"
#include "EEPROM.h"

#if defined(SERVO)
#include "Servo.h"
//Servo  servo2, servo1;
Servo servo[SERVO]/*, servo1*/;
char servon[PIN_LAST];
char servolast = 0;
//Servo *  servos[PIN_LAST] = {};
#endif

//typedef uint8_t byte;

byte read_src = 0;
byte read_src_want = 0; // set to 1 for automatic execution from eprom

#if defined(PIN_SRC)
byte read_src_pin = 1;
#endif


int  monitor_pin[PIN_LAST] = {
};
int  monitor_last[PIN_LAST] = {
};


int  read_eprom = 0;
int  serial_buf = -1;


void sp_setup()
{
    //  Serial.begin(9600);
    Serial.begin(SPEED);

#if defined(PIN_SRC)
    monitor_pin[PIN_SRC] = 1;
#endif
#if defined(REPORT)
    Serial.println("I");
#endif
}



void monitor()
{
    for (byte i = 0; i <= PIN_LAST; ++i)
        if (monitor_pin[i]) {
            int    now;
            if (i < PIN_ANALOG_FROM)  now = digitalRead(i);
            else  now = analogRead(i - PIN_ANALOG_FROM);
            if (monitor_last[i] >=    now + monitor_pin[i] or monitor_last[i] <= now - monitor_pin[i]) {
                monitor_last[i]               = now;
                Serial.print(i < PIN_ANALOG_FROM ? "r" : "R");
                Serial.print('a' + i, BYTE);
                Serial.println(now, DEC);
#if defined(PIN_SRC)
                if (read_src_pin and i            == PIN_SRC) {
#if defined(REPORT)
                    Serial.print("$");
                    Serial.print('0' + read_src, BYTE);
                    Serial.println('0' + now  , BYTE);
#endif
                    read_src_want              =    now;
                }
#endif

                /* // write yours handlers for pin=i changes here
                 switch (i) { case 0: break; case 1: break; case 2: break; default: 0; }
                 */
            }
        }
}


int read_chr(int timeout = READ_TIMEOUT)//wait one second max
{
    if (serial_buf >= 0) {
        int    r = serial_buf;
        serial_buf = -1;
        return r;
    }
    unsigned long  runtime = millis();
    if (read_src == 0) {
        while (!Serial.available() and millis() - timeout < runtime) {
#if defined(DELAY)
            delay(DELAY);
#endif
            monitor();
        }
        if (Serial.available()) {
            return Serial.read();
        }
    } else {
        if (read_eprom > EPROM_SIZE    )  read_eprom = 0;
        byte   r = EEPROM.read(read_eprom++);
        if (r == 'E') {
            read_eprom = 0;
            return 0;
        }
        return r;
    }
    return -1;
}
byte char2pin(byte pin)
{
    if (pin >= 'a') pin -= 'a';
    if (pin >= 'A') pin -= 'A', pin += 10;
    if (pin >= '0') pin -= '0';
    return pin;
}
boolean char2bin(byte value)
{
    if (value >= '0') value -= '0';
    return value;
}
int char2int(byte value, int saved = 0)
{
    if (value < '0' or value > '9') saved += value;
    else saved *= 10, saved += value - '0';
    return saved;
}
int read_num(byte maxchars = 5)
{
    unsigned int  value = 0;
    do {
        int    chr = read_chr();
        if (chr >= 0) {
            if (chr < '0' or chr > '9') {
                serial_buf = chr;
                return value;
            }
            value = char2int(chr, value);
        } else  break;
    } while (value >= 0 and-- maxchars > 0);
    return value;
}

void pulseOut(int pin, int us)
{
    digitalWrite(pin, HIGH);
    us = max(us - 20, 1);
    delayMicroseconds(us);
    digitalWrite(pin, LOW);
}

byte servo_attach(byte pin)
{

    pinMode(pin, OUTPUT);
    servon[pin] = servolast++;
    if(servo[servon[pin]].attached()) {
        servo[servon[pin]].detach();
    }

    servo[servon[pin]].attach(pin);
    return servon[pin];
}

int cmd_parse(int cmd)
{
    byte   pin = 0;
    int   value = 0;
    unsigned long value_ul = 0;
    switch (cmd) {
    case -1:
#if defined(DELAY)
        delay(DELAY);
#endif
        break;
    case 'w':
        pin = char2pin(read_chr());
        value = char2bin(read_chr());
#if defined(AUTO_MONITOR)
        pinMode(pin, OUTPUT);
#endif
        digitalWrite(pin, value);
#if defined(REPORT)
        Serial.print("w");
        Serial.print('a' + pin, BYTE);
        Serial.println(value);
#endif
        break;
    case 'W':
        pin = char2pin(read_chr());
        value = read_num(3);
        //pinMode(pin, OUTPUT);
        analogWrite(pin, value);
#if defined(REPORT)
        Serial.print("W");
        Serial.print('a' + pin, BYTE);
        Serial.println(value);
#endif
    case 'r':
        pin = char2pin(read_chr());
        //pinMode(pin, INPUT);
#if defined(AUTO_MONITOR)
        pinMode(pin, INPUT);
#endif
        Serial.print("r");
        Serial.print('a' + pin, BYTE);
        Serial.println(digitalRead(pin), DEC);
        break;
    case 'R':
        pin = char2pin(read_chr());
        if (pin >= PIN_ANALOG_FROM) pin -= PIN_ANALOG_FROM;
        //if (pin > 8)   break
        //pinMode(pin, INPUT);
        Serial.print("R");
        Serial.print('a' + PIN_ANALOG_FROM + pin, BYTE);
        Serial.println(analogRead(pin), DEC);
        break;
    case 'm':
        pin = char2pin(read_chr());
        value = char2bin(read_chr());
        pinMode(pin, value);
#if defined(REPORT)
        Serial.print("m");
        Serial.print('a' + pin, BYTE);
        Serial.println(value);
#endif
        break;
    case 'd':
        value = read_num();
        delay(value);
#if defined(REPORT)
        Serial.println("d");
#endif
        break;
    case 'D':
        value = read_num();
        delayMicroseconds(value);
#if defined(REPORT)
        Serial.println("D");
#endif
        break;
    case 'M':
        pin = char2pin(read_chr());
        value = read_num(4);
        monitor_pin[pin] = value;
#if defined(REPORT)
        Serial.print("M");
        Serial.print('a' + pin, BYTE);
        Serial.println(value, DEC);
#endif
        break;
    case  'e':
        Serial.println("e");
        for (int address = 0; address < EPROM_SIZE; ++address) {
#if defined(BINARY)
            Serial.print(EEPROM.read(address));
#else
            byte    v = EEPROM.read(address);
            //remove !v for binary
            if (     !v or      v == 'E'     )   break;
            Serial.print(v);
#endif
        }
        Serial.println("E");
        break;
    case 'E':
        for (int address = 0; address < EPROM_SIZE; ++address) {
            int    r = read_chr();
            //!!!remove 0 for binarydata
            if (r <= 0 )
                break;
            EEPROM.write(address, r);
            if (r == 'E') {
                break;
            }
        }
#if defined(REPORT)
        Serial.println("E");
#endif
        read_eprom = 0;
        break;
    case 's':
        read_src = read_src_want = 1;
        //read_eprom = 0;
#if defined(REPORT)
        Serial.println("s");
#endif
        break;
    case 'S':
        read_src =   read_src_want = 0;
#if defined(REPORT)
        Serial.println("S");
#endif
        break;
#if defined(PIN_SRC)
    case 'o':
        read_src_pin = 0;
#if defined(REPORT)
        Serial.println("o");
#endif
        break;
    case 'O':
        read_src_pin = 1;
#if defined(REPORT)
        Serial.println("O");
#endif
        break;
#endif

        //write your commands here
        // Example:
        // l 	= led on
        // L	= led off

    case 'l':
        pinMode(13, OUTPUT);
        digitalWrite(13, HIGH);
#if defined(REPORT)
        Serial.println("l");
#endif
        break;
    case 'L':
        pinMode(13, OUTPUT);
        digitalWrite(13, LOW);
#if defined(REPORT)
        Serial.println("L");
#endif
        break;


    case 'p':
        pin = char2pin(read_chr());
        //pinMode(pin, INPUT);
#if defined(AUTO_MONITOR)
        pinMode(pin, INPUT);
#endif
        Serial.print("p");
        Serial.print('a' + pin, BYTE);
        value_ul = pulseIn(pin, HIGH);
        //Serial.println( pulseIn(pin, HIGH), DEC);
        Serial.println( value_ul, DEC);
        //        Serial.println( (value_ul/(147*2.54))*10, DEC);



        break;
    case 'P':
        pin = char2pin(read_chr());
        value = read_num(4);
        //pinMode(pin, INPUT);
#if defined(AUTO_MONITOR)
        pinMode(pin, OUTPUT);
#endif
        pulseOut(pin, value);
#if defined(REPORT)
        Serial.print("P");
        Serial.print('a' + pin, BYTE);
        Serial.println(value);
#endif



        break;






#if defined(SERVO)
    case 'Z':
        pin = char2pin(read_chr());
        servo_attach(pin);
        /*	if (!servos[pin]) {
         Servo servo;
         		servos[pin] = &servo;
         		servos[pin]->attach(pin);
         	}*/
#if defined(REPORT)
        Serial.print("Z");

        Serial.print('a' + pin, BYTE);
        Serial.print(servo[servon[pin]].attached(), DEC);
        Serial.println(servon[pin], DEC);
        //    Serial.println(servos[pin]->attached(), DEC);
#endif
        break;
        /*
         case 'z':
         pin = char2pin(read_chr());
         #if defined(REPORT)
         Serial.print("z");
         Serial.print('a' + pin, BYTE);
         Serial.println(servo[servon[pin]].read(), DEC);
         //    Serial.println(servos[pin]->read(), DEC);
         #endif
         break;
         */

    case 'z':
        pin = char2pin(read_chr());
        value = read_num(3);
        //    value = char2bin(read_chr());
        servo[servon[pin]].write(value);
        //    servos[pin]->write(value);
#if defined(REPORT)
        Serial.print("z");
        //    Serial.print(servon[pin], DEC);
        Serial.print('a' + pin, BYTE);
        Serial.print(servon[pin], DEC);
        Serial.println(servo[servon[pin]].read(), DEC);
        //    Serial.println(servos[pin]->read(), DEC);
#endif
        break;
        /*

          case 'X':

            pin = char2pin(read_chr());
            pinMode(pin, OUTPUT);
            if(servo1.attached()) {
              servo1.detach();
            }
            servo1.attach(pin);
        #if defined(REPORT)
            Serial.print("X");
            Serial.print('a' + pin, BYTE);
            Serial.println(servo1.attached(), DEC);
            //    Serial.println(servos[pin]->attached(), DEC);
        #endif
            break;
          case 'x':
            pin = char2pin(read_chr());
            value = read_num(3);
            //    value = char2bin(read_chr());
            servo1.write(value);
            //    servos[pin]->write(value);
        #if defined(REPORT)
            Serial.print("x");
            Serial.print('a' + pin, BYTE);
            Serial.println(servo1.read(), DEC);
            //    Serial.println(servos[pin]->read(), DEC);
        #endif
            break;
        */

#endif


    default:
        return cmd;


    }
    return 0;
}


int sp_loop()
{
    monitor();
    if (!Serial.available()) {
        read_src = read_src_want;
    } else if (read_src != 0) {
        read_src_want = read_src;
        read_src = 0;
    }
    return cmd_parse( read_chr(READ_TIMEOUT_FIRST));
}



/*

 mn1 wn1 d1000 wn0 d1000 wn1

 */

#endif


