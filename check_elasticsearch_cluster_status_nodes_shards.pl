#!/usr/bin/perl -T
# nagios: -epn
#
#  Author: Hari Sekhon
#  Date: 2013-06-03 21:43:25 +0100 (Mon, 03 Jun 2013) 
#
#  http://github.com/harisekhon/nagios-plugins
#
#  License: see accompanying LICENSE file
#

$DESCRIPTION = "Nagios Plugin to check Elasticsearch cluster status, nodes and shards

Optional thresholds apply to all counts of nodes, data nodes, active primary shards, active shards, relocating shards, initializing shards and unassigned shards in <warning>,<critical> format where each threshold can take a standard Nagios ra:nge

See the adjacent individual plugins listed below which are more concisely checking each of these things... I would remove this plugin but it was already written and some people may prefer to be able to do all of this in one check:

check_elasticsearch_cluster_status.pl
check_elasticsearch_nodes.pl
check_elasticsearch_data_nodes.pl
check_elasticsearch_cluster_shards.pl

Tested on Elasticsearch 0.90.1, 1.2.1, 1.4.4";

$VERSION = "0.2";

use strict;
use warnings;
BEGIN {
    use File::Basename;
    use lib dirname(__FILE__) . "/lib";
}
use HariSekhonUtils;
use HariSekhon::ElasticSearch;

$ua->agent("Hari Sekhon $progname version $main::VERSION");

my $cluster;
my $node_thresholds;
my $data_node_thresholds;
my $active_primary_shard_thresholds;
my $active_shard_thresholds;
my $relocating_shard_thresholds;
my $initializing_shard_thresholds;
my $unassigned_shard_thresholds = "0,1";

%options = (
    %hostoptions,
    "C|cluster-name=s"          =>  [ \$cluster,                            "Cluster name to expect (optional). Cluster name is used for auto-discovery and should be unique to each cluster in a single network" ],
    "n|nodes=s"                 =>  [ \$node_thresholds,                    "Node thresholds (inclusive, optional)" ],
    "d|data-nodes=s"            =>  [ \$data_node_thresholds,               "Data Node thresholds (inclusive, optional)" ],
    "active-primary-shards=s"   =>  [ \$active_primary_shard_thresholds,    "Active Primary Shards thresholds (inclusive, optional)" ],
    "active-shards=s"           =>  [ \$active_shard_thresholds,            "Active Shards thresholds (inclusive, optional)" ],
    "relocating-shards=s"       =>  [ \$relocating_shard_thresholds,        "Relocating Shards thresholds (inclusive, optional)" ],
    "initializing-shards=s"     =>  [ \$initializing_shard_thresholds,      "Initializing Shards thresholds (inclusive, optional)" ],
    "unassigned-shards=s"       =>  [ \$unassigned_shard_thresholds,        "Unassigned Shards thresholds (inclusive, default w,c: 0,1)" ],
);
splice @usage_order, 6, 0, qw/cluster-name nodes data-nodes active-primary-shards active-shards relocating-shards initializing-shards unassigned-shards/;

get_options();

$host = validate_host($host);
$port = validate_port($port);
$cluster = validate_elasticsearch_cluster($cluster) if defined($cluster);
my $options_upper = { "simple" => "upper", "integer" => 1, "positive" => 1 };
my $options_lower = { "simple" => "lower", "integer" => 1, "positive" => 1 };
validate_thresholds(undef, undef, $options_lower, "nodes",                  $node_thresholds);
validate_thresholds(undef, undef, $options_lower, "data nodes",             $data_node_thresholds);
validate_thresholds(undef, undef, $options_upper, "active primary shards",  $active_primary_shard_thresholds);
validate_thresholds(undef, undef, $options_upper, "active shards",          $active_shard_thresholds);
validate_thresholds(undef, undef, $options_upper, "relocating shards",      $relocating_shard_thresholds);
validate_thresholds(undef, undef, $options_upper, "initializing shards",    $initializing_shard_thresholds);
validate_thresholds(undef,     1, $options_upper, "unassigned shards",      $unassigned_shard_thresholds);

vlog2;
set_timeout();

$status = "OK";

$json = curl_elasticsearch "/_cluster/health";

my $cluster_name = get_field("cluster_name");
$msg .= "cluster name: '$cluster_name'";
check_string($cluster_name, $cluster);

$msg .= check_elasticsearch_status(get_field("status"));

my $nodes = get_field_int("number_of_nodes");
$msg .= ", nodes: $nodes";
check_thresholds($nodes, 0, "nodes");

my $data_nodes = get_field_int("number_of_data_nodes");
$msg .= ", data nodes: $data_nodes";
check_thresholds($data_nodes, 0, "data nodes");

my $active_primary_shards = get_field_int("active_primary_shards");
$msg .= ", active primary shards: $active_primary_shards";
check_thresholds($active_primary_shards, 0, "active primary shards");

my $active_shards = get_field_int("active_shards");
$msg .= ", active shards: $active_shards";
check_thresholds($active_shards, 0, "active shards");

my $relocating_shards = get_field_int("relocating_shards");
$msg .= ", relocating shards: $relocating_shards";
check_thresholds($relocating_shards, 0, "relocating shards");

my $initializing_shards = get_field_int("initializing_shards");
$msg .= ", inititializing shards: $initializing_shards";
check_thresholds($initializing_shards, 0, "initializing shards");

my $unassigned_shards = get_field_int("unassigned_shards");
$msg .= ", unassigned shards: $unassigned_shards";
check_thresholds($unassigned_shards, 0, "unassigned shards");

my $timed_out = get_field("timed_out");
#$timed_out = ( $timed_out ? "true" : "false" );
if($timed_out){
    critical;
    $msg .= ", TIMED OUT: TRUE";
    #check_string($timed_out, "false");
}

vlog2;
quit $status, $msg;