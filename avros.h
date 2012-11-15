/* $Id$
 Arduino serial protocol v0.1 http://code.google.com/p/avros/
 <Oleg Alexeenkov> proler@gmail.com http://pro.setun.net

 -
 - Human/script readable-writeable (via terminal like putty (char-by-char input) or.. os command line)
 - Serial or eprom command source (upload simple program via terminal/script)
 - enable by pin automatc execution from eprom
 -

 examples:

 simple led on: 13 pin
 send: w13,1

 pin can be maximum 2 chars, we can write without separator:
 w131
 but for pins 0-9 only:
 w021
 w2,1


        on led, wait, off led, wait, on led:
                1 sec
 send:  w13,1   d1000 w13,0    d1000 w13,1

 by default reads and writes sets pinMode auromaticaly, but you can:
   mode read, monitor analog0 step 10
 send: m14,0 M14,10

 test monitor: 1hz tone to pin, add monitor them:
 send: t2,1 M2,1

 test eprom src - on wait off pin 13 (led) send:
 send: E o w13,1 d1000 w13,0 d1000 O S E e s
 .     \--prog-----------------------+-/   |
 .                                   |     \run
 .                                   \only once, remove to blink forever



 Serial protocol description:

 values:
 P - pin (2 digits or one with separator) 1, 12, 12 01
 B - binary 0 or 1 or '0' or '1'
 V - numeric value { or binary for '0'-'9' started from \x00 }-todo

 commands: [command byte][pin[,]][value?]
 all functions always return pins in variant2 [a-vw-z]

 a         // some letters empty, you can write yours handlers
 b
 c
 dV	delay(ms)
 DV	delayMicroseconds(us)
 e	eprom print
 E<DATA>E	write data to eprom while !=E or 512 bytes E<DATA512bytes>
 	answer: e<DATA>E
 f
 g
 h
 i
 j
 k
 l	// test lamp example
 mP,B	pinMode(pin, mode) mode: either INPUT=0 or OUTPUT=1.
 MP,V	monitor  changes [with min step] V=0 - off bin V=1 - on analog: V=1-1024
 	answer: rPB
 	answer: RPV
 n
 o	ignore src pin
 O	unignore src pin
 pP	pulseIn(pin, HIGH);
 PP,V	pulseOut - dirty emulation
 q
 rP	int digitalRead(pin) Returns Either HIGH=1 or LOW=0
 	answer: rPB
 RP	int analogRead(pin) values go from 0 to 1023
  	answer: RPV
 s	set cmd src to eprom
 S	set cmd src to serial
 tP,V	tone(pin, frequency)
 tP,0	noTone(pin)
 TP,V,V tone(pin, frequency, duration)
 TP,0	noTone(pin)
 u
 v
 wP,B	digitalWrite(pin, value) value: HIGH=1 or LOW=0
 WP,V	analogWrite(pin, value) - PWM  values from 0 to 255
 x      modules mode
 xs     servo module
 xsaP	servo attach    to use #define SERVO 1
 xsdP	servo detach
 xsrP	servo read
 xswP,V	servo write
 xswP,V	servo writeMicroseconds
 y
 z


 you can split multiplie commands by space, \n or tab, or input without spaces


 Arduino pins numbering:
 n	Duemilanove,Nano Mega
 0	RX               RX
 1	TX               TX
 2 		int      PWM
 3	PWM	int      -/-
 4
 5	PWM
 6	PWM
 7
 8
 9	PWM
 10	PWM
 11	PWM
 12	                 -/-
 13	led              PWM
 14	a0	analogs  COM
 15	a1               -/-
 16	a2
 17	a3
 18	a4
 19	a5
 20	a6               -/-
 21	a7               COM
 Mega:
 22	                 DGT
 23	                 -/-
 24
 25
 26
 27
 28
 29
 30
 31
 32
 33
 34
 35
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
 52                      -/-
 53                      DGT
 54                      a0 analogs
 55                      a1
 56                      a2
 57                      a3
 58                      a4
 59                      a5
 60                      a6
 61                      a7
 62                      a8
 63                      a9
 64                      a10
 65                      a11
 66                      a12
 67                      a13
 68                      a14
 69                      a15

 todo:
 interrupts() noInterrupts()
 finish binary values/pins
 execute commands from string
 module eprom - e=>xer, E=>xew
 */
