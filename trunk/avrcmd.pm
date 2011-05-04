#!/usr/bin/perl
#$Id:$

=example

perl avrcmd.pm . d1000 w13,0 d500 w13,1

perl avrcmd.pm + + + M0,1 M1,1 - - - .


=INSTALL
cpan Device::SerialPort
cpan Win32::SerialPort

windows:
choice com port number 0-9 (you cant access from commandline to coms >=10)
to set com props you can start manually:
mode COM1 BAUD=115200 PARITY=n DATA=8 STOP=1

=cut
#our %config;
package avrcmd;
use strict;
use Time::HiRes qw(time sleep);
#our $port;
my @porttry;
#my $portpath;
sub read() {
  my $self = shift if ref $_[0];
  #Poll to see if any data is coming in
  return unless $self->{port};
  my $ret;
  while ( length( my $char = $self->{port}->lookfor() ) ) {
    #If we get data, then print it
    #if ( length $char ) {
    #print "Recd [$char] \n";    #return $char;
    $ret .= $char;
    #}
  }
  return $ret;
}

sub rdf {
  my $self = shift if ref $_[0];
  local $_ = $self->read;
  s/\s+/ /;
  $_;
}

sub say() {
  my $self = shift if ref $_[0];
  local $_ = $self->read;
  #local $_ = rd;
  #print "read[", $_, "]" if length $_;
  print $_, "\n" if length $_;
  $_;
}

sub write (@) {
  my $self = shift if ref $_[0];
  return unless $self->{port};
  $self->{port}->write( join '', @_ );
  #print "writing [", ( join '', @_ ), "]\n";
}

sub new {
  my $class = shift;
  my $self  = {@_};
  if ( ref $class eq __PACKAGE__ ) { $self = $class; }
  else                             { bless( $self, $class ) unless ref $class; }
  #my (%config) = @_;
  #warn %config;
  $self->{path} //= $self->{com};
  unless ( $self->{path} ) {
    if ( $^O =~ /^(ms|cyg)?win/i ) {
      $self->{try_from} //= 0;
      $self->{try_to}   //= 30;
      push @porttry, map { "COM$_" } $self->{try_from} .. $self->{try_to};    #reverse
    } else {
      $self->{try_from} //= 0;
      $self->{try_to}   //= 3;
      if ( $^O eq 'freebsd' ) {
        push @porttry, map { "/dev/cuaU$_" } $self->{try_from} .. $self->{try_to};
      } else {
        push @porttry, reverse map { "/dev/ttyUSB$_" } $self->{try_from} .. $self->{try_to};
      }
    }
    for (@porttry) {
      print "try [$_]\n" if $self->{debug};
      $self->{path} = $_, last if -e;
    }
  }
  return unless $self->{path};
  print "selected port [$self->{path}] [$^O]\n" if $self->{debug};
  if ( $^O =~ /^(ms)?win/i ) {
    eval q{use Win32::SerialPort; };
    $self->{port} = Win32::SerialPort->new( $self->{path} ) unless $@;
  }
  #$quiet
  #|| die "Can't open $self->{port}Name: $^E\n";    # $quiet is optional
  unless ( $self->{port} ) {
    eval q{use Device::SerialPort;};
    #my $self->{port} = Device::SerialPort->new("/dev/tty.usbserial");
    #my $self->{port} = Device::SerialPort->new("COM2");
    $self->{port} = Device::SerialPort->new( $self->{path} ) unless $@;
  }
  #die " Can't open port"
  return unless $self->{port};
  $self->{port}->baudrate( $self->{'baudrate'} //= 115200 );
  $self->{port}->databits( $self->{'databits'} //= 8 );
  $self->{port}->parity( $self->{'parity'}     //= 'none' );
  $self->{port}->stopbits( $self->{'stopbits'} //= 1 );
  if ( $^O =~ /^(ms|cyg)?win/i ) {
    $self->{winmode} = "mode $self->{path} BAUD=$self->{'baudrate'} "
      . (
      !$self->{'parity'}
      ? ()
      : "PARITY=" . ( $self->{'parity'} eq 'odd' ? 'o' : $self->{'parity'} eq 'even' ? 'e' : 'n' ) . " "
      ) . "DATA=$self->{'databits'} STOP=$self->{'stopbits'}";
    $_ = `$self->{winmode}`;
    print $self->{winmode}, "\n", $_ if $self->{debug};
  }
  print +( map { $self->{$_} . ' ' } qw(path baudrate databits parity stopbits) ), "\n" if $self->{debug};
  #$self->{'waitinit'} //= 1;
  if ( $self->{'waitinit'} ) {
    print "waiting init..\n" if $self->{debug};
    my $n = 0;
    local $SIG{INT} = sub { $n = 99999; };
    print('i'), sleep 1, $_ = $self->say while $n++ < 10 and !/I/;
  }
  return $self;
}

sub cmd ($;@) {
  my $self = shift if ref $_[0];
  $self->write( shift, join ',', @_ );
}

sub digitalWrite ($$) {
  my $self = shift if ref $_[0];
  $self->cmd( 'w', @_ );
}

sub analogWrite ($$) {
  my $self = shift if ref $_[0];
  $self->cmd( 'W', @_ );
}

sub pinMode ($$) {
  my $self = shift if ref $_[0];
  $self->cmd( 'm', @_ );
}

sub digitalRead ($$) {
  my $self = shift if ref $_[0];
  $self->cmd( 'r', @_ );
}

sub analogRead ($$) {
  my $self = shift if ref $_[0];
  $self->cmd( 'R', @_ );
}

=todo
tone() 
noTone()
pulseIn()
=cut
unless (caller) {
  local $| = 1;
  my $port = __PACKAGE__->new(
    #'baudrate'=>9600,
    debug    => 1,
    waitinit => 1,
  );
  #sleep 1,
  $port->write( $_ . ' ' ), $port->say for @ARGV;
  #sleep 10;
  my $t = time;
  local $SIG{INT} = sub { $t = 0; };
  $port->say while time - $t < 60;
}
1;
