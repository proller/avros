#!/usr/bin/perl
#$Id:$

=example

perl avrcmd.pm . d1000 w13,0 d500 w13,1

perl avrcmd.pm + + + M0,1 M1,1 - - - .


=INSTALL
cpan Device::SerialPort
cpan Win32::SerialPort

freebsd:
comms/p5-Device-SerialPort

windows:
choice com port number 0-9 (you cant access from commandline to coms >=10)
to set com props you can start manually:
mode COM1 BAUD=115200 PARITY=n DATA=8 STOP=1

=cut

#our %config;
package avrcmd;
use strict;
no strict qw(refs);
use warnings;
no warnings qw(uninitialized);
use Time::HiRes qw(time sleep);
use Data::Dumper;
$Data::Dumper::Sortkeys = $Data::Dumper::Useqq = $Data::Dumper::Terse = 1;
$Data::Dumper::Indent = 0;
#our $port;
#my @porttry;
#my $portpath;
local $| = 1;

sub printlog {
  print join( ' ', @_ ), "\n";
}
our $indent = 1;
our $join   = ', ';
our $prefix = 'dmp';    # 'dmp '

sub dmp (@) {
  printlog $prefix, ( caller(1) )[3], ':', ( caller(0) )[2], ' ', (
    join $join, (
      map { ref $_ ? Data::Dumper->new( [$_] )->Indent($indent)->Pair( $indent ? ' => ' : '=>' )->Terse(1)->Dump() : "'$_'" } @_
    )
    );
  wantarray ? @_ : $_[0];
}

sub schedule($$;@) {    #$Id: psmisc.pm 4690 2011-10-21 10:56:26Z pro $ $URL: svn://svn.setun.net/search/trunk/lib/psmisc.pm $
  our %schedule;
  my ( $every, $func ) = ( shift, shift );
  my $p;
  ( $p->{'wait'}, $p->{'every'}, $p->{'runs'}, $p->{'cond'}, $p->{'id'} ) = @$every
    if ref $every eq 'ARRAY';
  $p = $every if ref $every eq 'HASH';
  $p->{'every'} ||= $every if !ref $every;
  $p->{'id'} ||= join ';', caller;
  $schedule{ $p->{'id'} }{'func'} = $func
    if !$schedule{ $p->{'id'} }{'func'}
    or $p->{'update'};
  $schedule{ $p->{'id'} }{'last'} = time - $p->{'every'} + $p->{'wait'}
    if $p->{'wait'} and !$schedule{ $p->{'id'} }{'last'};
  ++$schedule{ $p->{'id'} }{'runs'}, $schedule{ $p->{'id'} }{'last'} = time, $schedule{ $p->{'id'} }{'func'}->(@_),
        if ( $schedule{ $p->{'id'} }{'last'} + $p->{'every'} < time )
    and ( !$p->{'runs'} or $schedule{ $p->{'id'} }{'runs'} < $p->{'runs'} )
    and ( !( ref $p->{'cond'} eq 'CODE' )
    or $p->{'cond'}->( $p, $schedule{ $p->{'id'} }, @_ ) )
    and ref $schedule{ $p->{'id'} }{'func'} eq 'CODE';
}

sub debug (@) {
  my $self = shift if ref $_[0];
  return unless $self->{debug};
  #&dmp;
  print join( ' ', @_ ), "\n";
}

