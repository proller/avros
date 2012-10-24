#
# before use: install arduino-mk package
#

#freebsd example:
ARDUINO_DIR   = /usr/local/arduino
ARDMK_DIR     = /usr/local/arduino-mk
ARDUINO_PORT = /dev/cuaU0

BOARD_TAG    = atmega168

MONITOR_BAUDRATE = 115200
ARDUINO_LIBS = EEPROM Servo

include /usr/share/arduino/Arduino.mk


tidy:
	astyle -A3 -p --indent-switches --indent-preprocessor --lineend=linux --delete-empty-lines *.ino *.h
	perltidy -b  -i=2 -ce -l=128 -nbbc -sob -otr -sot *.pl *.pm *.PL examples/*.pl
