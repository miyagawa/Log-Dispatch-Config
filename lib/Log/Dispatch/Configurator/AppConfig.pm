package Log::Dispatch::Configurator::AppConfig;

use strict;
use vars qw($VERSION);
$VERSION = 0.01;

use base qw(Log::Dispatch::Configurator);
use AppConfig;

sub new {
    my($class, $file) = @_;
    my $config = AppConfig->new({
	CREATE => 1,
	GLOBAL => {
	    ARGCOUNT => AppConfig::ARGCOUNT_ONE(),
	},
    });
    $config->define(dispatchers => { DEFAULT => '' });
    $config->define(format      => { DEFAULT => undef });
    $config->file($file);

    bless { file => $file, _config => $config }, $class;
}

sub _config { $_[0]->{_config} }

sub global_format {
    my $self = shift;
    return $self->_config->get('format');
}

sub dispatchers {
    my $self = shift;
    return split /\s+/, $self->_config->get('dispatchers');
}

sub attrs {
    my($self, $name) = @_;
    my %var = $self->_config->varlist("^$name\.");
    my %param = map {
        (my $key = $_) =~ s/^$name\.//;
        $key => $var{$_};
    } keys %var;
    return \%param;
}

1;
__END__

=head1 NAME

Log::Dispatch::Configurator::AppConfig - Configurator implementation with AppConfig

=head1 SYNOPSIS

  use Log::Dispatch::Config;
  use Log::Dispatch::Configurator::AppConfig;

  my $config = Log::Dispatch::Configurator::AppConfig->new('log.cfg');
  Log::Dispatch::Config->configure($config);

  # nearby piece of code
  my $log = Log::Dispatch::Config->instance;

=head1 DESCRIPTION

Log::Dispatch::Configurator::AppConfig is an implementation of
Log::Dispatch::Configurator using AppConfig format. Here is a sample
of config file.

  dispatchers = file screen

  file.class = Log::Dispatch::File
  file.min_level = debug
  file.filename = /path/to/log
  file.mode = append
  file.format = [%d] [%p] %m at %F line %L%n

  screen.class = Log::Dispatch::Screen
  screen.min_level = info
  screen.stderr = 1
  screen.format = %m

See L<Log::Dispatch::Config> for details.

=head1 AUTHOR

Tatsuhiko Miyagawa E<lt>miyagawa@bulknews.netE<gt>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<Log::Dispatch::Config>, L<AppConfig>

=cut
