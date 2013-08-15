package Bio::EnsEMBL::DBLoader::RunnableDB::Grant;

use strict;
use warnings;

=pod

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

Bio::EnsEMBL::DBLoader::RunnableDB::Grant

=head1 DESCRIPTION

Package responsible for granting access to loaded databases. This prevents users
from accidentally querying a database before they are meant to (a common problem
when using global grants).

Allowed parameters are:

=over 8

=item database - The database to perform grants on

=item grant_user - The user to grant to. We only grant to % so socket based connections will not get the grant

=item target_db - HashRef of DBConnection compatible settings which are piped directly into a DBConnection->new() call

=back

=cut

use base qw/Bio::EnsEMBL::DBLoader::RunnableDB::Base Bio::EnsEMBL::DBLoader::RunnableDB::Database/;

sub param_defaults {
	return {
		grant_user => 'anonymous',
	};
}

sub fetch_input {
	my ($self) = @_;
	$self->throw('No database given') unless $self->database();
	$self->throw('No grant_user given') unless $self->param('grant_user');
	return;
}

sub run {
	my ($self) = @_;
	my $grant_template = q{GRANT SELECT, EXECUTE ON `%s`.* TO '%s'@'%%'};
	my $database = $self->database();
	my $grant_user = $self->param('grant_user');
	my $ddl = sprintf($grant_template, $database, $grant_user);
	$self->warning($ddl);
	$self->param('ddl', $ddl);
	return;
}

sub write_output {
	my ($self) = @_;
	$self->target_dbc()->do($self->param('ddl'));
	$self->target_dbc()->do('flush privileges');
	return;
}

1;