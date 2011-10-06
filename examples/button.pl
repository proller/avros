#!/usr/bin/perl
#
# react on pressed button
#
use strict;
use Data::Dumper;
#use Time::HiRes;
use lib::abs qw(..);
use avrcmd;
my $pin  = 3;
my $port = avrcmd->new(
  #'baudrate'=>9600,
  debug => 1, waitinit => 1,
  #path=>'COM1',
  handler => {
    qr{r(?<pin>$pin),(?<state>\d+)} => sub { print "pin $pin changed", Dumper \@_ }
  }
) or die;
$port->monitor( $pin, 1 );
#warn 'read:', $port->digitalRead( $pin );
my $stop;
local $SIG{INT} = sub { ++$stop };
$port->say(0.1),
  #Time::HiRes::sleep(0.1)
  while !$stop;
