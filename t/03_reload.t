use strict;
use Test::More tests => 4;

use Log::Dispatch::Config;
use FileHandle;
use File::Temp qw(tempfile);
use IO::Scalar;

sub writefile {
    my $fh = FileHandle->new(">" . shift) or die $!;
    $fh->print(@_);
}

my($fh, $file) = tempfile;
writefile($file, <<'CFG');
dispatchers=foo
foo.class=Log::Dispatch::File
foo.filename=/dev/null
foo.min_level=debug
CFG
    ;

Log::Dispatch::Config->configure($file);

{
    my $disp = Log::Dispatch::Config->instance;
    isa_ok $disp->{outputs}->{foo}, 'Log::Dispatch::File';

    sleep 1;

    writefile($file, <<'CFG');
dispatchers=bar
bar.class=Log::Dispatch::File
bar.filename=/dev/null
bar.min_level=debug
CFG
    ;

    local $^W;
    my $disp2 = Log::Dispatch::Config->instance;
    isa_ok $disp2->{outputs}->{bar}, 'Log::Dispatch::File';
    is $disp2->{outputs}->{foo}, undef;
    isnt "$disp", "$disp2", "$disp - $disp2";
}
