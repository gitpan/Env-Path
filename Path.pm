package Env::Path;

$VERSION = '0.10';

require 5.004;
use strict;

use constant MSWIN => $^O =~ /MSWin32|Windows_NT/i;

my $dsep = MSWIN ? ';' : ':';

sub new {
    my $class = shift;
    my $pathvar = shift;
    my $pathref = \$ENV{$pathvar};
    bless $pathref, $class;
    $pathref->Assign(@_) if @_;
    return $pathref if defined wantarray;
    eval "\@$pathvar\::ISA = '$class'";
}

sub import {
    my $class = shift;
    my @list = $_[0] =~ /^:all/ ? keys %ENV : @_;
    for my $pathvar (@list) {
	$class->new($pathvar);
    }
}

sub AUTOLOAD {
    my $class = shift;
    (my $pathvar = $Env::Path::AUTOLOAD) =~ s/.*:://;
    return if $pathvar eq 'DESTROY';
    $class->new($pathvar, @_);
}

sub _class2ref {
    my $proto = shift;
    ref $proto ? $proto : \$ENV{$proto};
}

sub PathSeparator {
    shift;
    $dsep = shift if @_;
    return $dsep;
}

sub Name {
    my $pathref = _class2ref(shift);
    for my $name (keys %ENV) {
	return $name if $pathref == \$ENV{$name};
    }
    return undef;
}

sub List {
    my $pathref = _class2ref(shift);
    return split /$dsep/, $$pathref;
}

sub Has {
    my $pathref = _class2ref(shift);
    my $entry = shift;
    my @list = $pathref->List;
    if (MSWIN) {
	for ($entry, @list) {
	    $_ = lc($_);
	    s%\\%/%g;
	}
    }
    my %has = map {$_ => 1} @list;
    return $has{$entry};
}

sub Assign {
    my $pathref = _class2ref(shift);
    $$pathref = join($dsep, @_);
    return $pathref;
}

sub Prepend {
    my $pathref = _class2ref(shift);
    $pathref->Remove(@_);
    $$pathref = $dsep.$$pathref if $$pathref;
    $$pathref = join($dsep, @_) . $$pathref;
    return $pathref;
}

sub Append {
    my $pathref = _class2ref(shift);
    $pathref->Remove(@_);
    $$pathref .= $dsep if $$pathref;
    $$pathref .= join($dsep, @_);
    return $pathref;
}

sub InsertBefore {
    my $pathref = _class2ref(shift);
    my $marker = shift;
    $pathref->Remove(@_);
    my $insert = join($dsep, map {split ','} @_);
    my $temp = $$pathref || '';
    $$pathref = '';
    for (split /$dsep/, $temp) {
	$_ ||= '.';
	$$pathref .= $dsep if $$pathref;
	if ($marker && $_ eq $marker) {
	    $$pathref .= $insert . $dsep;
	    undef $marker;
	}
	$$pathref .= $_;
    }
    if (defined $marker) {
	$$pathref = $$pathref ? "$insert$dsep$$pathref" : $insert;
    }
    return $pathref;
}

sub InsertAfter {
    my $pathref = _class2ref(shift);
    my $marker = shift;
    $pathref->Remove(@_);
    my $insert = join($dsep, map {split ','} @_);
    my $temp = $$pathref || '';
    $$pathref = '';
    for (split /$dsep/, $temp) {
	$_ ||= '.';
	$$pathref .= $dsep if $$pathref;
	$$pathref .= $_;
	if ($marker && $_ eq $marker) {
	    $$pathref .= $dsep . $insert;
	    undef $marker;
	}
    }
    if (defined $marker) {
	$$pathref = $$pathref ? "$$pathref$dsep$insert" : $insert;
    }
    return $pathref;
}

sub Remove {
    my $pathref = _class2ref(shift);
    return $pathref unless $$pathref;
    my %remove = map {$_ => 1} @_;
    $$pathref = join($dsep,
		grep {!$remove{$_}} map {$_ || '.'} split(/$dsep/, $$pathref));
    return $pathref;
}

