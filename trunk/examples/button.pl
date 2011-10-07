#!/usr/bin/perl
#
# react on pressed button[s]
#
# demo: touch pin 4 to increase led blinking speed, pin 3 to decrease
#
#
use strict;
use Data::Dumper;
#use Time::HiRes;
use lib::abs qw(..);
use avrcmd;
#my $pin  = 3;
my @pin    = ( 3 .. 10 );
my %action = (
  3 => {
    1 => sub { my $port = shift if ref $_[0]; $port->cmd('+') },
  },
  4 => {
    1 => sub { my $port = shift if ref $_[0]; $port->cmd('-') },
  },
);
my $port = avrcmd->new(
  #'baudrate'=>9600,
  debug => 1, waitinit => 1,
  #path=>'COM1',
  handler => {
    map {
      qr{r(?<pin>$_),(?<state>\d+)} => sub {
        my $port = shift if ref $_[0];
        print "pin changed", Dumper( $_[1] ), "\n";
        $action{ $_[1]{pin} }{ $_[1]{state} }->($port) if ref $action{ $_[1]{pin} }{ $_[1]{state} } eq 'CODE';
        }
      } @pin
  },
  init => sub {
    my $port = shift if ref $_[0];
    $port->monitor( $_, 1 ) for @pin;
    $port->say(2);    #wait for monitor answers
  },
) or die;
#warn 'read:', $port->digitalRead(3);
my $stop;
local $SIG{INT} = sub { ++$stop };
$port->say(0.1), while !$stop;