sub check () {
  my $self = shift if ref $_[0];
  #$self->debug('chk run', caller 3);
  return if $self->{emulate};
  if ( !$self->{port} ) {    # or !exists $self->{'inited'}
    if ( !$self->port_try( $self->{wait} ) and $self->{path} ) {
      delete $self->{path};
      $self->port_try( $self->{wait} );
    }
  }
  return 'no port' unless $self->{port};
  if ( ( ( $self->{port}->can('can_status') and $self->{port}->can_status() ) or !$self->{port}->can('can_status') )
    and $self->{port}->status() <= 1 )
  {
    $self->debug("no status, reopening [$self->{path}]");
    $self->port_try( $self->{wait} );
    if ( !$self->{port} ) {
      $self->debug("no port after reopen, reopening2");
      delete $self->{path};
      $self->port_try( $self->{wait} );
    }
  }
  if ( $self->{waitinit} and !$self->{'inited'} ) {
    schedule(
      { wait => 10, every => 10 },
      our $___report ||= sub {
        my $self = shift if ref $_[0];
        #dmp "no init, findnextport[$self->{'inited'}]", $self;
        $self->{'inited'} = 0, return unless exists $self->{'inited'};    #skip first
        delete $self->{path};
        $self->port_try( $self->{wait} );
      },
      $self
    );
  }
  return 'cant reopen port' unless $self->{port};
  return;
}

sub read(;$) {
  my $self = shift if ref $_[0];
  return if $self->check();
  return if $self->{emulate};
  my $end = time + $_[0];
  my $ret;
  do {
    while ( length( my $char = $self->{port}->lookfor() ) ) {
      $ret .= $char;
    }
    $self->parse($ret);
#warn ("sl[$self->{sleep}]"),
    sleep $self->{sleep} unless length $ret;
  } while !length $ret and time < $end;
  return $ret;
}

sub say(;$) {
  my $self = shift if ref $_[0];
  return if $self->{emulate};
  my $end = time + $_[0];
  my $ret;
  local $_;
  do {
    $ret .= ( $_ = $self->read(@_) );
    print $_, "\n" if length $_;
  } while time < $end;
  return $ret;
}

sub write (@) {
  my $self = shift if ref $_[0];
  $self->debug("write [@_]");
  return if $self->{emulate};
  return if $self->check();
  $self->{port}->write( join '', @_ );
}

sub use_try ($;@) {
  ( my $path = ( my $module = shift ) . '.pm' ) =~ s{::}{/}g;
  $INC{$path}
    or eval 'use ' . $module . ' qw(' . ( join ' ', @_ ) . ');1;' and $INC{$path};
}