sub Replace {
    my $pathref = _class2ref(shift);
    return $pathref unless $$pathref;
    my $re = shift;
    my @temp = split /$dsep/, $$pathref;
    for (@temp) {
	$_ ||= '.';
	if (/$re/) {
	    $_ = join($dsep, map {split ','} @_);
	}
    }
    $$pathref = join($dsep, @temp);
    return $pathref;
}

sub ListNonexistent {
    my $pathref = _class2ref(shift);
    return $pathref unless $$pathref;
    my @missing = ();
    for (split /$dsep/, $$pathref) {
	push(@missing, $_) if $_ && ! -e $_;
    }
    return @missing;
}

sub DeleteNonexistent {
    my $pathref = _class2ref(shift);
    return $pathref unless $$pathref;
    my $temp = $$pathref;
    $$pathref = '';
    for (split /$dsep/, $temp) {
	$_ ||= '.';
	next if ! -e $_;
	$$pathref .= $dsep if $$pathref;
	$$pathref .= $_;
    }
    return $pathref;
}

sub Uniqify {
    my $pathref = _class2ref(shift);
    my %seen;
    my $temp = $$pathref || '';
    $$pathref = '';
    for (split /$dsep/, $temp) {
	$_ ||= '.';
	my $entry = MSWIN ? lc($_) : $_;
	next if $seen{$entry}++;
	$$pathref .= $dsep if $$pathref;
	$$pathref .= $_;
    }
    return $pathref;
}

sub Whence {
    my $pathref = _class2ref(shift);
    my $pat = shift;
    my(@found, %seen);
    for my $dir (split /$dsep/, $$pathref) {
	$dir ||= '.';
	my $glob = join(MSWIN ? '\\' : '/', $dir, $pat);
	my @matches = MSWIN ? File::Glob::bsd_glob($glob) : glob($glob);
	push(@found, grep {-f $_ && -x _ && !$seen{$_}++} $glob, @matches);
    }
    return @found;
}

sub Shell {
    my $pathref = _class2ref(shift);
    my $name = $pathref->Name;
    my $winshell = MSWIN && !$ENV{SHELL};
    my $str = "set " if $winshell;
    $str .= qq($name="$$pathref");
    $str .= "; export $name" if !$winshell;
    return $str;
}

# Nothing to do here, just avoiding interaction with AUTOLOAD.
sub DESTROY { }

1;

__END__

=head1 NAME

Env::Path - Advanced operations on path variables

=head1 SYNOPSIS

  use Env::Path;

  # basic usage
  my $manpath = Env::Path->MANPATH;
  $manpath->Append('/opt/samba/man');
  for ($manpath->List) { print $_, "\n" };

  # similar to above using the "implicit object" shorthand
  Env::Path->MANPATH;
  MANPATH->Append('/opt/samba/man');
  for (MANPATH->List) { print $_, "\n" };

  # one-shot use
  Env::Path->PATH->Append('/usr/sbin');

  # change instances of /usr/local/bin to an architecture-specific dir
  Env::Path->PATH->Replace('/usr/local/bin', "/usr/local/$ENV{PLATFORM}/bin");

  # more complex use (different names for same semantics)
  my $libpath;
  if ($^O =~ /aix/) {
      $libpath = Env::Path->LIBPATH;
  } else {
      $libpath = Env::Path->LD_LIBRARY_PATH;
  }
  $libpath->Assign(qw(/usr/lib /usr/openwin/lib));
  $libpath->Prepend('/usr/ucblib') unless $libpath->Has('/usr/ucblib');
  $libpath->InsertAfter('/usr/ucblib', '/xx/yy/zz');
  $libpath->Uniqify;
  $libpath->DeleteNonexistent;
  $libpath->Remove('/usr/local/lib');
  print $libpath->Name, ":";
  for ($libpath->List) { print " $_" };
  print "\n";

  # simplest usage: bless all existing EV's as Env::Path objects
  use Env::Path ':all';
  my @cats = PATH->Whence('cat*');
  print "@cats\n";

=head1 DESCRIPTION

Env::Path presents an object-oriented interface to I<path variables>,
defined as that subclass of I<environment variables> which name an
ordered list of filesystem elements separated by a platform-standard
I<separator> (typically ':' on UNIX and ';' on Windows).

Of course, core Perl constructs such

  $ENV{PATH} .= ":/usr/local/bin";

