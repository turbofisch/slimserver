package Plugins::MusicMagic::Common;

# $Id$

use strict;

use Slim::Utils::Log;
use Slim::Utils::Misc;
use Slim::Utils::OSDetect;
use Slim::Utils::Strings;

my $os  = Slim::Utils::OSDetect::OS();
my $log = logger('plugin.musicmagic');

sub convertPath {
	my $mmsPath = shift;
	
	if (Slim::Utils::Prefs::get('MMSHost') eq 'localhost') {
		return $mmsPath;
	}
	
	my $remoteRoot = Slim::Utils::Prefs::get('MMSremoteRoot');
	my $nativeRoot = Slim::Utils::Prefs::get('audiodir');
	my $original   = $mmsPath;
	my $winPath    = $mmsPath =~ m/\\/; # test if this is a windows path

	if ($os eq 'unix') {

		# we are unix
		if ($winPath) {

			# we are running music magic on winders but
			# slim server is running on unix

			# convert any windozes paths to unix style
			$remoteRoot =~ tr/\\/\//;

			$log->debug("$remoteRoot :: $nativeRoot");

			# convert windozes paths to unix style
			$mmsPath =~ tr/\\/\//;
			# convert remote root to native root
			$mmsPath =~ s/$remoteRoot/$nativeRoot/;
		}

	} else {

		# we are windows
		if (!$winPath) {

			# we recieved a unix path from music match
			# convert any unix paths to windows style
			# convert windows native to unix first
			# cuz matching dont work unless we do
			$nativeRoot =~ tr/\\/\//;

			$log->debug("$remoteRoot :: $nativeRoot");

			# convert unix root to windows root
			$mmsPath =~ s/$remoteRoot/$nativeRoot/;
			# convert unix paths to windows
			$mmsPath =~ tr/\//\\/;
		}
	}

	$log->debug("$original is now $mmsPath");

	return $mmsPath
}

sub checkDefaults {

	if (!Slim::Utils::Prefs::isDefined('musicmagic')) {
		Slim::Utils::Prefs::set('musicmagic',0)
	}

	if (!Slim::Utils::Prefs::isDefined('MMMMixType')) {
		Slim::Utils::Prefs::set('MMMMixType',0)
	}

	if (!Slim::Utils::Prefs::isDefined('MMMStyle')) {
		Slim::Utils::Prefs::set('MMMStyle',0);
	}

	if (!Slim::Utils::Prefs::isDefined('MMMVariety')) {
		Slim::Utils::Prefs::set('MMMVariety',0);
	}

	if (!Slim::Utils::Prefs::isDefined('MMMSize')) {
		Slim::Utils::Prefs::set('MMMSize',12);
	}

	if (!Slim::Utils::Prefs::isDefined('MusicMagicplaylistprefix')) {
		Slim::Utils::Prefs::set('MusicMagicplaylistprefix','MusicMagic: ');
	}

	if (!Slim::Utils::Prefs::isDefined('MusicMagicplaylistsuffix')) {
		Slim::Utils::Prefs::set('MusicMagicplaylistsuffix','');
	}

	if (!Slim::Utils::Prefs::isDefined('musicmagicscaninterval')) {
		Slim::Utils::Prefs::set('musicmagicscaninterval',60);
	}

	if (!Slim::Utils::Prefs::isDefined('MMSport')) {
		Slim::Utils::Prefs::set('MMSport',10002);
	}

	if (!Slim::Utils::Prefs::isDefined('MMSHost')) {
		Slim::Utils::Prefs::set('MMSHost','localhost');
	}
}

1;

__END__
