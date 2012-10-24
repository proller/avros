#
# before use install arduino-mk package
#

ARDUINO_DIR  = /usr/share/arduino

#TARGET       = CLItest
ARDUINO_LIBS = EEPROM Servo

#BOARD_TAG    = uno
#ARDUINO_PORT = /dev/cu.usb*

include /usr/share/arduino/Arduino.mk


tidy:
	astyle -A3 -p --indent-switches --indent-preprocessor --lineend=linux --delete-empty-lines *.ino *.h
	perltidy -b  -i=2 -ce -l=128 -nbbc -sob -otr -sot *.pl *.pm *.PL examples/*.pl

