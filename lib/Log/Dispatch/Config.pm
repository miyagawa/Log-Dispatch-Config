package Log::Dispatch::Config;

use strict;
use vars qw($VERSION);
$VERSION = '0.02';

use AppConfig qw(:argcount);
use Log::Dispatch;

sub configure {
    my($class, $file) = @_;
    die "no config file supplied" unless $file;

    my $config = AppConfig->new({
	CREATE => 1,
	GLOBAL => {
	    ARGCOUNT => ARGCOUNT_ONE,
	},
    });
    $config->define(dispatchers => { DEFAULT => '' });
    $config->define(format      => { DEFAULT => undef });
    $config->file($file);

    *Log::Dispatch::instance = $class->make_closure($config, $file);
}

sub make_closure {
    my($class, $config, $file) = @_;

    my($instance, $ctime);
    return sub {
	my $dispclass = shift;

	# reload config, clear closure and refresh
	if (defined $ctime && (stat($file))[9] > $ctime) {
	    $class->configure($file);
	    ($instance, $ctime) = (undef, undef);
	    return $dispclass->instance;
	}

	# create composit dispatcher
	unless (defined $instance) {
	    my $callback = $class->format_to_cb($config->get('format'), 3);
	    my %dispatchers = $class->config_dispatchers($config);

	    my %args;
	    $args{callbacks} = $callback if defined $callback;
	    $instance = $dispclass->new(%args);

	    for my $dispname (keys %dispatchers) {
		my $logclass = delete $dispatchers{$dispname}->{class};
		$instance->add(
		    $logclass->new(
			name => $dispname,
			%{$dispatchers{$dispname}},
		    ),
		);
	    }
	    $ctime = time;	# memorize creation time
	}

	return $instance;
    };
}

sub config_dispatchers {
    my($class, $config) = @_;
    my %dispatchers;
    for my $disp (split /\s+/, $config->get('dispatchers')) {
	my %var = $config->varlist("^$disp\.");
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
	$dispatchers{$disp} = \%param;
    }
    return %dispatchers;
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

  my $dispatcher = Log::Dispatch->instance;

=head1 DESCRIPTION

Log::Dispatch::Config provides a way to configure Log::Dispatch with
configulation file (in AppConfig format). I mean, this is log4j for
Perl, not with all API compatibility though.

=head1 METHOD

This module has one class method C<configure> which parses config file
and declares C<instance> method in Log::Dispatch namespace. So what
you should do is call C<configure> method once in somewhere (like
C<startup.pl> in mod_perl), then you can get configured dispatcher
instance via C<Log::Dispatch-E<gt>instance>.

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

Declared C<instance> method would make C<Log::Dispatch> class
singleton, so multiple calls of C<instance> will all result in
returning same object.

  my $one = Log::Dispatch->instance;
  my $two = Log::Dispatch->instance; # same as $one

See GoF Design Pattern book for Singleton Pattern.

But in practice, in persistent environment like mod_perl, Singleton
instance is not so useful. Log::Dispatch::Config defines C<instance>
method so that the object reloads itself when configuration file is
modified since its last object creation time.

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
