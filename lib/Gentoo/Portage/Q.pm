package Gentoo::Portage::Q;

=head1 NAME

Gentoo::Portage::Q - Portage information query tool

=head1 SYNOPSIS

    use Gentoo::Portage::Q;

    my $portageq = Gentoo::Portage::Q->new();
    my $eroot = $portageq->envvar('EROOT');
    my $repos = $portageq->get_repos($eroot);
    my $repo_path = $portageq->get_repo_path( $eroot, 'gentoo' );

=head1 DESCRIPTION

The module provides interface for portage information query (mimic of L<portageq>)
Trying to keep the same interface as L<portageq> (part of L<portage>).

=cut

use strict;
use warnings;

use Config::Tiny;
use Path::Tiny;

our $VERSION = '0.001';

# default locations (paths) for make.profile & portage env settings (make.conf and friends)
# order matters, latest might overwrite previous values
my @make_profile = ( '/etc/make.profile', '/etc/portage/make.profile' );
my @portage_settings =
  ( '/usr/share/portage/config/make.globals', '/etc/make.conf', '/etc/portage/make.conf', "$ENV{HOME}/.gcpanrc" );

=head1 METHODS

=head2 new()

Returns a new C<Gentoo::Portage::Q> object.

=cut

sub new {
    my $class = shift;
    return bless {}, $class;
}

=head2 envvar($variable)

Returns a specific environment variable as exists prior to ebuild.sh.
WARNING: At the moment the method is very limited and have only few hardcoded vars to return, like C<EROOT>.

=cut

sub envvar {
    my ( $self, $var ) = @_;

    return $ENV{$var} if defined $ENV{$var};    # prefer to use custom from ENV

    unless ( $self->{_portage_env} ) {
        $self->{_portage_env} = $self->_read_portage_env();
        $self->{_portage_env}{EROOT} ||= '/';    # hardcoded, need to change to support Gentoo Prefix Project
    }

    return $self->{_portage_env}{$var};
}

=head2 get_repo_path( $eroot, $repo_id )

Returns the path to the C<$repo_id>.

=cut

sub get_repo_path {
    my ( $self, $eroot, $repo_id ) = @_;

    $self->{_repo} ||= $self->_load_repos($eroot);

    unless ( $self->{_repo}{$repo_id} ) {
        # if not loaded by 'get_repos' then trying to guess file name
        my $repo_conf_file = path( $eroot, 'etc', 'portage', 'repos.conf' )->child("$repo_id.conf");
        if ( $repo_conf_file->exists ) {
            my $repo_conf = Config::Tiny->read($repo_conf_file);
            $self->{_repo}{$repo_id} = $repo_conf->{$repo_id};
        }
        else { return; }
    }

    return $self->{_repo}{$repo_id}{location};
}

=head2 get_repos($eroot)

Returns arrayref with all C<repos> with names (repo_name file).

=cut

sub get_repos {
    my ( $self, $eroot ) = @_;

    unless ( $self->{_repos} ) {
        $self->{_repo} ||= $self->_load_repos($eroot);

        # keep order by priority, like portageq
        $self->{_repos} = [
            sort { ( $self->{_repo}{$b}{priority} || 0 ) <=> ( $self->{_repo}{$a}{priority} || 0 ) }
              keys %{ $self->{_repo} }
        ];
    }

    return $self->{_repos};
}


### helpers

sub _load_repos {
    my ( $self, $eroot ) = @_;
    my %repos;

    for my $file ( path( $eroot, 'etc', 'portage', 'repos.conf' )->children(qr/\.conf$/) ) {
        if ( -e $file ) {
            my $conf = Config::Tiny->read($file);
            $repos{$_} = $conf->{$_} for keys %$conf;
        }
    }
    # skip it, like portageq
    delete $repos{DEFAULT};

    return \%repos;
}

# manage list of portage env settings files (see man make.conf)
sub _portage_env_files {
    my $self = shift;

    unless ( $self->{_portage_env_files} ) {
        my @_make_profile = @make_profile;    # avoid to override the global var
        while (@_make_profile) {
            my $path = shift @_make_profile;
            if ( -l $path ) {
                unshift @_make_profile, path($path)->realpath;
            }
            elsif ( -d $path ) {
                my $mp = path( $path, 'make.defaults' );
                unshift @{ $self->{_portage_env_files} }, "$mp" if $mp->exists;
                # handle parent file, add each parent's location
                my $p = path( $path, 'parent' );
                if ( $p->exists ) {
                    push @_make_profile,
                      map { substr( $_, 0, 1 ) eq '/' ? $_ : path( $path, $_ )->realpath } $p->lines( { chomp => 1 } );
                }
            }
        }

        for my $path (@portage_settings) {
            if ( -d $path ) {
                push @{ $self->{_portage_env_files} }, sort map { "$_" } path($path)->children();
            }
            elsif ( -e $path ) {
                push @{ $self->{_portage_env_files} }, $path;
            }
        }
    }

    return $self->{_portage_env_files};
}

# execute each portage env settings file and collect all env settings from them
sub _read_portage_env {
    my $self = shift;
    my %portage_env;

    for my $file ( @{ $self->_portage_env_files } ) {
        open( my $h, '-|', "bash -norc -noprofile -c '. $file; set'" ) or die "Can't run bash command: $!";
        while ( defined( my $l = <$h> ) ) {
            # skip already defined ENV vars, since we want only portage env
            if ( $l =~ /^(\w+)=(.*?)$/ and not defined $ENV{$1} ) {
                $portage_env{$1} = _strip_env_var($2);
            }
        }
        close $h;
    }

    return \%portage_env;
}

sub _strip_env_var {
    my $var = shift;
    $var =~ s/\\n|\\t/ /g;
    $var =~ s/\s+/ /g;
    $var =~ s/\$|'//g;
    $var =~ s/^\s//;
    $var =~ s/\s$//;
    return $var;
}

1;

__END__

=head1 TODO

=over

=item Split the module and place onto CPAN as separate one

=back

=head1 AUTHOR

Sergiy Borodych <bor@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2016 by Sergiy Borodych.

Distributed under the terms of the GNU General Public License v2.

=head1 SEE ALSO

L<portageq>, L<https://wiki.gentoo.org/wiki/Portageq>, L<https://wiki.gentoo.org/wiki//etc/portage/repos.conf>

=cut