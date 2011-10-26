#!/usr/bin/env perl

package Script;

use strict;
use warnings;

use Bio::EnsEMBL::DBSQL::DBConnection;
use Bio::EnsEMBL::Utils::Exception qw/throw warning/;
use Bio::EnsEMBL::Utils::Scalar qw/:assert wrap_array/;
use Bio::EnsEMBL::DBDumper;
use Getopt::Long;
use Pod::Usage;

sub run {
  my ($class) = @_;
  my $self = bless({}, $class);
  $self->args();
  $self->check();
  $self->defaults();
  $self->process();
  return;
}

sub args {
  my ($self) = @_;
  my $opts = {};
  GetOptions($opts, qw/
    host=s
    port=i
    username=s
    password=s
    pattern=s
    databases=s@
    directory=s
    verbose
    help
    man
  /) or pod2usage(-verbose => 1, -exitval => 1);
  pod2usage(-verbose => 1, -exitval => 0) if $opts->{help};
  pod2usage(-verbose => 2, -exitval => 0) if $opts->{man};
  $self->{opts} = $opts;
  return;
}

sub check {
  my ($self) = @_;
  
  my $opts = $self->opts();
  
  my @requireds = qw/host port username directory/;
  foreach my $r (@requireds) {
    if($opts->{$r}) {
      print STDERR "-${r} has not been given at the command line but is a required parameter\n";
      pod2usage(-verbose => 1, -exitval => 1);
    }
  }
    
  if($opts->{pattern} && $opts->{databases}) {
    print STDERR "-pattern and -databases are mututally exclusive but have both been given at the command line\n";
    pod2usage(-verbose => 1, -exitval => 1);
  }
  
  return;
}

sub defaults {
  my ($self) = @_;
  
  my $opts = $self->opts();
  
  #Port
  $opts->{port} = 3306 if ! $opts->{port};
  $self->v(q{Connecting to %s@%s:%d}, map { $opts->{$_} } qw/username host port/);
  
  #DBs
  my $dbc = $self->dbc();
  if( $opts->{databases}) {
    $opts->{databases} = wrap_array($opts->{databases});
  }
  else {
    my $pattern = $opts->{pattern};
    $self->v('Using pattern %s', $pattern);
    my $databases = $dbc->sql_helper()->execute_simple(
      -SQL => 'show databases like ?',
      -PARAMS => [$opts->{pattern}]
    );
    $opts->{databases} = $databases;
  }
  $self->v(q{Found %d database(s) to process}, scalar(@{$opts->{databases}}));
  $dbc->disconnect_if_idle();
  
  return;
}

sub process {
  my ($self) = @_;
  my $databases = $self->opts()->{databases};
  foreach my $db (@{$databases}) {
    $self->v('Working with database %s', $db);
    my $dumper = Bio::EnsEMBL::DBDumper->new(
      -DBC => $self->dbc($db), -DIR => $self->opts()->{directory}
    );
    $dumper->run();
    $self->v('Finished with database %s', $db);
  }
  return;
}

sub dbc {
  my ($self, $dbname) = @_;
  my $opts = $self->{opts};
  my %args = (
    -HOST => $opts->{host},
    -PORT => $opts->{port},
    -USER => $opts->{username},
    -RECONNECT_WHEN_CONNECTION_LOST => 1,
    -DISCONNECT_WHEN_INACTIVE => 1,
    -DRIVER => 'mysql'
  );
  $args{-DBNAME} = $dbname if $dbname;
  $args{-PASS} = $opts->{password} if $opts->{password};
  return Bio::EnsEMBL::DBSQL::DBConnection->new(%args);
}

sub opts {
  my ($self) = @_;
  return $self->{'opts'};
}

sub v {
  my ($self, $msg, @args) = @_;
  return unless $self->opts()->{verbose};
  print sprintf($msg, @args), "\n";
  return;
}

Script->run();

1;
__END__

=pod

=head1 NAME

dump_mysql.pl

=head1 SYNOPSIS

  ./dump_mysql.pl --host HOST [--port PORT] --username USER [--password PASS] [-pattern '%' | -databases DB] -directory DIR [-help | -man]

=head1 DESCRIPTION

A script which is used to generate MySQL dumps which take into account issues
surrounding BLOB handling, VIEWS and other oddities of the Ensembl MySQL dump
process.

=head1 OPTIONS

=over 8

=item B<--host>

Host name of the database to connect to

=item B<--port>

Optional integer of the database port. Defaults to 3306.

=item B<--username>

Username of the connecting account. Must be able to perform 
C<SELECT INTO OUTFILE> calls.

=item B<--password>

Optional password of the connecting user

=item B<--pattern>

Allows the specification of a LIKE pattern to select databases with. Cannot
be used in conjunction with the C<--databases> argument. 

=item B<--databases>

Allows database name specification and can be used more than once. Cannot
be used in conjunction with C<--pattern>.

=item B<--directory>

Target directory to place all dumps. A sub-directory will be created here;
one per database dump.

=item B<--verbose>

Makes the program give more information about what is going on. Otherwise
the program is silent.

=item B<--help>

Help message

=item B<--man>

Man page

=back