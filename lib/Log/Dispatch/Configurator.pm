package Log::Dispatch::Configurator;

use strict;
use vars qw($VERSION);
$VERSION = 0.12;

sub new {
    my($class, $file) = @_;
    my $self = bless {
	file   => $file,
	_ctime => 0,
	_watch => 0,
    }, $class;
    $self;
}

sub parse { }

sub needs_reload {
    my $self = shift;
    return $self->{_ctime} < (stat($self->{file}))[9];
}

sub conf_time {
    my $self = shift;
    $self->{_ctime} = shift if @_;
    $self->{_ctime};
}

sub should_watch {
    my $self = shift;
    $self->{_watch} = shift if @_;
    return $self->{_watch};
}

sub _abstract_method {
    require Carp;
    Carp::croak(shift, " is an abstract method of ", __PACKAGE__);
}

sub get_attrs_global { _abstract_method('get_attrs_global') }
sub get_attrs        { _abstract_method('get_attrs') }

1;
__END__

=head1 NAME

Log::Dispatch::Configurator - Abstract Configurator class

=head1 SYNOPSIS

  package Log::Dispatch::Configurator::Foo;
  use base qw(Log::Dispatch::Configurator);

  # should implement
  sub get_attrs_global { }
  sub get_attrs        { }

  # optional
  sub parse        { }
  sub needs_reload { }

=head1 DESCRIPTION

Log::Dispatch::Configurator is an abstract class of config parser. If
you make new configurator implementation, you should inherit from this
class.

See L<Log::Dispatch::Config/"PLUGGABLE CONFIGURATOR"> for details.

=head1 AUTHOR

Tatsuhiko Miyagawa E<lt>miyagawa@bulknews.netE<gt>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<Log::Dispatch::Config>

=cut

