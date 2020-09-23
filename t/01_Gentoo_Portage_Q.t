#!/usr/bin/env perl

use strict;
use warnings;

use lib 'lib';
use Path::Tiny;

use Test::More tests => 2;

{
	use_ok('Gentoo::Portage::Q');
}

{
	my $cwd = Path::Tiny->cwd;
	
	is($cwd, 'abcdef', 'test for cwd');
}