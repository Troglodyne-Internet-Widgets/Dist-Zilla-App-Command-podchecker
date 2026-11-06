# NAME

Dist::Zilla::App::Command::podchecker - Check the POD of a distribution as its build weaves it

# VERSION

version 0.001

# SYNOPSIS

In the root of a distribution, run `dzil podchecker` to check every module
and program, or `dzil podchecker lib/Foo/Bar.pm script/foo` to check those
files.

# DESCRIPTION

A distribution that Pod::Weaver writes the POD of has commands in its source,
such as `=method` and `=func`, that Pod::Weaver turns into plain POD in the
build.  [podchecker](https://metacpan.org/pod/podchecker) reports each of them as an error in the source, so its
verdict on such a file says nothing about the POD that ships.

`dzil podchecker` checks the POD that ships.  It runs the plugins of the
distribution in memory, as far as the files go, and runs [Pod::Checker](https://metacpan.org/pod/Pod%3A%3AChecker) on
each file as the plugins left it.  It writes no build, so a plugin that writes
into the source tree after the build, such as `[ReadmeAnyFromPod]` with
`location = root`, writes nothing.  It does run the `BeforeBuild` plugins,
because the files that a build gathers can depend on them.

With no arguments, it checks the files that `[PodWeaver]` weaves by default:
the modules that the distribution installs, and its Perl programs.  With
arguments, it checks the files of the distribution with those names, such as
`lib/Foo/Bar.pm`.

Each error and warning goes to the standard output, with the name of the file
in the distribution and the line in the woven file.  A file with no error is
reported as `pod syntax OK`.  The command dies, so `dzil` exits non-zero,
when a file has an error, or when an argument names no file of the
distribution.  A file with no POD is reported, and is no error.

The idea and the order of the plugin phases come from
[Dist::Zilla::App::Command::podpreview](https://metacpan.org/pod/Dist%3A%3AZilla%3A%3AApp%3A%3ACommand%3A%3Apodpreview), by Peter Shangov, which shows the
woven POD of one module.

# METHODS

## execute

`($opt, \@args)`.  Runs the plugins up to the files, and checks the POD of
each file that ["DESCRIPTION"](#description) says.  Dies with the number of files that have
an error.

## files\_to\_check

`(\@names)`.  The files of the distribution named in `@names`, or, with
none, those that `:InstallModules` and `:PerlExecFiles` find.  Dies with each
name that is not a file of the distribution.

## check\_file

`($file)`, a file of Dist::Zilla.  Runs Pod::Checker on its content, prints
what it found on the standard output, and returns false when it found an error.
That includes a file whose only POD commands are unknown ones, such as
`=method`, which Pod::Checker reports as an error and then counts as a file
with no POD.

# SEE ALSO

Please see those modules/websites for more information related to this module.

- [Dist::Zilla::App::Command::podpreview](https://metacpan.org/pod/Dist%3A%3AZilla%3A%3AApp%3A%3ACommand%3A%3Apodpreview)
- [Pod::Checker](https://metacpan.org/pod/Pod%3A%3AChecker)
- [Pod::Weaver](https://metacpan.org/pod/Pod%3A%3AWeaver)

# AUTHORS

Current Maintainers:

- George S. Baugh <george@troglodyne.net>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2026 by Troglodyne LLC.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
