#! /usr/bin/perl -w -I ..
#
# Simple Network Management Protocol (SNMP) Test via check_snmp
#
#

use strict;
use Test::More;
use NPTest;

my $tests = 32;
plan tests => $tests;
my $res;

SKIP: {
	skip "check_snmp is not compiled", $tests if ( ! -x "./check_snmp" );

	my $host_snmp = getTestParameter( "host_snmp",          "NP_HOST_SNMP",      "localhost",
	                                   "A host providing an SNMP Service");

	my $snmp_community = getTestParameter( "snmp_community",     "NP_SNMP_COMMUNITY", "public",
                                           "The SNMP Community string for SNMP Testing (assumes snmp v1)" );

	my $host_nonresponsive = getTestParameter( "host_nonresponsive", "NP_HOST_NONRESPONSIVE", "10.0.0.1",
	                                           "The hostname of system not responsive to network requests" );

	my $hostname_invalid   = getTestParameter( "hostname_invalid",   "NP_HOSTNAME_INVALID",   "nosuchhost",
	                                           "An invalid (not known to DNS) hostname" );

	$res = NPTest->testCmd( "./check_snmp -t 1" );
	is( $res->return_code, 3, "No host name" );
	is( $res->output, "No host specified" );
	
	$res = NPTest->testCmd( "./check_snmp -H fakehostname" );
	is( $res->return_code, 3, "No OIDs specified" );
	is( $res->output, "No OIDs specified" );

	$res = NPTest->testCmd( "./check_snmp -H fakehost -o oids -P 3 --seclevel=rubbish" );
	is( $res->return_code, 3, "Invalid seclevel" );
	like( $res->output, "/check_snmp: Invalid seclevel - rubbish/" );

	$res = NPTest->testCmd( "./check_snmp -H fakehost -o oids -P 3c" );
	is( $res->return_code, 3, "Invalid protocol" );
	like( $res->output, "/check_snmp: Invalid SNMP version - 3c/" );

	SKIP: {
		skip "no snmp host defined", 20 if ( ! $host_snmp );

		$res = NPTest->testCmd( "./check_snmp -H $host_snmp -C $snmp_community -o system.sysUpTime.0 -w 1: -c 1:");
		cmp_ok( $res->return_code, '==', 0, "Exit OK when querying uptime" ); 
		like($res->output, '/^SNMP OK - (\d+)/', "String contains SNMP OK");
		$res->output =~ /^SNMP OK - (\d+)/;
		my $value = $1;
		cmp_ok( $value, ">", 0, "Got a time value" );
		like($res->perf_output, "/sysUpTime.*$1/", "Got perfdata with value '$1' in it");

		$res = NPTest->testCmd( "./check_snmp -H $host_snmp -C $snmp_community -o system.sysDescr.0");
		cmp_ok( $res->return_code, '==', 0, "Exit OK when querying sysDescr" ); 
		unlike($res->perf_output, '/sysDescr/', "Perfdata doesn't contain string values");

		$res = NPTest->testCmd( "./check_snmp -H $host_snmp -C $snmp_community -o host.hrSWRun.hrSWRunTable.hrSWRunEntry.hrSWRunIndex.1 -w 1:1 -c 1:1");
		cmp_ok( $res->return_code, '==', 0, "Exit OK when querying hrSWRunIndex.1" ); 
		like($res->output, '/^SNMP OK - 1\s.*$/', "String fits SNMP OK and output format");

		$res = NPTest->testCmd( "./check_snmp -H $host_snmp -C $snmp_community -o host.hrSWRun.hrSWRunTable.hrSWRunEntry.hrSWRunIndex.1 -w 0   -c 1:");
		cmp_ok( $res->return_code, '==', 1, "Exit WARNING when querying hrSWRunIndex.1 and warn-th doesn't apply " ); 
		like($res->output, '/^SNMP WARNING - \*1\*\s.*$/', "String matches SNMP WARNING and output format");

		$res = NPTest->testCmd( "./check_snmp -H $host_snmp -C $snmp_community -o host.hrSWRun.hrSWRunTable.hrSWRunEntry.hrSWRunIndex.1 -w  :0 -c 0");
		cmp_ok( $res->return_code, '==', 2, "Exit CRITICAL when querying hrSWRunIndex.1 and crit-th doesn't apply" ); 
		like($res->output, '/^SNMP CRITICAL - \*1\*\s.*$/', "String matches SNMP CRITICAL and output format");

		$res = NPTest->testCmd( "./check_snmp -H $host_snmp -C $snmp_community -o ifIndex.2,ifIndex.1 -w 1:2 -c 1:2");
		cmp_ok( $res->return_code, '==', 0, "Checking two OIDs at once" );
		like($res->output, "/^SNMP OK - 2 1/", "Got two values back" );
		like( $res->perf_output, "/ifIndex.2=2/", "Got 1st perf data" );
		like( $res->perf_output, "/ifIndex.1=1/", "Got 2nd perf data" );

		$res = NPTest->testCmd( "./check_snmp -H $host_snmp -C $snmp_community -o ifIndex.2,ifIndex.1 -w 1:2,1:2 -c 2:2,2:2");
		cmp_ok( $res->return_code, '==', 2, "Checking critical threshold is passed if any one value crosses" );
		like($res->output, "/^SNMP CRITICAL - 2 *1*/", "Got two values back" );
		like( $res->perf_output, "/ifIndex.2=2/", "Got 1st perf data" );
		like( $res->perf_output, "/ifIndex.1=1/", "Got 2nd perf data" );
	}

	SKIP: {
		skip "no non responsive host defined", 2 if ( ! $host_nonresponsive );
		$res = NPTest->testCmd( "./check_snmp -H $host_nonresponsive -C $snmp_community -o system.sysUpTime.0 -w 1: -c 1:");
		cmp_ok( $res->return_code, '==', 3, "Exit UNKNOWN with non responsive host" ); 
		like($res->output, '/External command error: Timeout: No Response from /', "String matches timeout problem");
	}

	SKIP: {
		skip "no non invalid host defined", 2 if ( ! $hostname_invalid );
		$res = NPTest->testCmd( "./check_snmp -H $hostname_invalid   -C $snmp_community -o system.sysUpTime.0 -w 1: -c 1:");
		cmp_ok( $res->return_code, '==', 3, "Exit UNKNOWN with non responsive host" ); 
		like($res->output, '/External command error: .*nosuchhost/', "String matches invalid host");
	}

}
