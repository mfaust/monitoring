#!/usr/bin/perl 
#===============================================================================
#
#         FILE:  check_ldap_request.pl
#
#        USAGE:  ./check_ldap_request.pl -H hostname -b base -f filer [-s scope] [-h]
#
#  DESCRIPTION:  Nagios Plugin - Check if LDAP attribute exist
#
#      OPTIONS:  ---
# REQUIREMENTS:  Net::LDAP Perl library
#         BUGS:  ---
#        NOTES:  ---
#      LICENSE:  This Nagios module is under GPLv2 License
#       AUTHOR:  Pierre Mavro (), pierre@mavro.fr
#      COMPANY:  
#      VERSION:  1.0
#      CREATED:  09/12/2009 15:38:41
#     REVISION:  ---
#===============================================================================

use strict;
use warnings;
use Getopt::Long;
use Net::LDAP;

# Make an LDAP request
sub make_ldap_request
{
	my $hostname=shift;
	my $base=shift;
	my $filter=shift;
	my $scope=shift;	

	my $ldap=Net::LDAP->new("ldaps://$hostname") or die("Connection to $hostname could not be established : $@ - $!");

	my $mesg=$ldap->bind();
	
	$mesg=$ldap->search(base  =>$base,
          	            scope =>"$scope",
              	        filter=>"($filter)");
	$mesg->code && die $mesg->error;
	
	if($mesg->count()) {
		$ldap->unbind();
		print "LDAP request OK - \'$filter\' exists\n";
		exit(0);
	}
	else
	{
		$ldap->unbind();
		print "LDAP request CRITICAL - unable to find \'$filter\'\n";
		exit(2);
	}
} 

# Help print
sub help
{
    print "Usage : check_ldap_request.pl -H hostname -b base -f filer [-s scope] [-h]\n";
    print "\t-H : LDAP server hostname or IP\n";
    print "\t-b : Base of LDAP server (ex: \"dc=ldap,dc=company,dc=lan\")\n";
    print "\t-f : Specify a filter (ex: \"uid=pmavro\")\n";
    print "\t-s : LDAP Scope (ex: sub)\n";
    print "\t-h : Print this help message\n";
    exit(1);
}

sub check_opts
{
	# Vars
	my ($hostname,$base,$filter);
	my $scope='sub';
	
	# Set options
	GetOptions( "help|h"    => \&help,
				"H=s"       => \$hostname,
				"b=s"		=> \$base,
				"f=s"		=> \$filter,
				"s=s"		=> \$scope);
				
	unless (($hostname) and ($base) and ($filter))
	{
		&help;
	}
	else
	{
		&make_ldap_request($hostname,$base,$filter,$scope);
	}
}

&check_opts;
