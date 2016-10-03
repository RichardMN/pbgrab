#!/usr/bin/perl -w
# Wrapper to PBGrab.pm
#

use Getopt::Long qw(GetOptions);
use PBGrab;
use Data::Dumper;

$pbaselogin = "";
$pbasepassword = "";
$pbasegallery = "";
$pbasedownloaddir = "";
$pbasedebug = "";
$proxydetails = "";
$striphtml = 0;
$nested = 1;
$printversion = 0;

GetOptions(
  'u|username=s' => \$pbaselogin,
  'p|password=s' => \$pbasepassword,
  'g|gallery=s' => \$pbasegallery,
  'r|root=s' => \$pbasedownloaddir,
  'd|debug' => \$PBGrab::show_dbg,
  's|striphtml' => \$striphtml,
  'proxy=s' => \$proxydetails,
  'v' => \$printversion
) or die PBGrab::usage();

$printversion && die PBGrab::dispversion();

PBGrab::pbgrab($pbaselogin,
  $pbasepassword,
  $pbasegallery,
  $pbasedownloaddir,
  $pbasedebug,
  $striphtml,
  $nested);
