#!/usr/bin/perl
#$Id:$

=INSTALL
cpan Win32::SerialPort
=cut
#our %config;
package avrcmd;
use strict;
use Time::HiRes qw(time sleep);
our $port;
my @porttry;
#my $portpath;
sub rd() {
  #Poll to see if any data is coming in
  return unless $port;
  my $ret;
  while ( length( my $char = $port->lookfor() ) ) {
    #If we get data, then print it
    #if ( length $char ) {
    #print "Recd [$char] \n";    #return $char;
    $ret .= $char;
    #}
  }
  return $ret;
}

sub rdf {
  local $_ = rd;
  s/\s+/ /;
  $_;
}

sub rdp() {
  local $_ = rd;
  #print "read[", $_, "]" if length $_;
  print $_ if length $_;
  $_;
}

sub write (@) {
  return unless $port;
  $port->write( join '', @_ );
  #print "writing [", ( join '', @_ ), "]\n";
}

sub new {
  my $class = shift;
  my (%config) = @_;
  warn %config;
  $config{path} //= $config{com};
  unless ( $config{path} ) {
    if ( $^O =~ /^(ms|cyg)?win/i ) {
      $config{try_from} //= 0;
      $config{try_to}   //= 30;
      push @porttry, map { "COM$_" } $config{try_from} .. $config{try_to};    #reverse
    } else {
      $config{try_from} //= 0;
      $config{try_to}   //= 3;
      if ( $^O eq 'freebsd' ) {
        push @porttry, map { "/dev/cuaU$_" } $config{try_from} .. $config{try_to};
      } else {
        push @porttry, reverse map { "/dev/ttyUSB$_" } $config{try_from} .. $config{try_to};
      }
    }
    for (@porttry) {
      print "try [$_]\n" if $config{debug};
      $config{path} = $_, last if -e;
    }
  }
  return unless $config{path};
  print "selected port [$config{path}] [$^O]\n" if $config{debug};
  if ( $^O =~ /^(ms)?win/i ) {
    eval q{use Win32::SerialPort; };
    $port = Win32::SerialPort->new( $config{path} ) unless $@;
  }
  #$quiet
  #|| die "Can't open $PortName: $^E\n";    # $quiet is optional
  unless ($port) {
    eval q{use Device::SerialPort;};
    #my $port = Device::SerialPort->new("/dev/tty.usbserial");
    #my $port = Device::SerialPort->new("COM2");
    $port = Device::SerialPort->new( $config{path} ) unless $@;
  }
  #die " Can't open port"
  return unless $port;
  $port->baudrate( $config{'baudrate'} //= 115200 );
  $port->databits( $config{'databits'} //= 8 );
  $port->parity( $config{'parity'}     //= 'none' );
  $port->stopbits( $config{'stopbits'} //= 1 );
  print +( map { $config{$_} . ' ' } qw(path baudrate databits parity stopbits) ), "\n" if $config{debug};
  #$config{'waitinit'} //= 1;
  if ( $config{'waitinit'} ) {
    print "waiting init..\n" if $config{debug};
    my $n = 0;
    local $SIG{INT} = sub { $n = 99999; };
    print('i'), sleep 1, $_ = rdp while $n++ < 10 and !/I/;
  }
  return $port;
}
unless (caller) {
  my $port = __PACKAGE__->new(
    #'baudrate'=>9600,
    debug => 1
  );
  sleep 1, $port->write( $_ . ' ' ) for @ARGV;
  #sleep 10;
}
1;
