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
#use Data::Dumper;
#our $port;
#my @porttry;
#my $portpath;
sub read(;$) {
  my $self = shift if ref $_[0];
  #Poll to see if any data is coming in
  return unless $self->{port};
  my $end = time + $_[0];
  my $ret;
  do {
    #print '.';
    while ( length( my $char = $self->{port}->lookfor() ) ) {
      #If we get data, then print it
      #if ( length $char ) {
      #print "Recd [$char] \n";    #return $char;
      $ret .= $char;
      #}
    }
    #warn "[$ret]", ' ', time, ' ', $end if $ret;
    $self->parse($ret);
    sleep $self->{sleep} unless length $ret;
  } while !length $ret and time < $end;
  return $ret;
}

sub say(;$) {
  my $self = shift if ref $_[0];
  local $_ = $self->read(@_);
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
  $self->{split}   //= qr/\n/;
  $self->{handler} //= {
    qr{^R} => sub { warn("readed[$_[0] by $_[1]]") }
  };
  $self->{path}  //= $self->{com};
  $self->{wait}  //= 2;
  $self->{sleep} //= 0.01;

  unless ( $self->{path} ) {
    if ( $^O =~ /^(ms|cyg)?win/i ) {
      $self->{try_from} //= 0;
      $self->{try_to}   //= 30;
      push @{ $self->{porttry} ||= [] }, map { "COM$_" } reverse $self->{try_from} .. $self->{try_to};    #reverse
    } else {
      $self->{try_from} //= 0;
      $self->{try_to}   //= 3;
      if ( $^O eq 'freebsd' ) {
        push @{ $self->{porttry} ||= [] }, map { "/dev/cuaU$_" } $self->{try_from} .. $self->{try_to};
      } else {
        push @{ $self->{porttry} ||= [] }, reverse map { "/dev/ttyUSB$_" } $self->{try_from} .. $self->{try_to};
      }
    }
  }
  for ( $self->{path} ? $self->{path} : @{ $self->{porttry} || [] } ) {
    print "try [$_]\n" if $self->{debug};
    $self->{path} = $_ if -e;
    next unless $self->{path};
    print "selected port [$self->{path}] [$^O]\n" if $self->{debug};
    #warn $^O;
    if ( $^O =~ /^(ms)?win/i ) {
      eval q{use Win32::SerialPort;};
      $self->{port} = Win32::SerialPort->new( $self->{path} ) unless $@;
      warn "not opened [$self->{path}] [$@]" unless $self->{port};
    }
    #$quiet
    #|| die "Can't open $self->{port}Name: $^E\n";    # $quiet is optional
    unless ( $self->{port} ) {
      eval q{use Device::SerialPort;};
      #my $self->{port} = Device::SerialPort->new("/dev/tty.usbserial");
      #my $self->{port} = Device::SerialPort->new("COM2");
      $self->{port} = Device::SerialPort->new( $self->{path} ) unless $@;
      warn "not opened [$self->{path}] [$@]" unless $self->{port};
    }
    #die " Can't open port"
    #warn Dumper $self->{port};
    last if $self->{port};
  }
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
    local $| = 1;
    print('i'),
      #sleep 1,
      $_ = $self->say(1) while $n++ < 10 and !/I/;
    #warn "init[$_]";
  }
  return $self;
}

sub cmd ($;@) {
  my $self = shift if ref $_[0];
  $self->write( shift, ( join ',', @_ ), " " );
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

sub digitalRead ($) {
  my $self = shift if ref $_[0];
  my $ret;
  #warn "dcmdgo";
  local $self->{handler}{qr{r(?<pin>$_[0]),(?<state>\d+)}} = sub {
    #print "DR:pin $_[0] changed", Dumper \@_;
    $ret = $_[1]{state};
  };
  $self->cmd( 'r', @_ );
  my $tries = 3;
  #warn ("dreadgo[$self->{wait}][$ret]:"),
  $self->read( $self->{wait} ) while !length $ret and --$tries > 0;
  $ret;
}

sub analogRead ($) {
  my $self = shift if ref $_[0];
  $self->cmd( 'R', @_ );
}

sub tone ($$) {
  my $self = shift if ref $_[0];
  $self->cmd( ( $_[2] ? 'T' : 't' ), @_ );
}

sub noTone ($) {
  my $self = shift if ref $_[0];
  $self->cmd( 't', $_[0], '0' );
}

sub delay($) {
  my $self = shift if ref $_[0];
  $self->cmd( 'd', @_ );
}

sub delayMicroseconds($) {
  my $self = shift if ref $_[0];
  $self->cmd( 'D', @_ );
}

sub EEPROM_read() {
  my $self = shift if ref $_[0];
  $self->cmd( 'e', @_ );
}

sub pulseIn($) {
  my $self = shift if ref $_[0];
  $self->cmd( 'p', @_ );
}

sub pulseOut($$) {
  my $self = shift if ref $_[0];
  $self->cmd( 'P', @_ );
}
#avros only
sub monitor ($$) {
  my $self = shift if ref $_[0];
  $self->cmd( 'M', @_ );
}

sub servo_attach($) {
  my $self = shift if ref $_[0];
  $self->cmd( 'y', @_ );
}

sub servo_read($) {
  my $self = shift if ref $_[0];
  $self->cmd( 'z', @_ );
}

sub servo_write($$) {
  my $self = shift if ref $_[0];
  $self->cmd( 'Z', @_ );
}

sub parse ($) {
  my $self = shift if ref $_[0];
  for my $string ( map { split $self->{split}, $_ } @_ ) {
    #warn "parse[$string]";
    for ( keys %{ $self->{handler} || {} } ) {
      next unless $string =~ $_;
      $self->{handler}{$_}->( $string, \%+, $_ ) if ref $self->{handler}{$_} eq 'CODE';
    }
  }
}

=todo
pulseIn()
=cut

unless (caller) {
  #parse("test");
  #parse("R0");
  #parse("R1\nR2\n");
  sub {
    local $| = 1;
    my $port = __PACKAGE__->new(
      #'baudrate'=>9600,
      debug => 1, waitinit => 1,
      #path=>'COM1',
    ) or return;
    #sleep 1,
    $port->write( $_ . ' ' ), $port->say for @ARGV;
    #sleep 10;
    my $t = time;
    local $SIG{INT} = sub { $t = 0; };
    $port->say while time - $t < 60;
    }
    ->();
}
1;
