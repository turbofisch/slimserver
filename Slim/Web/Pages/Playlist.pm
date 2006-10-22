package Slim::Web::Pages::Playlist;

# $Id$

# SlimServer Copyright (c) 2001-2004 Sean Adams, Slim Devices Inc.
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License, 
# version 2.

use strict;

use File::Spec::Functions qw(:ALL);
use POSIX ();
use Scalar::Util qw(blessed);

use Slim::Utils::Log;
use Slim::Utils::Misc;
use Slim::Utils::Strings qw(string);
use Slim::Web::Pages;

my $log = logger('player.playlist');

sub init {
	
	Slim::Web::HTTP::addPageFunction( qr/^playlist\.(?:htm|xml)/, \&playlist, 'fork' );
}

sub playlist {
	my ($client, $params, $callback, $httpClient, $response) = @_;
	
	if (!defined($client)) {

		# fixed faster rate for noclients
		$params->{'playercount'} = 0;
		return Slim::Web::HTTP::filltemplatefile("playlist.html", $params);
	
	} elsif ($client->needsUpgrade()) {

		$params->{'player_needs_upgrade'} = '1';
		return Slim::Web::HTTP::filltemplatefile("playlist_needs_upgrade.html", $params);
	}
	
	# If synced, use the master's playlist
	$client = Slim::Player::Sync::masterOrSelf($client);

	$params->{'playercount'} = Slim::Player::Client::clientCount();
	
	my $songcount = Slim::Player::Playlist::count($client);

	$params->{'playlist_items'} = '';
	$params->{'skinOverride'} ||= '';
	
	my $count = Slim::Utils::Prefs::get('itemsPerPage');

	unless (defined($params->{'start'}) && $params->{'start'} ne '') {

		$params->{'start'} = (int(Slim::Player::Source::playingSongIndex($client)/$count)*$count);
	}

	if ($client->currentPlaylist() && !Slim::Music::Info::isRemoteURL($client->currentPlaylist())) {
		$params->{'current_playlist'} = $client->currentPlaylist();
		$params->{'current_playlist_modified'} = $client->currentPlaylistModified();
		$params->{'current_playlist_name'} = Slim::Music::Info::standardTitle($client,$client->currentPlaylist());
	}

	if ($log->is_debug && $client->currentPlaylistRender() && ref($client->currentPlaylistRender()) eq 'ARRAY') {

		$log->debug("currentPlaylistChangeTime : " . localtime($client->currentPlaylistChangeTime()));
		$log->debug("currentPlaylistRender     : " . localtime($client->currentPlaylistRender()->[0]));
		$log->debug("currentPlaylistRenderSkin : " . $client->currentPlaylistRender()->[1]);
		$log->debug("currentPlaylistRenderStart: " . $client->currentPlaylistRender()->[2]);

		$log->debug("skinOverride: $params->{'skinOverride'}");
		$log->debug("start: $params->{'start'}");
	}

	# Only build if we need to.
	# Check to see if we're newer, and the same skin.
	if ($songcount > 0 && 
		defined $params->{'skinOverride'} &&
		defined $params->{'start'} &&
		$client->currentPlaylistRender() && 
		ref($client->currentPlaylistRender()) eq 'ARRAY' && 
		$client->currentPlaylistChangeTime() && 
		$client->currentPlaylistRender()->[1] eq $params->{'skinOverride'} &&
		$client->currentPlaylistRender()->[2] eq $params->{'start'} &&
		$client->currentPlaylistChangeTime() < $client->currentPlaylistRender()->[0]) {

		if (Slim::Utils::Prefs::get("playlistdir")) {
			$params->{'cansave'} = 1;
		}

		$log->info("Skipping playlist build - not modified.");

		$params->{'playlist_items'}   = $client->currentPlaylistRender()->[3];
		$params->{'pageinfo'}         = $client->currentPlaylistRender()->[4];

		return Slim::Web::HTTP::filltemplatefile("playlist.html", $params);
	}

	if (!$songcount) {
		return Slim::Web::HTTP::filltemplatefile("playlist.html", $params);
	}

	my $item;
	my %form;

	$params->{'cansave'} = 1;
	
	$params->{'pageinfo'} = Slim::Web::Pages->pageInfo({
				'itemCount'    => $songcount,
				'currentItem'  => Slim::Player::Source::playingSongIndex($client),
				'path'         => $params->{'path'},
				'otherParams'  => "player=" . Slim::Utils::Misc::escape($client->id()),
				'start'        => $params->{'start'},
				'perPage'      => $params->{'itemsPerPage'},
	});
	
	my ($start,$end);
	$start = $params->{'start'} = $params->{'pageinfo'}{'startitem'};
	$end = $params->{'pageinfo'}{'enditem'};
	
	my $offset = $start % 2 ? 0 : 1; 

	my $currsongind   = Slim::Player::Source::playingSongIndex($client);

	my $itemCount    = 0;
	my $itemsPerPass = Slim::Utils::Prefs::get('itemsPerPass');
	my $itemsPerPage = Slim::Utils::Prefs::get('itemsPerPage');
	my $composerIn   = Slim::Utils::Prefs::get('composerInArtists');

	$params->{'playlist_items'} = [];
	$params->{'myClientState'}  = $client;

	# This is a hot loop.
	# But it's better done all at once than through the scheduler.
	for my $itemnum ($start..$end) {

		# These should all be objects - but be safe.
		my $objOrUrl = Slim::Player::Playlist::song($client, $itemnum);
		my $track    = $objOrUrl;

		if (!blessed($objOrUrl) || !$objOrUrl->can('id')) {

			$track = Slim::Schema->rs('Track')->objectForUrl($objOrUrl) || do {

				logError("Couldn't retrieve objectForUrl: [$objOrUrl] - skipping!");

				$itemCount++;
				next;
			};
		}

		my %form = ();

		$track->displayAsHTML(\%form);

		$form{'num'}       = $itemnum;
		$form{'levelName'} = 'track';
		$form{'odd'}       = ($itemnum + $offset) % 2;

		if ($itemnum == $currsongind) {
			$form{'currentsong'} = "current";

			if (Slim::Music::Info::isRemoteURL($track)) {
				$form{'title'} = Slim::Music::Info::standardTitle(undef, $track) || $track->url;
			} else {
				$form{'title'} = Slim::Music::Info::getCurrentTitle(undef, $track->url);
			}

		} else {

			$form{'currentsong'} = undef;
			$form{'title'}    = Slim::Music::Info::standardTitle(undef, $track);
		}

		$form{'nextsongind'} = $currsongind + (($itemnum > $currsongind) ? 1 : 0);

		push @{$params->{'playlist_items'}}, \%form;

		$itemCount++;

		# don't neglect the streams too long, every itemsPerPass idle them
		if (!($itemCount % $itemsPerPass)) {

			main::idleStreams();
		}
	}

	$log->info("End playlist build. $itemCount items");

	# Give some player time after the loop, but before rendering.
	main::idleStreams();

	if ($client) {

		# Stick the rendered data into the client object as a stopgap
		# solution to the cpu spike issue.
		$client->currentPlaylistRender([
			time(),
			($params->{'skinOverride'} || ''),
			($params->{'start'}),
			$params->{'playlist_items'},
			$params->{'pageinfo'},
		]);
	}

	return Slim::Web::HTTP::filltemplatefile("playlist.html", $params),
}

1;

__END__
