use strict;
use Test::More tests => 4;

use Log::Dispatch::Config;
use FileHandle;
use IO::Scalar;

sub slurp {
    my $fh = FileHandle->new(shift) or die $!;
    local $/;
    return $fh->getline;
}

my $log;
BEGIN { $log = 't/log.out'; unlink $log if -e $log }
END   { unlink $log if -e $log }

Log::Dispatch::Config->configure('t/log.cfg');

tie *STDERR, 'IO::Scalar', \my $err;

my $disp = Log::Dispatch::Config->instance;
$disp->debug('debug');
$disp->alert('alert');

untie *STDERR;

my $file = slurp $log;
like $file, qr(debug at t/02_log\.t), 'debug';
like $file, qr(alert at t/02_log\.t), 'alert';

ok $err !~ qr/debug/, 'no debug';
is $err, "alert %", 'alert %';



