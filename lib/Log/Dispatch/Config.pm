package Log::Dispatch::Config;

use strict;
use vars qw($VERSION);
$VERSION = '0.05_01';

require Log::Dispatch;
use base qw(Log::Dispatch);
use fields qw(filename ctime);
use vars qw($_Instance);

sub configure {
    my($class, $file) = @_;
    die "no config file supplied" unless $file;

    # now keep $file as an instance, later we should make object
    $_Instance = $file;
}

# backward compatibility
sub Log::Dispatch::instance {
    __PACKAGE__->instance;
}

sub instance {
    my $class = shift;
    unless (defined $_Instance) {
	require Carp;
	Carp::croak("Log::Dispatch::Config->configure not yet called.");
    }

    if (ref($_Instance) && UNIVERSAL::isa($_Instance, 'Log::Dispatch::Config')) {
        # reload singleton on the fly
        $_Instance = $_Instance->reload;
    }
    else {
        # first time call: $_Instance is a filename or not L::D::C
	$_Instance = $class->create_instance($_Instance);
    }

    return $_Instance;
}

sub reload {
    my $self = shift;
    my $class = ref($self);

    my $new = $self;
    if ($self->{ctime} <= (stat($self->{filename}))[9]) {
	$new = $class->create_instance($self->{filename});
    }

    return $new;
}

sub create_instance {
    my($class, $file) = @_;

    my $config = $class->get_config($file);

    my $callback = $class->format_to_cb($config->get('format'), 3);
    my %dispatchers;
    foreach my $disp (split /\s+/, $config->get('dispatchers')) {
        $dispatchers{$disp} = $class->config_dispatcher(
                $disp,
                $config->varlist("^$disp\\."),
	    );
    }

    my %args;
    $args{callbacks} = $callback if defined $callback;
    my $instance = $class->new(%args);

    for my $dispname (keys %dispatchers) {
	my $logclass = delete $dispatchers{$dispname}->{class};
	$instance->add(
	    $logclass->new(
		name => $dispname,
		%{$dispatchers{$dispname}},
	    ),
	);
    }

    # config info
    $instance->{filename}  = $file;
    $instance->{ctime} = time;

    return $instance;
}

sub get_config {
    my ($class, $file) = @_;

    require AppConfig;

    my $config = AppConfig->new({
	CREATE => 1,
	GLOBAL => {
	    ARGCOUNT => AppConfig::ARGCOUNT_ONE(),
	},
    });
    $config->define(dispatchers => { DEFAULT => '' });
    $config->define(format      => { DEFAULT => undef });
    $config->file($file);

    return $config;
}

sub config_dispatcher {
    my($class, $disp, %var) = @_;
    my %param = map {
        (my $key = $_) =~ s/^$disp\.//;
        $key => $var{$_};
    } keys %var;

    my $dispclass = $param{class}
        or die "class param missing for $disp";

    eval qq{require $dispclass};
    die $@ if $@ && $@ !~ /locate/;

    if (exists $param{format}) {
        $param{callbacks} = $class->format_to_cb(delete $param{format}, 5);
    }
    return \%param;
}

sub format_to_cb {
    my($class, $format, $stack) = @_;
    return undef unless defined $format;

    my %syn = (
	d => 'datetime',
	p => 'level',
	m => 'message',
	F => 'filename',
	L => 'line',
	P => 'package',
    );
    $format =~ s/%([dpmFLP])/\$\{$syn{$1}\}/g;
    $format =~ s/%n/\n/g;

    return sub {
	my %p = @_;
	@p{qw(package filename line)} = caller($stack);
	$p{datetime} = scalar localtime;
	my $log = $format;
	$log =~ s/\$\{(.+?)\}/$p{$1}/g;
	return $log;
    };
}

1;
__END__

=head1 NAME

Log::Dispatch::Config - Log4j for Perl

=head1 SYNOPSIS

  use Log::Dispatch::Config;
  Log::Dispatch::Config->configure('/path/to/config');

  my $dispatcher = Log::Dispatch::Config->instance;

  # or the same (may be deprecated)
  my $dispatcher = Log::Dispatch->instance;

=head1 DESCRIPTION

