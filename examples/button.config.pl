use strict;
#@button::pin = ( 2 .. 5 );
$button::action{2} = {
  1 => sub {
    my $port = shift if ref $_[0];
    our $time;
    warn('skip, too fast'), return if $time + 60 > time;
    warn "go! ";
    #warn $time, ":\n", `ssh somehost somecommand`;
    warn $time, ":\n", `ssh w-dev4 /opt/www/morda/debian/package.pl`;
    $time = time;
  },
};
$button::action{3} = { 1 => sub { my $port = shift if ref $_[0]; $port->cmd('+') }, };
$button::action{4} = { 1 => sub { my $port = shift if ref $_[0]; $port->cmd('-') }, };
1;
