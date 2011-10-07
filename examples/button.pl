#!/usr/bin/perl
#
# react on pressed button[s]
#
use strict;
use Data::Dumper;
#use Time::HiRes;
use lib::abs qw(..);
use avrcmd;
#my $pin  = 3;
my @pin  = ( 3 .. 10 );
my $port = avrcmd->new(
  #'baudrate'=>9600,
  debug => 1, waitinit => 1,
  #path=>'COM1',
  handler => {
    map {
      qr{r(?<pin>$_),(?<state>\d+)} => sub { print "pin changed", Dumper( $_[1] ), "\n" }
      } @pin
  },
  init => sub {
    my $port = shift if ref $_[0];
    $port->monitor( $_, 1 ) for @pin;
    $port->say(2);    #wait for monitor answers
  },
) or die;
warn 'read:', $port->digitalRead(3);
my $stop;
local $SIG{INT} = sub { ++$stop };
$port->say(0.1), while !$stop;