will suffice for most uses. Env::Path is for the others; cases where
you need to insert or remove interior path entries, strip redundancies,
operate on a pathvar without having to know whether the current
platform uses ":" or ";", operate on a pathvar which may have a
different name on different platforms, etc.

This OO interface is slightly unusual in that the environment variable
is itself the object and the constructor is Env::Path->AUTOLOAD(); thus

    Env::Path->MANPATH;

would bless $ENV{MANPATH} into its package. C<$ENV{MANPATH}> is
otherwise unmodified with the exception of possible autovivification.
The only attribute the new object has is its pre-existing value.

Also, while the object reference may be assigned and used in the normal
style

    my $path = Env::Path->CLASSPATH;
    $path->Append('/opt/foo/classes.jar');

a shorthand is also available:

    Env::Path->CLASSPATH;
    CLASSPATH->Append('/opt/foo/classes.jar');

I.e. the name of the path variable may be used as a proxy for its
object reference. This may be done at 'use' time too:

    use Env::Path qw(PATH CLASSPATH);	# or qw(:all) to bless all EV's
    CLASSPATH->Append('/opt/foo/classes.jar');

=head2 CLASS METHODS

=over 4

=item * <CONSTRUCTOR>

The constructor may have any name; it's assumed to name a I<path
variable> as defined above. Returns the object reference.

=item * PathSeparator

Returns or sets the platform-specific path separator character, by
default I<:> on open platforms and I<;> on monopolistic ones.

=back

=head2 INSTANCE METHODS

Unless otherwise indicated these methods return the object reference,
allowing method calls to be strung together. All methods which take
lists join them together using the value of C<Env::Path-E<gt>PathSeparator>.

=over 4

=item * Name

Returns the name of the pathvar.

=item * Has

Returns true iff the specified entry is present in the pathvar.

=item * Assign

Takes a list and sets the pathvar to that value, separated by the
current PathSeparator.

=item * List

Returns the current path in list format.

=item * Prepend

For each entry in the supplied list, removes it from the pathvar if
present and prepends it, thus ensuring that it's present exactly once
and at the front.

=item * Append

Analogous to Prepend.

=item * InsertBefore

Takes a <dirname> and a list, inserts the list just before the first
instance of the <dirname>. If I<dirname> is not found, works just like
I<Prepend>. As with I<Prepend>, duplicates of the supplied entries are
removed.

=item * InsertAfter

Analogous to I<InsertBefore>

=item * Remove

Removes the specified entries from the path.

=item * Replace

Takes a /pattern/ and a list. Traverses the path and replaces all
entries which match the pattern with the concatenated list entries.

=item * ListNonexistent

Returns a list of all entries which do not exist as filesystem
entities.

=item * DeleteNonexistent

Removes from the path all entries which do not exist as filesystem
entities.

=item * Uniqify

Removes redundant entries (the 2nd through nth instances of each entry).

=item * Whence

Takes a pattern and returns an ordered list of all filenames found
along the path which match it and are executable.

=item * Shell

Returns a string suitable for passing to a shell which would set and export
the pathvar to its current value within the shell context.

=back

=head1 NOTES

=over 4

=item *

No provision is made for path variables which are not also environment
variables, a situation which is technically possible but quite rare.

=item *

Except where necessary no assumption is made that path entries should
be directories, because pathvars like CLASSPATH may contain "virtual
dirs" such as zip/jar files. For instance the I<DeleteNonexistent>
method does not remove entries which are files.  In Perl terms the test
applied is C<-e>, not C<-d>.

=item *

The shorthand notation for pathvar I<FOO> is implemented by hacking
I<@FOO::ISA>, so there's a slight risk of namespace collision if your
code also creates packages with all-upper-case names. No packages are
created unless the shorthand notation is employed.

=back

=head1 WORKS ON

UNIX and Windows.

=head1 AUTHOR

David Boyce <dsb@boyski.com>

=head1 COPYRIGHT

Copyright (c) 2000-2001 David Boyce. All rights reserved.  This Perl
program is free software; you may redistribute and/or modify it under
the same terms as Perl itself.

=head1 SEE ALSO

perl(1), perlobj(1), Env::Array(3)

=cut
