#!/usr/bin/perl
#
# react on pressed button
#
use strict;
use lib::abs qw(..);
use avrcmd;
my $pin  = 3;
my $port = avrcmd->new(
  #'baudrate'=>9600,
  debug => 1, waitinit => 1,
  #path=>'COM1',
  handler => {
    qr{R$pin} => sub { print "pin $pin changed" }
  }
) or die;
$port->monitor( $pin, 1 );
my $stop;
local $SIG{INT} = sub { ++$stop };
$port->say while !$stop;
