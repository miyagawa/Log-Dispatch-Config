use strict;
use Test::More 'no_plan';

use Log::Dispatch::Config::Category;

Log::Dispatch::Config::Category->configure(Foo => 't/log.cfg');
Log::Dispatch::Config::Category->configure(Bar => 't/another.cfg');

my $foo = Log::Dispatch::Config::Category->instance('Foo');
my $bar = Log::Dispatch::Config::Category->instance('Bar');

isa_ok $foo, 'Log::Dispatch::Config';
isa_ok $bar, 'Log::Dispatch::Config';

isnt "$foo", "$bar", 'not same instance';

my $bar2 = Log::Dispatch::Config::Category->instance('Bar');
is "$bar", "$bar2", 'same instance';

END { unlink 't/log.out' if -e 't/log.out' }