sub open (;$) {
  my $self = shift if ref $_[0];
  delete $self->{port};
  delete $self->{inited};
#warn("sleep$_[0]"),
  sleep $_[0] if $_[0];
  $@ = undef;
  if ($^O =~ /^(ms)?win/i and use_try 'Win32::SerialPort' ) {
    $self->{port} = Win32::SerialPort->new( $self->{path} );    # unless $@;
    warn "not opened [$self->{path}] [$@] [$!]" unless $self->{port};
  } elsif ( !$self->{port} and use_try 'Device::SerialPort' ) {
    $self->{port} = Device::SerialPort->new( $self->{path} );    # unless $@;
    warn "not opened [$self->{path}] [$@] [$!]" unless $self->{port};
  } else {
    warn 'no good lib [ Device::SerialPort Win32::SerialPort ]';
  }
  return unless $self->{port};
  $self->{port}->baudrate( $self->{'baudrate'} //= 115200 );
  $self->{port}->databits( $self->{'databits'} //= 8 );
  $self->{port}->parity( $self->{'parity'}     //= 'none' );
  $self->{port}->stopbits( $self->{'stopbits'} //= 1 );
  #$self->debug("port opts [$self->{'baudrate'}]  $self->{'databits'} $self->{'parity'} ");
  return $self->{port};
}

sub port_try {
  my $self = shift if ref $_[0];
  #dmp caller;
  #dmp "port_try[$self->{path}]", $self->{ports}, caller;
  for my $path (
      $self->{path}
    ? $self->{path}
    : sort { $self->{ports}{$a} <=> $self->{ports}{$b} || $b cmp $a }
    keys %{ $self->{ports} || {} }
    )
  {
    delete $self->{path};
    ++$self->{ports}{$path};
    $self->debug("try [$path]($self->{ports}{$path}) ");
    $self->{path} = $path if -e $path;
    next unless $self->{path};
    $self->debug("selected port [$self->{path}] [$^O]");
    $self->open();
    if ( $self->{port} ) {
      next unless $self->init();
      return $self->{port};
    }
  }
  delete $self->{port};
  delete $self->{path};
  sleep $self->{wait};
  return;
}

sub new {
  my $class = shift;
  my $self  = {@_};
  if ( ref $class eq __PACKAGE__ ) { $self = $class; }
  else                             { bless( $self, $class ) unless ref $class; }
  $self->{split}   //= qr/\n/;
  $self->{handler} //= {
    #qr{^R} => sub { warn("readed[$_[0] by $_[1]]") }
  };
  $self->{path}       //= $self->{com};
  $self->{wait}       //= 2;
  $self->{sleep}      //= 0.01;
  $self->{port_finds} //= 1;
  unless ( $self->{path} ) {
    if ( $^O =~ /^(ms|cyg)?win/i ) {
      $self->{try_from} //= 0;
      $self->{try_to}   //= 9;
      #push @{ $self->{port_try} ||= [] },
      map { ++$self->{ports}{"COM$_"} }
        reverse $self->{try_from} .. $self->{try_to};    #reverse
    } else {
      $self->{try_from} //= 0;
      $self->{try_to}   //= 3;
      if ( $^O eq 'freebsd' ) {
        #push @{ $self->{ports} ||= [] },
        map { ++$self->{ports}{"/dev/cuaU$_"} } $self->{try_from} .. $self->{try_to};
      } else {
        #push @{ $self->{port_try} ||= [] }, reverse
        map { ++$self->{ports}{"/dev/ttyUSB$_"} } $self->{try_from} .. $self->{try_to};
      }
    }
  }
  $self->check();
  return $self;
}

sub init () {
  my $self = shift if ref $_[0];
  return unless $self->{port};
  $self->{'inited'} = 0;
  if ( $^O =~ /^(ms|cyg)?win/i and !$self->{no_mode} ) {
    delete $self->{port};
    $self->{winmode} = "mode $self->{path} BAUD=$self->{'baudrate'} "
      . (
      !$self->{'parity'} ? ()
      : "PARITY="
        . (
          $self->{'parity'} eq 'odd'  ? 'o'
        : $self->{'parity'} eq 'even' ? 'e'
        : 'n'
        )
        . " "
      ) . "DATA=$self->{'databits'} STOP=$self->{'stopbits'}";
    $_ = `$self->{winmode}`;
    $self->debug( $self->{winmode}, "\n", $_ );
    $self->open();
  }
  return unless $self->{port};
  if ( $self->{'waitinit'} ) {
    my $n = 10;
    $self->debug("waiting init ($n)..");
    local $SIG{INT} = sub { $n = -1; };
    local $| = 1;
    while ( --$n >= 0 ) {
      $_ = $self->say(1);
      ++$self->{'inited'}, last if /I$self->{'deviceid'}/;
    }
  }
  $self->{init}->($self)
    if ref $self->{init} eq 'CODE'
    and ( !$self->{'waitinit'} or $self->{'inited'} );
  return $self->{'inited'} || !$self->{'waitinit'};
}

sub cmd ($;@) {
  my $self = shift if ref $_[0];
  $self->write( shift, ( join ',', @_ ), " " );
}
# arduino/hardware/arduino/cores/arduino/wiring.h
sub HIGH ()   { 1 }
sub LOW ()    { 0 }
sub INPUT ()  { 0 }
sub OUTPUT () { 1 }

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
    my $self = shift if ref $_[0];
    #print "DR:pin $_[0] changed", Dumper \@_;
    $ret = $_[1]{state};
  };
  $self->cmd( 'r', @_ );
  my $tries = 3;
  #warn("dreadgo[$self->{wait}][$ret]:"),
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
  $self->cmd( 'xsa', @_ );
}

sub servo_read($) {
  my $self = shift if ref $_[0];
  $self->cmd( 'xsr', @_ );
}

sub servo_write($$) {
  my $self = shift if ref $_[0];
  $self->cmd( 'xsw', @_ );
}

sub servo_writeMicroseconds($$) {
  my $self = shift if ref $_[0];
  $self->cmd( 'xsW', @_ );
}

sub servo_new {
    my $self = shift if ref $_[0];
    my ($name, $c) = @_;
    $c = $name, $name = undef if ref $name and !$c;
    $name //= $c->{pin};
    $self->{servo}{$name} = $c;
    $c->{start}   //= $c->{min} // 64;
    $c->{end}     //= $c->{max} // 250;
    $c->{max}     //= $c->{end}; #$c->{center} + $c->{start};
    $c->{min}     //= $c->{start};
    $c->{trim}    //= 0;
    $c->{step}    //= 30;
    $c->{center}  //= $c->{min} + ( ( $c->{end} - $c->{min} ) / 2 ) + $c->{trim};
    $c->{slow}    //= $c->{center} + $c->{step};
    $c->{slowrev} //= $c->{center} - $c->{step};
    #$c->{cmd}     //= 'W';
    $c->{cmd} //= 'xsw';
    $self->servo_attach( $c->{pin} ) unless $c->{no_attach};
    $self->servo_value($name,  $c->{center}) unless $c->{no_center};
    $c->{last}    //= $c->{center};
    $c->{init}->($self, $c) if ref $c->{init} eq 'CODE';
    return $self->{servo}{$name};
}

sub servo_v {
    my $self = shift if ref $_[0];
    my ($name, $value) = @_;
    my $c = ref $name ? $name : $self->{servo}{$name};
    unless ($value) {
#warn("r1($value)[$c->{last}]"),
        $value = $c->{last} ;
    } elsif ($value > 1 or $value < -1) {    
        #warn("r2[$value]"),
    #$value = $value ;
    } elsif ($value > 0) {
#warn("r3[$c->{center} + ($c->{max}-$c->{center}) * $value = ",($c->{center} + ($c->{max}-$c->{center}) * $value),"]"),
        $value = $c->{center} + ($c->{max}-$c->{center}) * $value * ($c->{reverse}?-1:1);
    } elsif ($value < 0) {
#warn("r4[$c->{center} + ($c->{center}-$c->{min}) * $value = ",$c->{center} + ($c->{center}-$c->{min}) * $value,"]"),
        $value = $c->{center} + ($c->{center}-$c->{min}) * $value * ($c->{reverse}?-1:1);
    }
    $value = $c->{max} if $value > $c->{max};
    $value = $c->{min} if $value < $c->{min};
    return int $value;
}

sub servo_value {
    my $self = shift if ref $_[0];
    my ($name, $value) = @_;
    my $c = ref $name ? $name : $self->{servo}{$name};
    return $c->{last} unless defined $value;
    return $self->cmd($c->{cmd}, $c->{pin}, $c->{last} = $self->servo_v($c, $value));
}

sub servo_add {
    my $self = shift if ref $_[0];
    my ($name, $value) = @_;
    my $c = ref $name ? $name : $self->{servo}{$name};
    my $l = $c->{last};
    $l = ($c->{last} - $c->{center}) / $c->{max} if $value > -1 and $value < 1;
#warn "last=$c->{last}  l=$l  v=$value";
    $self->servo_value($c, $self->servo_v($c, $l + $value));
}

sub parse ($) {
  my $self = shift if ref $_[0];
  for my $string ( map { split $self->{split}, $_ } @_ ) {
    $self->debug("parse[$string]");
    for ( keys %{ $self->{handler} || {} } ) {
      next unless $string =~ $_;
      $self->{handler}{$_}->( $self, $string, \%+, $_ )
        if ref $self->{handler}{$_} eq 'CODE';
    }
  }
}

=todo
pulseIn()
=cut

unless (caller) {
  sub {
    local $| = 1;
    my $port = __PACKAGE__->new(
      #'baudrate'=>9600,
      debug => 1, waitinit => 1,
      #path=>'COM2',
    ) or return;
    #print("[$_]"),
    $port->write( $_ . ' ' ), $port->say for @ARGV;
    my $t = time;
    local $SIG{INT} = sub { $t = 0; };
    $port->say while time - $t < 60;
    }
    ->();
}
1;
