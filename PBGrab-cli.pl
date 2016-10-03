#!/usr/bin/perl -w
# ---------------------------------------------------------------
#	======== Pbase Album Grabber Command-Line Interface ================
#		- Arjun Roychowdury
#
# License: http://creativecommons.org/licenses/by-nc-sa/3.0/
#
# Modified for CLI use by Richard Martin-Nielsen in September 2016.
# Released as version 1.6 with the same license derivative work.
#
# --------------------------------------------------------------------

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
