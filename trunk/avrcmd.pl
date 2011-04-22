#!/usr/bin/perl
# $Id:$

=INSTALL
cpan Win32::SerialPort
=cut
#our %config;

package avrcmd;
use strict;
use Time::HiRes qw(time sleep);
our $port;
my @porttry;
my $portpath;


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
    print "read[", $_, "]" if length $_;
    $_;
}

sub write (@) {
    return unless $port;
    $port->write( join '', @_ );
    print "writing [", ( join '', @_ ), "]\n";
}


sub new {
    my (%config) = @_;
    $portpath ||= $config{com};
    unless ($portpath) {
        if ( $^O =~ /^(ms|cyg)?win/i ) {

            push @porttry, map {"COM$_"}  1..30; #reverse
            #push @porttry, 'COM1';
            #push @porttry, 'COM3';
            #push @porttry, 'COM4';
        }
        elsif ( $^O eq 'freebsd' ) {
            push @porttry, '/dev/cuaU0';
        }
        else {
            push @porttry, reverse qw(/dev/ttyUSB0 /dev/ttyUSB1);
        }
        for (@porttry) { print "try [$_]\n"; $portpath = $_, last if -e; }
    }
    print "selected port [$portpath] [$^O]\n";
    if ( $^O =~ /^(ms)?win/i ) {
        eval q{use Win32::SerialPort; };
        $port = Win32::SerialPort->new($portpath) unless $@;
    }

    #$quiet
    #|| die "Can't open $PortName: $^E\n";    # $quiet is optional
    unless ($port) {
        eval q{use Device::SerialPort;};

        #my $port = Device::SerialPort->new("/dev/tty.usbserial");
        #my $port = Device::SerialPort->new("COM2");
        $port = Device::SerialPort->new($portpath) unless $@;
    }

    #  die " Can't open port"
    return unless $port;

    #$port->baudrate(9600);
    $port->baudrate( $config{baudrate} //= 115200 );
    $port->databits( $config{databits} //= 8 );
    $port->parity( $config{parity}     //= 'none' );
    $port->stopbits( $config{stopbits} //= 1 );
    print "[$portpath]: ",
      ( map { $config{$_} . ' ' } qw(baudrate databits parity stopbits) ), "\n";
    print "waiting init..\n";
    my $n = 0;
    local $SIG{INT} = sub { $n = 99999; };

    print('i'), sleep 1, $_ = rdp while $n++ < 10 and !/I/;

    return $port;
}

unless (caller) {
my $port = __PACKAGE__->new();
$port->write($_) for @ARGV;
}

1;