#if !defined(avros_h)
#define avros_h


//extern "C" void __cxa_pure_virtual() {}



#if !defined(SPEED)
//#define SPEED 9600
#define SPEED 115200 // 300, 1200, 2400, 4800, 9600, 14400, 19200, 28800, 38400, 57600, 115200,
#endif

#if !defined(PIN_LAST)
//#define PIN_LAST 21 // 0..21 0..69
#if defined(__AVR_ATmega1280__) || defined(__AVR_ATmega2560__)
#define PIN_LAST A15 // 69
#else
#define PIN_LAST A7  // 21
#endif
#endif

#if !defined(PIN_ANALOG_FROM)
#if defined(__AVR_ATmega1280__) || defined(__AVR_ATmega2560__)
//#define PIN_ANALOG_FROM 54 //mega
#else
//#define PIN_ANALOG_FROM 14 //due
#endif
#define PIN_ANALOG_FROM A0 //auto from WProgram.h
#endif

//#define PIN_SRC 2  //execute from eprom if pin HIGH=1 // pin MUST be connected to gnd(0) or +(1)

#if !defined(REPORT)
#define REPORT 1 //print to serial about command executions
#endif

//#define DEBUG
//#define DELAY 100 // auto delay if nothing to do

#if !defined(READ_TIMEOUT)
#define READ_TIMEOUT 100 //for typing from console set to 500-1000, for scripts - 1-50
#endif

#if !defined(READ_TIMEOUT_FIRST)
#define READ_TIMEOUT_FIRST 0
#endif

// w1,1 w011 w131 w13,1
#if !defined(READ_SEPARATOR)
#define READ_SEPARATOR ','
#endif

#if !defined(MONITOR)
#define MONITOR 1
#endif

#if !defined(AUTO_MODE)
#define AUTO_MODE 1
#endif

#if !defined(TONE)
#define TONE 1
#endif

#if !defined(PULSE)
#define PULSE 1
#endif

#if !defined(TEST)
#define TEST 1
#endif


//#define BINARY // TODO NOT FINISHED


//#include "WProgram.h" //before arduino 1.0
#include "Arduino.h"

#if (defined(EEPROM_h) and !defined(EPROM)) or !defined(EPROM)  //already included, using
#define EPROM 512
#endif

#if EPROM
#include "EEPROM.h"
#endif

#if defined(Servo_h) and !defined(SERVO) //already included, using
#define SERVO 1
#endif

#if SERVO
#include "Servo.h"
Servo servo[SERVO];
char servon[PIN_LAST + 1] = {};
char servolast = 0;
//Servo *  servos[PIN_LAST] = {};
#endif

//typedef uint8_t byte;

byte read_src = 0;
byte read_src_want = 0; // set to 1 for automatic execution from eprom

#if defined(PIN_SRC)
byte read_src_pin = 1;
#endif

int  read_eprom = 0;
int  serial_buf = -1;

#if MONITOR
#if !defined(MONITOR_FIRST)
#define MONITOR_FIRST 0
#endif
#if !defined(MONITOR_LAST)
#define MONITOR_LAST PIN_LAST
#endif
#if !defined(MONITOR_PULSE)
#define MONITOR_PULSE HIGH
#endif

int  monitor_pin[MONITOR_LAST + 1] = { // using arduino 0018 or earlier  possible error, to fix: #define PIN_LAST 21
};
int  monitor_last[MONITOR_LAST + 1] = {
};
#endif

void sp_setup()
{
    //  Serial.begin(9600);
    Serial.begin(SPEED);
#if MONITOR
#if defined(PIN_SRC)
    monitor_pin[PIN_SRC] = 1;
#endif
#endif
#if REPORT
#if defined(DEVICEID)
    Serial.print("I");
    Serial.println(DEVICEID, DEC);
#else
    Serial.println("I");
#endif
#endif
}

