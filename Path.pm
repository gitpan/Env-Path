package Env::Path;

$VERSION = '0.04';

require 5.004;
use strict;

use constant MSWIN => $^O =~ /MSWin32|Windows_NT/i;

my $dsep = MSWIN ? ';' : ':';

sub AUTOLOAD {
    my $class = shift;
    (my $pathvar = $Env::Path::AUTOLOAD) =~ s/.*:://;
    return if $pathvar eq 'DESTROY';
    my $pathref = \$ENV{$pathvar};
    bless $pathref, $class;
    $pathref->Assign(@_) if @_;
    return $pathref if defined wantarray;
    eval "\@$pathvar\::ISA = '$class'";
}

sub new {
    my $class = shift;
    my $var = shift;
    return $class->$var(@_);
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
    my $insert = join($dsep, @_);
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
    my $insert = join($dsep, @_);
    my $temp = $$pathref || '';
    $$pathref = '';
    for (split /$dsep/, $temp) {
	$_ ||= '.';
	$$pathref .= $dsep if $$pathref;
	$$pathref .= $_;
	if ($marker && $_ eq $marker) {
	    $$pathref .= join($dsep, '', @_);
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
    my %remove = map {$_ => 1} @_;
    $$pathref = join($dsep,
		grep {!$remove{$_}} map {$_ || '.'} split(/$dsep/, $$pathref));
    return $pathref;
}

sub DeleteNonexistent {
    my $pathref = _class2ref(shift);
    my $temp = $$pathref || '';
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
    my $patt = shift;
    my @found;
    for my $dir (split /$dsep/, $$pathref) {
	$dir ||= '.';
	for (sort glob("$dir/$patt")) {
	    push(@found, $_) if -f $_ && -x _;
	}
    }
    return @found;
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

  # more complex use
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

  Env::Path->PATH;
  my @places = PATH->Whence('foo*');
  print "@places\n";

=head1 DESCRIPTION

Env::Path presents an object-oriented interface to I<path variables>,
defined as that subclass of I<environment variables> which name an
ordered list of filesystem elements separated by a platform-standard
I<separator> (typically ':' on UNIX and ';' on Windows).

Of course, core Perl constructs such

  $ENV{PATH} .= ":/usr/local/bin";

will suffice for most uses; Env::Path is for the others. Cases where
you need to insert or remove interior path entries, strip redundancies,
operate on a pathvar without having to know whether the current
platform uses ":" or ";", operate on a pathvar which may have a
different name on different platforms, etc.

The OO interface is slightly unusual in that the environment variable
is itself the object, and the constructor is Env::Path->AUTOLOAD(); thus

    Env::Path->XXXPATH;

blesses $ENV{XXXPATH} into its package. C<$ENV{XXXPATH}> is otherwise
unmodified (except for being autovivified if necessary). The only
attribute the object has is the path value, and that it had already.

Also, while the object reference may be assigned and used in the normal
style:

    my $path = Env::Path->CLASSPATH;
    $path->Append('/opt/foo/classes.jar');

a shorthand is also available:

    Env::Path->CLASSPATH;
    CLASSPATH->Append('/opt/foo/classes.jar');

I.e. the name of the path variable may be used as a proxy for its
object reference.

=head2 CLASS METHODS

=over 4

=item * <Constructor>

The constructor may have any name; it's assumed to name a I<path
variable> as defined above. Returns the object reference.

=item * PathSeparator

Returns or sets the platform-specific path separator character, by
default I<:> on open platforms and I<;> on monopolistic ones.

=back

=head2 INSTANCE METHODS

Unless otherwise indicated these methods return the object reference,
allowing method calls to be strung together. All methods which take
lists join them together using the value of C<Env::Path->PathSeparator>.

=over 4

=item * Name

Returns the name of the pathvar.

=item * Has

Returns true iff the specified entry is currently present in the path.

=item * Assign

Takes a list and sets the pathvar to that value.

=item * List

Returns the current path in list format.

=item * Prepend

For each entry in the supplied list, removes it from the pathvar if
present. Then prepends all supplied entries to the pathvar.

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

=item * DeleteNonexistent

Removes from the path all entries which do not exist as filesystem
entities.

=item * Uniqify

Removes redundant entries (the 2nd through nth instances of each entry).

=item * Whence

Takes a pattern and returns an ordered list of all filenames found
along the path which match it and are executable.

=back

=head1 NOTES

=over 4

=item *

No provision is made for path variables which are not also environment
variables, a situation which is technically possible but very rare.

=item *

Except where necessary, no assumption is made that path entries must be
directories. This is because pathvars like CLASSPATH may contain
"virtual dirs" such as zip/jar files. For instance the
I<DeleteNonexistent> method does not remove entries which are files.
In Perl terms the test applied is C<-e>, not C<-d>.

=item *

The shorthand notation for pathvar I<FOO> is implemented by defining
I<@FOO::ISA>, so there's a slight risk of namespace collision if your
code also creates packages with all-upper-case names. No packages are
defined unless the shorthand notation is employed.

=back

=head1 AUTHOR

David Boyce <dsb@world.std.com>

=head1 COPYRIGHT

Copyright (c) 2000 David Boyce. All rights reserved.  This Perl
program is free software; you may redistribute and/or modify it under
the same terms as Perl itself.

=head1 SEE ALSO

perl(1), perlobj(1), "perldoc Env::Array"

=cut
