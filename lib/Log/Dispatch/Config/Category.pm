package Log::Dispatch::Config::Category;

use strict;
use vars qw($VERSION);
$VERSION = 0.11_01;

use Log::Dispatch::Config;

sub _prepare_config {
    my($class, $name, $config) = @_;
    die "Usage: configure(name, conf)" unless $name && $config;

    my $subclass = $class->_classname($name);
    unless ($subclass->isa('Log::Dispatch::Config')) {
	eval <<EVIL;
package $subclass;
use base qw(Log::Dispatch::Config);
EVIL
    ;
    }
    return $subclass;
}

sub configure {
    my($class, $name, $config) = @_;
    my $subclass = $class->_prepare_config($name, $config);
    $subclass->configure($config);
}

sub configure_and_watch {
    my($class, $name, $config) = @_;
    my $subclass = $class->_prepare_config($name, $config);
    $subclass->configure_and_watch($config);
}

sub instance {
    my($class, $name) = @_;
    return $class->_classname($name)->instance;
}

sub reload {
    my($class, $name) = @_;
    return $class->_classname($name)->reload;
}

sub _classname {
    my($class, $name) = @_;
    # stolen from Apache::Registry
    $name =~ s/([^A-Za-z0-9_\/])/sprintf("_%2x",unpack("C",$1))/eg;
    return __PACKAGE__ . "::$name";
}

1;
__END__

=head1 NAME

Log::Dispatch::Config::Category - Named logger class

=head1 SYNOPSIS

  use Log::Dispatch::Config::Category;
  Log::Dispatch::Config::Category->configure(Foo => 'foo.conf');
  Log::Dispatch::Config::Category->configure(Bar => 'Bar.conf');

  my $foo = Log::Dispatch::Config::Category->instance('Foo');
  my $bar = Log::Dispatch::Config::Category->instance('Bar');

=head1 DESCRIPTION

Log::Dispatch::Config::Category is an utility for
Log::Dispatch::Config which provides a way to name Logger instances
with their own unique names. Maybe useful for persistent environment
like mod_perl.

The word I<category> is chosen from log4j's one. Note that the concept
is same, but the interface (how to define category) is different.

=head1 BEHIND THE SCENES

Log::Dispatch::Config::Category is not a subclass of
Log::Dispatch::Config, but configure() call makes subclasses at
run-time (hackish!)

For example,

  Log::Dispatch::Config::Category->configure(Foo => 'foo.conf');

will result to:

  package Log::Dispatch::Config::Category::Foo;
  use base qw(Log::Dispatch::Config);

=head1 TODO

=over 4

=item *

Defines default logger for not confgured name. log4j has root for it.

=cut

=head1 AUTHOR

Tatsuhiko Miyagawa E<lt>miyagawa@bulknews.netE<gt>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<Log::Dispatch::Config>

=cut
