use ExtUtils::MakeMaker;
WriteMakefile(
    'NAME'      => 'Log::Dispatch::Config',
    'VERSION_FROM' => 'lib/Log/Dispatch/Config.pm', # finds $VERSION
    'PREREQ_PM' => {
	Test::More => 0.32,
	Log::Dispatch => 1.79,
	AppConfig => 1.52,
	IO::Scalar => 0,
    },
);