void print_pin_sep(byte pin)
{
#if REPORT
    Serial.print(pin, DEC);
    Serial.print(READ_SEPARATOR);
#endif
}

#if MONITOR
void monitor()
{
    for (byte i = MONITOR_FIRST; i <= MONITOR_LAST; ++i) {
        //#if DEBUG
        //Serial.print("MT:");
        //print_pin_sep(i);
        //#endif
        if (monitor_pin[i]) {
            int    now;
            if (i < PIN_ANALOG_FROM and monitor_pin[i] > 1)  now = pulseIn(i, MONITOR_PULSE);
            else if (i < PIN_ANALOG_FROM)  now = digitalRead(i);
            else  now = analogRead(i - PIN_ANALOG_FROM);
            if (monitor_last[i] >=    now + monitor_pin[i] or monitor_last[i] <= now - monitor_pin[i]) {
                monitor_last[i]               = now;
                Serial.print(i < PIN_ANALOG_FROM ? "r" : "R");
                //Serial.print('a' + i, BYTE);
                print_pin_sep(i);
                Serial.println(now, DEC);
#if defined(PIN_SRC)
                if (read_src_pin and i            == PIN_SRC) {
#if REPORT
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
}
#endif


int read_chr(unsigned int timeout = READ_TIMEOUT)//wait one second max
{
    if (serial_buf >= 0) {
        int    r = serial_buf;
        serial_buf = -1;
        return r;
    }
    unsigned long  runtime = millis();
    if (read_src == 0) {
        while (!Serial.available() and millis() - timeout < runtime) {
#if DELAY
            delay(DELAY);
#endif
#if MONITOR
            monitor();
#endif
        }
        if (Serial.available()) {
            return Serial.read();
        }
#if EPROM
    } else if(read_src == 1) {
        if (read_eprom > EPROM    )  read_eprom = 0;
        byte   r = EEPROM.read(read_eprom++);
        if (r == 'E') {
            read_eprom = 0;
            return 0;
        }
        return r;
#endif
#if SRC_STRING
    } else if(read_src == 2) {
#endif
    }
    return -1;
}
#if READ_PIN_ONE_BYTE
byte char2pin(byte pin)
{
    if (pin >= 'a') pin -= 'a';
    if (pin >= 'A') pin -= 'A', pin += 10;
    if (pin >= '0') pin -= '0';
    return pin;
}
#endif

boolean char2bin(byte value)
{
    if (value >= '0') value -= '0';
    return value;
}
unsigned int char2int(byte value, unsigned int saved = 0)
{
    if (value < '0' or value > '9') saved += value;
    else saved *= 10, saved += value - '0';
    return saved;
}
unsigned int read_num(byte maxchars = 5, boolean flush = 0)
{
    unsigned int  value = 0;
    do {
        int    chr = read_chr();
        if (chr >= 0) {
            if (chr < '0' or chr > '9') {
                if (!flush) serial_buf = chr;
                return value;
            }
            value = char2int(chr, value);
        } else  break;
    } while (value >= 0 and-- maxchars > 0);
    return value;
}

byte read_pin(bool flush =
#if READ_SEPARATOR
                  1
#else
                  0
#endif

             )
{
#if READ_PIN_ONE_BYTE
    return char2pin(read_chr());
#endif
    byte pin = read_num(2);
    if (flush) {
        if (pin >= 10) {
            serial_buf = read_chr();
        }
        if ( (serial_buf < '0' or serial_buf > '9')) {
            serial_buf = -1;
        }
    }
    return pin;
}

#if PULSE
void pulseOut(byte pin, unsigned int us)
{
    digitalWrite(pin, HIGH);
    us = max(us - 20, 1);
    delayMicroseconds(us);
    digitalWrite(pin, LOW);
}
#endif

#if SERVO
byte servo_attach(byte pin)
{
    pinMode(pin, OUTPUT);
    if (!servon[pin]) servon[pin] = servolast++;
    if (servolast >= SERVO) servolast = 0;
    if(servo[servon[pin]].attached()) {
        servo[servon[pin]].detach();
    }
    servo[servon[pin]].attach(pin);
    return servon[pin];
}
#endif

int cmd_parse(int cmd)
{
    byte   	  pin = 0;
    unsigned int  value = 0;
    unsigned long value_ul = 0;
    switch (cmd) {
        case -1:
#if DELAY
            delay(DELAY);
#endif
            break;
        case 'w':
            pin = read_pin();
            value = char2bin(read_chr());
#if AUTO_MODE
            pinMode(pin, OUTPUT);
#endif
            digitalWrite(pin, value);
#if REPORT
            Serial.print("w");
            print_pin_sep(pin);
            Serial.println(value);
#endif
            break;
        case 'W':
            pin = read_pin();
            value = read_num(3);
            //pinMode(pin, OUTPUT);
            analogWrite(pin, value);
#if REPORT
            Serial.print("W");
            print_pin_sep(pin);
            Serial.println(value);
#endif
        case 'r':
            pin = read_pin();
            //pinMode(pin, INPUT);
#if AUTO_MODE
            pinMode(pin, INPUT);
#endif
            Serial.print("r");
            print_pin_sep(pin);
            Serial.println(digitalRead(pin), DEC);
            break;
        case 'R':
            pin = read_pin();
            if (pin >= PIN_ANALOG_FROM) pin -= PIN_ANALOG_FROM;
            //if (pin > 8)   break
            //pinMode(pin, INPUT);
            Serial.print("R");
            print_pin_sep(PIN_ANALOG_FROM + pin);
            //Serial.print('a' + PIN_ANALOG_FROM + pin, BYTE);
            Serial.println(analogRead(pin), DEC);
            break;
        case 'm':
            pin = read_pin();
            value = char2bin(read_chr());
            pinMode(pin, value);
#if REPORT
            Serial.print("m");
            print_pin_sep(pin);
            Serial.println(value);
#endif
            break;
        case 'd':
            value = read_num();
            delay(value);
#if REPORT
            Serial.println("d");
            Serial.println(value);
#endif
            break;
        case 'D':
            value = read_num();
            delayMicroseconds(value);
#if REPORT
            Serial.println("D");
            Serial.println(value);
#endif
            break;
#if MONITOR
        case 'M':
            pin = read_pin();
            value = read_num(4);
            if(pin >= MONITOR_FIRST and pin <= MONITOR_LAST) monitor_pin[pin] = value;
#if REPORT
            Serial.print("M");
            print_pin_sep(pin);
            Serial.println(value, DEC);
#endif
            break;
#endif
#if EPROM
        case  'e':
            Serial.println("e");
            for (int address = 0; address < EPROM; ++address) {
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
            for (int address = 0; address < EPROM; ++address) {
                int    r = read_chr();
                //!!!remove 0 for binarydata
                if (r <= 0 )
                    break;
                EEPROM.write(address, r);
                if (r == 'E') {
                    break;
                }
            }
#if REPORT
            Serial.println("E");
#endif
            read_eprom = 0;
            break;
#endif
        case 's':
            read_src = read_src_want = 1;
            //read_eprom = 0;
#if REPORT
            Serial.println("s");
#endif
            break;
        case 'S':
            read_src = read_src_want = 0;
#if REPORT
            Serial.println("S");
#endif
            break;
#if TONE
        case 't':
            pin = read_pin();
            value = read_num(5);
            if (!value) {
                noTone(pin);
            } else {
                tone(pin, value);
            }
#if REPORT
            Serial.print("t");
            print_pin_sep(pin);
            Serial.println(value);
#endif
            break;
        case 'T':
            pin = read_pin();
            value = read_num(5, 1);
            value_ul = read_num(5);
            if (!value) {
                noTone(pin);
            } else {
                tone(pin, value, value_ul);
            }
#if REPORT
            Serial.print("T");
            print_pin_sep(pin);
            Serial.print(value);
            Serial.print(READ_SEPARATOR);
            Serial.println(value_ul);
#endif
#endif
            break;
            /* bad idea    case 'T':
                    pin = read_pin();
                    noTone(pin);
            #if REPORT
                    Serial.print("T");
                    print_pin_sep(pin);
                    Serial.println(0);
            #endif
                    break;
            */
#if defined(PIN_SRC)
        case 'o':
            read_src_pin = 0;
#if REPORT
            Serial.println("o");
#endif
            break;
        case 'O':
            read_src_pin = 1;
#if REPORT
            Serial.println("O");
#endif
            break;
#endif
            //write your commands here
            // Example:
#if TEST
            // l 	= led on
            // L	= led off
        case 'l':
            pinMode(13, OUTPUT);
            digitalWrite(13, HIGH);
#if REPORT
            Serial.println("l");
#endif
            break;
        case 'L':
            pinMode(13, OUTPUT);
            digitalWrite(13, LOW);
#if REPORT
            Serial.println("L");
#endif
            break;
#endif
#if PULSE
        case 'p':
            pin = read_pin();
            //pinMode(pin, INPUT);
#if AUTO_MODE
            pinMode(pin, INPUT);
#endif
            Serial.print("p");
            print_pin_sep(pin);
            value_ul = pulseIn(pin, HIGH);
            //Serial.println( pulseIn(pin, HIGH), DEC);
            Serial.println( value_ul, DEC);
            //        Serial.println( (value_ul/(147*2.54))*10, DEC);
            break;
        case 'P':
            pin = read_pin();
            value = read_num(4);
            //pinMode(pin, INPUT);
#if AUTO_MODE
            pinMode(pin, OUTPUT);
#endif
            pulseOut(pin, value);
#if REPORT
            Serial.print("P");
            print_pin_sep(pin);
            Serial.println(value);
#endif
            break;
#endif

        case 'x': //modules
            cmd = read_chr();
            switch (cmd) {
#if SERVO
        case 's': //servo
            cmd = read_chr();
            switch (cmd) {

        case 'a':
            pin = read_pin();
            servo_attach(pin);
#if REPORT
            Serial.print("xsa");
            print_pin_sep(pin);
            Serial.print(servo[servon[pin]].attached(), DEC);
            Serial.println(servon[pin], DEC);
            //    Serial.println(servos[pin]->attached(), DEC);
#endif
            break;
        case 'd':
            pin = read_pin();
            if (servo[servon[pin]].attached()) servo[servon[pin]].detach();
#if REPORT
            Serial.print("xsd");
            print_pin_sep(pin);
            Serial.println(servo[servon[pin]].attached(), DEC);
            //Serial.println(servon[pin], DEC);
            //    Serial.println(servos[pin]->attached(), DEC);
#endif
            break;
        case 'w':
            pin = read_pin();
            value = read_num(3);
            servo[servon[pin]].write(value);
#if REPORT
            Serial.print("xsw");
            print_pin_sep(pin);
            Serial.println(value, DEC);
            //Serial.println(servon[pin], DEC);
#endif
            break;
        case 'W':
            pin = read_pin();
            value = read_num(3);
            servo[servon[pin]].writeMicroseconds(value);
#if REPORT
            Serial.print("xsW");
            print_pin_sep(pin);
            Serial.println(value, DEC);
            //Serial.println(servon[pin], DEC);
#endif
            break;

        case 'r':
            pin = read_pin();
            value = servo[servon[pin]].read();
#if REPORT
            Serial.print("xsr");
            //    Serial.print(servon[pin], DEC);
            print_pin_sep(pin);
            Serial.print(servon[pin], DEC);
            Serial.println(servo[servon[pin]].read(), DEC);
            //    Serial.println(servos[pin]->read(), DEC);
#endif
            break;
        }
        break;
#endif //SERVO
        }
        break;

        default:
            return cmd;
    }
    return 0;
}

/// todo unfinished
#if SRC_STRING

int run_string(char * s)
{
    read_src =   read_src_want = 2;
    read_string = s;
    cmd_parse( read_chr());
}
#endif




int sp_loop()
{
#if MONITOR
    monitor();
#endif
    if (!Serial.available()) {
        read_src = read_src_want;
    } else if (read_src != 0) {
        read_src_want = read_src;
        read_src = 0;
    }
    return cmd_parse( read_chr(READ_TIMEOUT_FIRST));
}


#endif