Log::Dispatch::Config is a subclass of Log::Dispatch and provides a
way to configure Log::Dispatch object with configulation file (in
AppConfig format). I mean, this is log4j for Perl, not with all API
compatibility though.

=head1 METHOD

This module has a class method C<configure> which parses config file
for later creation of the Log::Dispatch::Config singleton instance.
(Actual construction of the object is done in the first C<instance>
call).

So, what you should do is call C<configure> method once in somewhere
(like C<startup.pl> in mod_perl), then you can get configured
dispatcher instance via C<Log::Dispatch::Config-E<gt>instance>.

Formerly, C<configure> method declares C<instance> method in
Log::Dispatch namespace. Now it inherits from Log::Dispatch, so the
namespace pollution is not necessary. Currrent version still defines
one-liner shortcut:

  sub Log::Dispatch::instance { Log::Dispatch::Config->instance }

so still you can call C<Log::Dispatch-E<gt>instance>, if you prefer,
or for backward compatibility.

=head1 CONFIGURATION

Here is an example of the config file:

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

Config file is parsed with AppConfig module, see L<AppConfig> when you
face configuration parsing error.

=head2 GLOBAL PARAMETERS

=over 4

=item dispatchers

  dispatchers = file screen

C<dispatchers> defines logger names, which will be splitted by spaces.
If this parameter is unset, no logging is done.

=item format

  format = [%d] [%p] %m at %F line %L%n
  format = [${datetime}] [${prioity}] ${message} at ${filename} line ${line}\n

C<format> defines log format. C<%X> style and C<${XXX}> style are both
supported. Possible conversions format are

  %d ${datetime}	datetime string
  %p ${priority}	priority (debug, info, warning ...)
  %m ${message}		message string
  %F ${filename}	filename
  %L ${line}		line number
  %P ${package}		package
  %n 			newline (\n)

C<format> defined here would apply to all the log messages to
dispatchers. This parameter is B<optional>.

=back

=head2 PARAMETERS FOR EACH DISPATCHER

Parameters for each dispatcher should be prefixed with "name.", where
"name" is the name of each one, defined in global C<dispatchers>
parameter.

=over 4

=item class

  screen.class = Log::Dispatch::Screen

C<class> defines class name of Log::Dispatch subclasses. This
parameter is B<essential>.

=item format

  screen.format = -- %m --

C<format> defines log format which would be applied only to the
dispatcher. Note that if you define global C<format> also, C<%m> is
double formated (first global one, next each dispatcher one). This
parameter is B<optional>.

=item (others)

  screen.min_level = info
  screen.stderr = 1

Other parameters would be passed to the each dispatcher
construction. See Log::Dispatch::* manpage for the details.

=back

=head1 SINGLETON

Declared C<instance> method would make C<Log::Dispatch::Config> class
singleton, so multiple calls of C<instance> will all result in
returning same object.

  my $one = Log::Dispatch::Config->instance;
  my $two = Log::Dispatch::Config->instance; # same as $one

See GoF Design Pattern book for Singleton Pattern.

But in practice, in persistent environment like mod_perl, Singleton
instance is not so useful. Log::Dispatch::Config defines C<instance>
method so that the object reloads itself when configuration file is
modified since its last object creation time.

=head1 SUBCLASSING

Should you wish to use something other than AppConfig to configure
your logging, you can subclass Log::Dispatch::Config. Then you
will need to implement the following:

=over 4

=item *

A C<get_config()> class method that returns an object from
which to retrieve configuration information. Specifically this
object must support two methods: C<$obj-E<lt>get('property')> and
C<$obj-E<lt>varlist('^name\\.')>. See the AppConfig methods of
the same name for implementation details. The C<get_config()>
method will be passed whatever was passed into C<configure()>.

=item *

Possibly a reload() method which returns $self if the class does
not need to be reloaded, or a new object (usually created via
a class method call to C<create_instance()>). The "thing" you
passed to C<configure()> will be stored in $self->{filename}.

Note that you do not need to implement this if your config class
is based on filesystem files.

=back

=head1 TODO

=over 4

=item *

LogLevel configuration depending on caller package like log4j?

=back

=head1 AUTHOR

Tatsuhiko Miyagawa E<lt>miyagawa@bulknews.netE<gt>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<Log::Dispatch>, L<AppConfig>

=cut
