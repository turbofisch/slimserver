#!/usr/bin/perl -w

# SlimServer Copyright (C) 2001-2005 Sean Adams, Slim Devices Inc.
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License,
# version 2.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#

use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin";

BEGIN {
	use bootstrap;

	bootstrap->loadModules(qw(Time::HiRes DBD::SQLite DBI XML::Parser));
};

use Getopt::Long;
use File::Spec::Functions qw(:ALL);

use Slim::Music::Import;
use Slim::Music::Info;
use Slim::Music::MusicFolderScan;
use Slim::Music::PlaylistFolderScan;
use Slim::Utils::Misc;
use Slim::Utils::OSDetect;
use Slim::Utils::Prefs;
use Slim::Utils::Scanner;
use Slim::Utils::Strings qw(string);

sub main {

	our ($d_info, $d_remotestream, $d_parse, $d_import, $d_scan, $d_sql, $d_itunes);
	our ($rescan, $wipe, $itunes, $musicmagic);

	our $LogTimestamp = 1;
	our $d_server     = 1;

	GetOptions(
		'rescan'     => \$rescan,
		'wipe'       => \$wipe,
		'itunes'     => \$itunes,
		'musicmagic' => \$musicmagic,
	);

	if (!$rescan && !$wipe && !scalar @ARGV) {
		usage();
		exit;
	}

	# Bring up strings, database, etc.
	initializeFrameworks();

	my $ds = Slim::Music::Info::getCurrentDataStore();

	#
	Slim::Utils::Scanner->init;

	Slim::Music::MusicFolderScan->init;
	Slim::Music::PlaylistFolderScan->init;

	if ($itunes) {

		eval "use Plugins::iTunes::Importer";

		if ($@) {
			errorMsg("Couldn't load iTunes Importer: $@\n");
		} else {
			Plugins::iTunes::Importer->initPlugin;
		}
	}

	if ($musicmagic) {

		eval "use Plugins::MusicMagic::Importer";

		if ($@) {
			errorMsg("Couldn't load MusicMagic Importer: $@\n");
		} else {
			Plugins::MusicMagic::Importer->initPlugin;
		}
	}

	#$::d_server && msg("SlimServer checkDataSource...\n");
	#checkDataSource();

	$::d_server && msg("SlimServer done init...\n");

	if ($wipe) {
		Slim::Music::Info::wipeDBCache();
	}

	# We've been passed an explict path or URL - deal with that.
	if (scalar @ARGV) {

		for my $url (@ARGV) {

			Slim::Utils::Scanner->scanPathOrURL({ 'url' => $url });
		}

	} else {

		# Otherwise just use our Importers to scan.
		Slim::Music::Import->resetImporters;
		Slim::Music::Import->startScan;
	}

	$ds->setLastRescanTime(time);
}

sub initializeFrameworks {

	$::d_server && msg("SlimServer OSDetect init...\n");
	Slim::Utils::OSDetect::init();

	$::d_server && msg("SlimServer OS Specific init...\n");

	$SIG{'CHLD'} = 'IGNORE';
	$SIG{'PIPE'} = 'IGNORE';
	$SIG{'TERM'} = \&bootstrap::sigterm;
	$SIG{'INT'}  = \&bootstrap::sigint;
	$SIG{'QUIT'} = \&bootstrap::sigquit;

	# initialize slimserver subsystems
	$::d_server && msg("SlimServer settings init...\n");

	Slim::Utils::Prefs::init();
	Slim::Utils::Prefs::load();

	Slim::Utils::Prefs::set('prefsWriteDelay', 0);

	Slim::Utils::Prefs::checkServerPrefs();

	Slim::Utils::Prefs::makeCacheDir();	

	$::d_server && msg("SlimServer strings init...\n");
	Slim::Utils::Strings::init(catdir($Bin,'strings.txt'), "EN");

	$::d_server && msg("SlimServer Info init...\n");
	Slim::Music::Info::init();
}

sub usage {
	print <<EOF;
Usage: $0 [--rescan] [--wipe] [--itunes] [--musicmagic] <path or URL>

Examples:

	$0 --rescan /Users/dsully/Music

	$0 http://www.somafm.com/groovesalad.pls

EOF

}

sub cleanup {

	$::d_server && msg("SlimServer cleaning up.\n");

	# Make sure to flush anything in the database to disk.
	my $ds = Slim::Music::Info::getCurrentDataStore();

	if ($ds) {
		$ds->forceCommit;
	}
}

main();

__END__
