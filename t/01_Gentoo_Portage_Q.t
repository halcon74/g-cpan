#!/usr/bin/env perl

use strict;
use warnings;

use lib 'lib';
use Path::Tiny;

use Test::More tests => 6;

{
	use_ok('Gentoo::Portage::Q');
}

{
	my $cwd = Path::Tiny->cwd;
	is($cwd, '/var/tmp/portage/app-portage/g-cpan-9999/work/g-cpan-9999', 'test for cwd');
	
	my $portageq = Gentoo::Portage::Q->new();
	my $eroot = $portageq->envvar('EROOT');
	is($eroot, '', 'test for EROOT (envvar)');
	
	my $eroot_1 = $portageq->envvar_1('EROOT');
	is($eroot_1, '', 'test for EROOT (envvar_1)');
	
	my $eroot_2 = $portageq->envvar_2('EROOT');
	is($eroot_2, '/', 'test for EROOT (envvar_2)');
	
	my $eroot_from_obj = $portageq->{_eroot};
	is($eroot_from_obj, '/', 'test for EROOT (from obj)');
}