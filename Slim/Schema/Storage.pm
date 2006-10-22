package Slim::Schema::Storage;

# $Id$

# SlimServer Copyright (c) 2001-2006 Sean Adams, Slim Devices Inc.
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License,
# version 2.

# Shim to get a backtrace out of throw_exception

use strict;
use base qw(DBIx::Class::Storage::DBI::mysql);

use Carp::Clan qw/DBIx::Class/;

use Slim::Utils::Log;
use Slim::Utils::Misc;

our $dbAccess = Slim::Utils::PerfMon->new('Database Access', [0.002, 0.005, 0.01, 0.015, 0.025, 0.05, 0.1, 0.5, 1, 5], 1);

sub throw_exception {
	my ($self, $msg) = @_;

	logBacktrace($msg);

	# Need to propagate the real error so that DBIx::Class::Storage will
	# do the right thing and reconnect to the DB.
	croak($msg);
}

sub select { 
	my $self = shift;

	$::perfmon && (my $now = Time::HiRes::time());

	my @ret = $self->next::method(@_);

	$::perfmon && $dbAccess->log(Time::HiRes::time() - $now) && msg("    DBIx select\n", undef, 1);

	return wantarray ? @ret : $ret[0];
}

sub select_single { 
	my $self = shift;

	$::perfmon && (my $now = Time::HiRes::time());

	my @ret = $self->next::method(@_);

	$::perfmon && $dbAccess->log(Time::HiRes::time() - $now) && msg("    DBIx select_single\n", undef, 1);

	return wantarray ? @ret : $ret[0];
}

1;

__END__
