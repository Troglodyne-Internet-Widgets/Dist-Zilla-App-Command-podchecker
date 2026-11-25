## no critic (NamingConventions::Capitalization) dzil runs the command of the lowercase name
package Dist::Zilla::App::Command::podchecker;
## use critic

# ABSTRACT: Check the POD of a distribution as its build weaves it

use 5.022;
use strict;
use warnings FATAL => 'all';

use Dist::Zilla::App -command;

=head1 SYNOPSIS

In the root of a distribution, run C<dzil podchecker> to check every module
and program, or C<dzil podchecker lib/Foo/Bar.pm script/foo> to check those
files.

=head1 DESCRIPTION

A distribution that Pod::Weaver writes the POD of has commands in its source,
such as C<=method> and C<=func>, that Pod::Weaver turns into plain POD in the
build.  L<podchecker> reports each of them as an error in the source, so its
verdict on such a file says nothing about the POD that ships.

C<dzil podchecker> checks the POD that ships.  It runs the plugins of the
distribution in memory, as far as the files go, and runs L<Pod::Checker> on
each file as the plugins left it.  It writes no build, so a plugin that writes
into the source tree after the build, such as C<[ReadmeAnyFromPod]> with
C<location = root>, writes nothing.  It does run the C<BeforeBuild> plugins,
because the files that a build gathers can depend on them.

With no arguments, it checks the files that C<[PodWeaver]> weaves by default:
the modules that the distribution installs, and its Perl programs.  With
arguments, it checks the files of the distribution with those names, such as
F<lib/Foo/Bar.pm>.

Each error and warning goes to the standard output, with the name of the file
in the distribution and the line in the woven file.  A file with no error is
reported as C<pod syntax OK>.  The command dies, so C<dzil> exits non-zero,
when a file has an error, or when an argument names no file of the
distribution.  A file with no POD is reported, and is no error.

The idea and the order of the plugin phases come from
L<Dist::Zilla::App::Command::podpreview>, by Peter Shangov, which shows the
woven POD of one module.

=cut

=method abstract

The line that C<dzil help> shows for the command.

Returns Str, the abstract.

    my $line = Dist::Zilla::App::Command::podchecker->abstract;

=cut

sub abstract { return 'check the POD of the distribution as the build weaves it' }

=method usage_desc

The usage line of the command, in the format of L<Getopt::Long::Descriptive>.

Returns Str, the usage line, with C<%c> for the name of the program and C<%o>
for the options.

    my $usage = Dist::Zilla::App::Command::podchecker->usage_desc;

=cut

sub usage_desc { return '%c podchecker %o [ <file> ... ]' }

=method execute($opt, $args)

Runs the plugins up to the files, and checks the POD of each file that
L</DESCRIPTION> says.

=over 4

=item opt - Object - the options, which the command does not read

=item args - ArrayRef[Str] - the names of the files to check, or none for the default files

=back

Returns nothing.

Dies with the number of files that have an error, when one has, and as
C<files_to_check> dies.

    $command->execute( $opt, ['lib/Foo/Bar.pm'] );

=cut

sub execute {
    my ( $self, $opt, $args ) = @_;

    # What the plugins log would mix with the report.  A plugin that fails
    # still dies with its message.
    my $chrome = $self->app->chrome;
    $chrome->logger->mute;
    my $zilla = $self->zilla;

    # The phases of a build up to the content of the files, in the order of
    # podpreview, which is the order of Dist::Zilla::Dist::Builder::build_in.
    my %phases = ( before_build => -BeforeBuild, gather_files => -FileGatherer, prune_files => -FilePruner, munge_files => -FileMunger );
    for my $phase (qw{before_build gather_files prune_files munge_files}) {
        for my $plugin ( @{ $zilla->plugins_with( $phases{$phase} ) } ) {
            $plugin->$phase;
        }
    }

    my @files = $self->files_to_check($args);
    my $bad   = 0;
    for my $file (@files) {
        $bad++ if !$self->check_file($file);
    }
    die "$bad of " . scalar(@files) . " file(s) have POD errors\n" if $bad;
    return;
}

# The files of the distribution named in C<names>, or, with none, those that
# C<:InstallModules> and C<:PerlExecFiles> find, each once.
# @param   names  ArrayRef[Str]  the names of files of the distribution, such as F<lib/Foo/Bar.pm>
# @returns the files, each a Dist::Zilla::Role::File, as a list, in the order of the names
# @throws  with each name that is not a file of the distribution
# @example my @files = $command->files_to_check( ['lib/Foo/Bar.pm'] );
sub files_to_check {
    my ( $self, $names ) = @_;
    my $zilla = $self->zilla;
    if ( !@$names ) {
        my ( %seen, @found );
        for my $finder (qw{:InstallModules :PerlExecFiles}) {
            for my $file ( @{ $zilla->find_files($finder) } ) {
                push @found, $file if !$seen{ $file->name }++;
            }
        }
        return @found;
    }
    my %by_name;
    for my $file ( @{ $zilla->files } ) {
        $by_name{ $file->name } = $file;
    }
    my @missing = grep { !exists $by_name{$_} } @$names;
    die 'Not a file of the distribution: ' . join( q{, }, @missing ) . "\n" if @missing;
    return @by_name{@$names};
}

# Runs Pod::Checker on the content of a file, and prints what it found on the
# standard output.  An error includes the unknown POD commands of a file whose
# only commands are unknown ones, such as C<=method>, which Pod::Checker
# reports as an error and then counts as a file with no POD.  A file with no
# POD has no error.
# @param   file  Object  the file to check, which does Dist::Zilla::Role::File
# @returns Bool  false when the file has an error, true otherwise
# @throws  when it cannot print to the standard output
# @example my $ok = $command->check_file($file);
sub check_file {
    my ( $self, $file ) = @_;
    my $checker = Dist::Zilla::App::Command::podchecker::Checker->new( -warnings => 1 );
    $checker->output_fh( \*STDOUT );
    $checker->source_filename( $file->name );
    $checker->parse_string_document( $file->encoded_content );
    my $counted = $checker->num_errors;
    my $errors  = $counted < 0 ? $checker->errors : $counted;
    if ( $errors <= 0 && $counted < 0 ) {
        print {*STDOUT} $file->name . " does not contain any pod commands.\n" or die "Cannot print: $!\n";
        return 1;
    }
    print {*STDOUT} $file->name . ( $errors ? " has $errors pod syntax error(s).\n" : " pod syntax OK.\n" ) or die "Cannot print: $!\n";
    return !$errors;
}

# Pod::Checker sets num_errors to -1 at the end of a document in which it saw
# no POD command that it knows, and so drops the errors that it counted.
# Here, because App::Cmd would load a module of its own under Command as a
# command.
package Dist::Zilla::App::Command::podchecker::Checker;    ## no critic (NamingConventions::Capitalization) under the command of the lowercase name

use parent 'Pod::Checker';

sub end_Document {    ## no critic (NamingConventions::Capitalization) the name of the hook of Pod::Simple::Methody
    my ( $self, @args ) = @_;
    $self->{ __PACKAGE__ . '/errors' } = $self->num_errors;
    return $self->SUPER::end_Document(@args);
}

sub errors {
    my ($self) = @_;
    return $self->{ __PACKAGE__ . '/errors' } // -1;
}

package Dist::Zilla::App::Command::podchecker;    ## no critic (NamingConventions::Capitalization) the POD below belongs to the command

=head1 SEE ALSO

L<Dist::Zilla::App::Command::podpreview>
L<Pod::Checker>
L<Pod::Weaver>

=cut

1;
