#!/usr/bin/perl -w
# ---------------------------------------------------------------
#	======== Pbase Album Grabber =====================
#	A program to download galleries to your local
#	disk. PLEASE use this program sparingly - its a
#	bandwidth hog.
#
#		- Arjun Roychowdury
#
#
# License: http://www.gnu.org/licenses/gpl-3.0.html
#
# Modified for CLI use by Richard Martin-Nielsen in September 2016.
# Released as version 1.6 with the same license derivative work.
#
# --------------------------------------------------------------------

#
# packages you need to have
# if perl complains about missing packages, see the readme
# on how to install some of them
#

package PBGrab;
use Exporter;
our @ISA=qw( Exporter );
our @EXPORT_OK=qw (pbgrab);
our @EXPORT=qw (pbgrab);


use LWP::Simple;
use LWP::UserAgent;
use Getopt::Long;
use XML::TreeBuilder;
use HTML::TreeBuilder;
use HTTP::Cookies;
use URI::Escape;
use URI::http;
use File::Find;
use File::Slurp;
use File::Basename;
use GD;
use URI;
use Encode::Byte; # needed by pp or it croaks about encoding not supported
use Cwd;
use Data::Dumper;
#use Crypt::SSLeay;

$curdir='';
$user        = 'richardmartin';    # the pbase username
$interactive = 1;     # if enabled, will ask for password to login
$show_dbg    = 1;     # if enabled, prints verbose message
$http_proxy  = '';    # if you browse using a proxy
$secure      = '';    # if you want HTTPS login
$proxy_user  = '';    # If your proxy needs authentication
$proxy_pwd   = '';    # if your proxy needs authentication
$root_path   = '';    # Will hold the base directory where to download
$user_gal    = '';    # will hold name of a specific gallery to download, if so desired
$strip_html  = '';    # if 1, it will remove HTML tags from captions
$pb_repeat = 3;    # number of times to try before I decide an image is broken
$base         = 'http://www.pbase.com';
$secure_base  = 'https://secure.pbase.com';
$img_href     = '';
$gal_href     = '';
$corrupt_size = 948;                          # the size of "creating thumbnail"
$dlink_disabled = 637;			      # size of direct linking disabled
$pass_protected = 1543;			      # size of password protected

$cookie_jar='';


@progress=("|","/","-","\\");
$progress_cnt=0;

#---------------------------------------------------------
# Version
#---------------------------------------------------------
sub getversion {
    return ("1.6");
}

sub dispversion {
    print( "\nPbgrab version ", getversion(), "\n" );
}

sub printprogress
{
		# no need to print progress if debug is on screen
		return if ($show_dbg && !$show_dbg_fn);
		print(".");
}

sub myexit
{
	#$mw->update();
	close (DBG_FH);
	#print ("\nPress any key to exit...");
	#ReadLine(0);
	print ("\nThanks & Bye\n");
	print_dbg("Inside myexit");
	chdir($origdir);
}

#---------------------------------------------------------
# Credits
# --------------------------------------------------------
sub credits {
	print ("\nThanks to Irv Cobb, Tom Byron for being good beta-testers\n");
}

#---------------------------------------------------------
# Usage Help
#---------------------------------------------------------
sub usage {

    dispversion();
    print "(c) Arjun Roychowdhury\n\n";
    print <<EOM;

	usage: pbgrab -u username <options>

            Options:
              -h:            displays this help and exits
     ........................................................................
              -v:            displays version and exits
     ........................................................................
              -u:            username
     ........................................................................
              -i:            Ask for pbase password (browser independent)
     ........................................................................
              -d <file>:     Display verbose information. If a filename is
	      		     specified, then the debug output will be written
			     to that file, else the screen
     ........................................................................
     -gallery name:          Only downloads images from specified gallery
     .........................................................................
     -root name:	     Archives images to specified directory name.
                             If not provided, creates a directory of format
                             pbgrab_mm_dd_yy_hr_min
     .........................................................................
     -striphtml:	     If specified, will remove HTML tags from the
     			     PBase captions. If you want to preserve funky
			     html including PBase paypal shopping carts, don't
			     add this
     .........................................................................
     -proxy proxydetails:    routes all messages through a proxy
                             (example -proxy myproxy.foo.com:8000 if proxy
                             needs authentication)
                             (or -proxy user:passwd\@myproxy.foo.com:8000)

     .........................................................................
EOM
}

sub mydie
{
	print "\nSERIOUS ERROR::",@_,"\n";
	print_dbg("Inside mydie");
	myexit();
	return;
}

#---------------------------------------------------------
# verbose printing
#---------------------------------------------------------
sub print_dbg {
    #print DBG_FH "PBgrab-VERBOSE:", @_, "\r\n" if ($show_dbg);
		print "PBgrab-VERBOSE:", @_, "\r\n" if ($show_dbg);
    #$mw->update();

}

sub flush_print {
    print @_;
    select(STDOUT);
    $| = 1;
}


#---------------------------------------------------------
# Remind the user
#---------------------------------------------------------
sub print_credit {
    $pbver = getversion();
    print "\n----------------------------------------\n";
    print " PBgrab - Pbase Gallery Grabber v$pbver\n";
    print "\n";
    print "(c) Arjun Roychowdhury.\n";
    print "\n";
    credits();
    print "------------------------------------------\n\n";
    select(STDOUT);
    $| = 1;
}

#---------------------------------------------------------
# Ensure cookie support
#---------------------------------------------------------
sub link_cookies {

    print_dbg("Inside link_cookies");
    if ( $interactive || $password ) {

        # We automatically fill the pbase form to login the user
        use WWW::Mechanize;
        use Term::ReadKey;

        # I have removed secure login - if you are using secure with source code
        # please uncomment this line and comment out the next

        #eval "use Crypt::SSLeay";
        $secure = 0;    # comment this line if you want secure login
        $cookie_jar = HTTP::Cookies->new();
        $mech       = WWW::Mechanize->new();
        $mech->cookie_jar($cookie_jar);
        if ($http_proxy) {
            $mech->proxy( 'http' => $http_proxy );
            print_dbg("Mechanize:Using proxy $http_proxy for all operations");
        }
        if ( !$password ) {
            print "\nPlease enter Pbase password for $user:";
            ReadMode('noecho');
            $password = ReadLine(0);
            ReadMode('restore');
            chomp($password);
        }
        print "\n";
        select(STDOUT);
        $|         = 1;
        $login_url = "$base/logout";
        print "Please wait....\n";
        print_dbg("Attempting to login to pbase site with cookies");
	print_dbg("Contacting PBase, if this takes long, or gets stuck, blame PBase :)");
	print_dbg("login url is $login_url");
        $resp = $mech->get($login_url);

        if ( !$resp->is_success )

          # this will usually happen incase it cannot retrieve the login page
        {
            print_dbg( $resp->error_as_HTML );
            print "\nError logging into pbase.";
            print "If you are using the -proxy option\n";
            print "please make sure the proxy value is correct.\n";
            print
              "If you are using a personal firewall, you should use -proxy\n";
            myexit(); return;
        }
        my %data = (
            login_id => $user,
            password => $password,
        );
        $mech->set_fields(%data);
        $mech->click('submit');
        print_dbg("Submitted the form - hope you gave the right password");
        select(STDOUT);
        $| = 1;
    }
}

#---------------------------------------------------------
# Make a sincere attempt to download the image
#---------------------------------------------------------
sub tryanddownload {
    #$mw->update();
    my $iurl   = shift;
    my $method = shift;
    my $fn=shift;
    my $downloadcaption=shift;
    my $output_title=shift;
    my $output_date=shift;
    my $isvideo=shift;
    my $ct=shift;

    $origurl=$iurl;
    $capfile="captions\/".$fn.".txt";
    $thumb_fn="thumbs\/thumb_".$fn.".jpg";
    $fn="images\/".$fn.".jpg";

    $datefile="dates\/".$imgcnt.".txt";
    print_dbg("Creating date file $datefile\n");
    open (DTFILE, ">$datefile") || die $!;
		print DTFILE $output_date if defined($output_date);
    close (DTFILE);

    $rpt_cnt  = 1;
    $ret_code = 1;
    $caplink="";

    # The final frontier !
    # If I cannot download the direct link image, I get the image HTML page,
    # extract the embedded URI and download that.

    if (   $method eq "DESPERATE"
        || $method eq "FINALFRONTIER" )    # html indirection
    {
	print_dbg("virtual URL passed to tryanddownload: $iurl");
        eval {
            my $g_tree = HTML::TreeBuilder->new;
	    if ($iurl)
	    {
            $resp   = $browser->get($iurl);
            $g_page = $resp->content;
            $g_tree->parse($g_page);
            my $link = $g_tree->look_down(
                _tag  => 'div',
                id    => 'image',
                class => 'image'
            );


            $link = $link->look_down( _tag => 'table' );

 	    $link = $link->look_down( _tag => 'tr' );
            $link = $link->look_down( _tag => 'td' );
            $link = $link->look_down( _tag => 'a' );
            $link = $link->look_down( _tag => 'img', class => 'display' );
            $link = $link->attr('src');
            $iurl = $link;
            print_dbg("Real link for download: $iurl");
	    }
	    # did you want the caption ?
	    if ($downloadcaption)
	    {
		    if ($origurl)
		    {
   		         $caption=$g_tree->look_down(_tag=>'div', id=>'imagecaption', class=>'imagecaption');
		   	 $caplink=$caption->as_HTML if (defined($caption));
			 $caplink=$caption->as_text if (($strip_html) && (defined($1)));
		    }
		    else {$caplink=$ct;} # if its a video in a pblog
		    print_dbg ("CAPTION:$caplink");
		    if ($caplink)
		    {
		   	 print_dbg ("\nwriting caption to $capfile\n");
		   	 open(CAPFILEH, ">$capfile") || die "Error opening $capfile for writing";
		   	 print CAPFILEH $caplink;
		    	close(CAPFILEH);
		   }
		    # now grab title from real page
		    $my_title = $g_tree->look_down(_tag=>'div', id=>'imageinfo', class=>'imageinfo');
		    $my_title = $g_tree->look_down(_tag=>'span', , class=>'title') if (defined($my_title));
		    $my_title_text = $my_title->as_text if (defined($my_title));

		    $output_title = $my_title_text if (!$output_title);
		    print_dbg ("TITLE from image page:$output_title");
		    $titlefile="titles\/".$imgcnt.".txt";
    		    print_dbg("Creating title file $titlefile\n");
    		    open (TTLFILE, ">$titlefile") || die $!;
                    print TTLFILE $output_title;
                    close (TTLFILE);
	     }

            $g_tree->delete();

        };

    }    # desperate
         # before I say that an image is broken, I will try and download it
         # 2 times (or whatever value you gave in -repeat
         # if it fails after that many times, then I classify it as broken

    do {
        print_dbg("$fn (Trying $method scheme, try#$rpt_cnt)");
        if ($pb_nosave) { $resp = $browser->get($iurl) }
        else {
            if ($pb_mirror)    #in this mode, only download images that are new
            {
                $resp = $browser->mirror( $iurl, $fn );
                print_dbg("Image is up-to-date:$fn (Not mirrored)")
                  if ( $resp->code == 304 );
            }
            else
	    {
		$image=undef;
		if (!$isvideo)
		{
			print_dbg("Trying to download>> $iurl");
                	$resp = $browser->get( $iurl, ":content_file" => $fn );
			$badimage=0;
			$image = GD::Image->newFromJpeg($fn);
		}
		else
		{
			$image=undef;
		}
		$badimage=1 if (!defined($image)) ;
		if ($badimage)
		{
			print_dbg("$fn is not a valid image. Making my own");
			$image = new GD::Image(160,160);
			$grey = $image->colorAllocate(128,128,128);
			$image->fill(50,50,$grey);
		}
		my $x_cap="";
            	my $max = 160;    # This is the max thumbnail dimension of pbase
            	my ( $maxx, $maxy );

		my ($ox,$oy)=$image->getBounds();
		if ( ( $maxx, $maxy ) = $max =~ /^(\d+)x(\d+)$/i )
		{
                	$max = $ox > $oy ? $maxx : $maxy;
	        }
            	my $r = $ox > $oy ? $ox / $max : $oy / $max;

	    	if ($r >=1)
	    	{
	    	    $x = new GD::Image(int($ox/$r),int($oy/$r));
		    $x->copyResized($image,0,0,0,0,int($ox/$r),int($oy/$r),$ox,$oy);

	    	}
	    	else {$x = $image;}
		my ($oxx,$oyy) = $x->getBounds();
		    print_dbg ("Trying to create thumbnail $thumb_fn");
		    open (IMGFN, ">$thumb_fn");
		    binmode IMGFN;
		    $jpg_data= $x->jpeg();
	    	    print IMGFN $jpg_data;
	    	    close IMGFN;

		    # add to gallery html
		    $gal_str ="<td align=center><a href='$fn'><img src='$thumb_fn'></a><br/>$output_title</br>";
		    $gal_str = $gal_str."<a href='$capfile'>caption</a>" if ( -e $capfile);
		    $gal_str = $gal_str."</td>\n";
		    print GAL_HTML $gal_str;
		    $thumb_col++;

		    if ( $thumb_col == 5 ) {
       			 print GAL_HTML "</tr><tr valign=top>\n";

			$thumb_col = 1;
    			}


            }
        }

        $valid = length( $resp->content ) if ($pb_nosave);
        $valid = ( -s $fn ) if ( !$pb_nosave );

        if ( ( $valid == 0 ) || ( $valid == $corrupt_size ) || ($valid==$dlink_disabled) || ($valid==$pass_protected)) {
            $rpt_cnt++;

	    print_dbg("Hmm, you likely have direct linking disabled for this, trying to get the mangled image...") if ($valid==$dlink_disabled);
	    print_dbg("Hmm, this is likely a private image, working around PBase hiding tricks...") if ($valid==$pass_protected);

	    $rpt_cnt = $pb_repeat+1 if (($valid==$dlink_disabled) || ($valid==$pass_protected));
            $ret_code = 0;
        }

	else
	{
            $rpt_cnt  = $pb_repeat + 1;
            $ret_code = 1;
        }
    } until ( $rpt_cnt > $pb_repeat );
    print_dbg("Failed to download this time!") if (!$ret_code);
    return $ret_code;
}




#=========================================================
# MAIN
#=========================================================

sub pbgrab
{

@stackedgalleries=();
$user=shift;
$password=shift;
$user_gal=shift;
$root_path=shift;
$show_dbg=shift;
$strip_html=shift;
#$mw=shift;
$download_nested=shift;


$user=lc($user);
$user_gal=lc($user_gal);

$origdir=cwd();

print "\n\n";
print_credit();
link_cookies();

if ($show_dbg)
{
	$show_dbg_fn="debug.txt";
	print "\n ** Debug log will be stored in $show_dbg_fn **\n";
		open (DBG_FH, ">$show_dbg_fn") || mydie "Could not create $show_dbg_fn";
		binmode(DBG_FH,":unix"); # unbuffered

		my $dt = localtime();
		print DBG_FH "Log file created on: $dt\n";
}


print_dbg ("pbgrab invoked with user:$user, gallery:$user_gal, path:$root_path, striphtml:$strip_html, nested:$download_nested");


$browser = LWP::UserAgent->new;
$browser->cookie_jar($cookie_jar);

# if user wants to route thru a proxy (firewall cases) do so
if ($http_proxy) {
    $browser->proxy( 'http', $http_proxy );
    print_dbg("Browser:Using proxy $http_proxy for all operations");
    select(STDOUT);
    $| = 1;
}

mkdir($root_path);
chdir($root_path);
push @stackedgalleries, $user_gal;
#push @stackedgalleries, cwd();

open( MASTER_GAL_HTML, ">index.html" );
print MASTER_GAL_HTML
"<html>\n<head>\n<title>Pbgrab downloaded archive for $user</title></head>\n";
    print MASTER_GAL_HTML "<body><font face='tahoma' size=2>\n";
    print MASTER_GAL_HTML
      "<h2>Pbgrab downloaded archive for $user</h2>\n";
    $pg_ver = getversion();
    print MASTER_GAL_HTML
      "<small>Pbgrab version $pg_ver (c) Arjun Roychowdhury</small><br><br>\n";
    print MASTER_GAL_HTML
    "<a href='$user_gal/index.html'>$user_gal</a>\n</body></html>\n";
    close (MASTER_GAL_HTML);


while (@stackedgalleries)
{
$curdir=cwd();
$user_gal=shift(@stackedgalleries);
$pushed_dir=shift(@stackedgalleries);
$screwit_page = "http://www.pbase.com/".$user."/".$user_gal."\&page=1";
print_dbg("Gallery URL to work on:$screwit_page\n");
print "\n****Now working on Gallery:$user_gal****\n";


#$mw->update();
$datetime = localtime();




print_dbg("Getting $screwit_page");
$response = $browser->get($screwit_page);
    if ( $response->is_error ) {
	$failed=$response->status_line;
        print "ERROR: Could not read Gallery Tree\n";
        print "If you are using a personal firewall, you should use -proxy\n";
	print "The error was: ".$failed."\n";
	print_dbg ("Error reading gallery tree with error $failed");
        myexit(); return;
    }
$g_page = $response->content;

$tree = HTML::TreeBuilder->new;
eval { $tree->parse($g_page) };
if ($@) {
    print "There are probably no galleries that match your criteria\n";
    print_dbg("There was an error parsing the first page");
}

print "Your galleries will be stored in ". $curdir. "/".$user_gal. "\n";
#chdir($pushed_dir);
mkdir ($user_gal);
chdir($user_gal);
mkdir ("captions");
mkdir ("dates");
mkdir ("images");
mkdir ("titles");
mkdir ("thumbs");

$thumb_col=1;

my $gallerytitle = '';
my $gallerytitletext = '';
my $gallerytitleh=$tree->look_down(_tag=>'h2');
if (defined($gallerytitleh))
{
	$gallerytitle=$gallerytitleh->as_HTML;
	$gallerytitletext=$gallerytitleh->as_text;
	$gallerytitle=$gallerytitletext if ($strip_html);
}
print_dbg("Retrieved gallery title as: $gallerytitle");

my $galleryheader=$tree->look_down(_tag=>'div',class=>"galleryheader");
$gallerydesc='';
if (defined($galleryheader))
{
	$gallerydesc=$galleryheader->as_HTML;
	$gallerydesc=$galleryheader->as_text if ($strip_html);
}
print_dbg("Retrieved gallery description as:$gallerydesc");

open( GAL_HTML, ">index.html" );
print GAL_HTML
"<html>\n<head>\n<title>$gallerytitletext</title></head>\n";
    print GAL_HTML "<body><font face='tahoma' size=2>\n";
		print GAL_HTML "<h1>$gallerytitletext</h1>\n";
    print GAL_HTML
      "<h2>Pbgrab downloaded archive for $user, gallery $user_gal on $datetime</h2>\n";
    $pg_ver = getversion();
    print GAL_HTML
      "<small>Pbgrab version $pg_ver (c) Arjun Roychowdhury</small><br><br>\n";
print GAL_HTML "<center>\n";
print GAL_HTML $gallerydesc;
            print GAL_HTML
              "<table border=0 cellpadding=2 width='10%' cellspacing=2>\n";
            print GAL_HTML "<tr valign=top>\n";

#iterate through each gallery
my $pages=$tree->look_down(_tag => 'div', id=>'gallery_entries');
$pages=$tree->look_down(_tag => 'div', class=>'thumbnails') if (!defined($pages)); # non pblog galleries use thumbnails while pblog galleries use gallery_entries
$pages=$pages->look_down(_tag => 'table') if (defined($pages));
$pages=$pages->look_down(_tag => 'tr') if (defined($pages));
$pages=$pages->look_down(_tag => 'td') if (defined($pages));
$pages=$pages->right() if (defined($pages));
@page_list_tree=();
@page_list_tree=$pages->find_by_tag_name('a') if (defined($pages));
@page_list=();
foreach my $pagenode (@page_list_tree)
{
	$url="http://www.pbase.com".$pagenode->attr('href');
	push @page_list,$url if ( !($url =~ m/&page=all/) && ($url =~ m/&page=/ )); # handle non pblogs having an all page
}
unshift(@page_list,$screwit_page);
print_dbg ("Here are the pages I found that I will need to scrape:");
foreach (@page_list) {
  print_dbg ("$_\n");
}


$cnt=0; $imgcnt=0;

open (FH,">gallerydesc.txt");
print FH $gallerydesc;
close (FH);

foreach my $pagenode (@page_list)
{
	#$mw->update();
	$cnt++;
	print "\n\n";
	print "Working on Page $cnt...\n";
	#last if ($cnt > 4);  # ONLY FOR TESTING - REMOVE
	my $g_tree= HTML::TreeBuilder->new;
	print_dbg("Getting page:$pagenode");
	$resp=$browser->get($pagenode);
	$g_page=$resp->content;
	$g_tree->parse($g_page);
	#my $ge_odd=$g_tree->look_down('class',qr/gallery_entry*/);
	my $ge_odd;
	eval {
		$ge_odd=$g_tree->look_down(
			_tag => 'div',
			class => qr{^gallery_entry});
		#$ge_odd=$g_tree->look_down('class','gallery_entry-odd');
	};
	$ispblog=1;
	if (!defined ($ge_odd)) # its a gallery, maybe
	{
		print_dbg("This page is a regular gallery, not a pblog");
		print_dbg("If it is a pblog maybe its private and you did not correctly specify a password");
		$ispblog=0;
		eval {
			$ge_odd=$g_tree->look_down(_tag=>'div',class=>'thumbnails');
		};
		if ($@)
		{
			if ($cnt==1) # print this error is its on first page
			{
			print_dbg("An error occurred. Make sure you entered the correct username (and password if its a private gallery)");
			print ("I could not process this gallery. Make sure you entered your login details correctly\n");
			}
			myexit(); return;
		}
		eval {

		@list_ge=$ge_odd->look_down(_tag=>'td', class=>'thumbnail'); # get a list of all images on the page
	};
	if ($@)
		{
			print_dbg("An error occurred. Make sure you entered the correct username (and password if its a private gallery)");
			print ("I could not process this gallery. Make sure you entered your login details correctly\n");
			myexit(); return;
		}

		$ge_cnt=0;
		$ge_odd=$list_ge[$ge_cnt];
		$ge_size=scalar @list_ge;
		print_dbg("There are a total of $ge_size images on this page");
	}

	# suck pblogs
	while (defined ($ge_odd) && ref($ge_odd))
	{
		print_dbg("\n\n--------- NEW IMAGE PARSE --------");
		$ct="";
		$isvideo=0;
		print_dbg(Dumper($ispblog, $ge_odd));
		if ($ispblog && defined $ge_odd ) {
			print_dbg(Dumper($ge_odd->as_text()));
			#print_dbg(Dumper($ge_odd->as_text()));
			$title=$ge_odd->look_down('class','title-image');
			$caption=$ge_odd->look_down('class','image_caption');
			$date=$ge_odd->look_down('class','image_date');
			$img=$ge_odd->look_down('class','thumbnail');
			$img=$ge_odd->look_down(_tag=>'a')->attr('href') if (defined($img));
		}
		else # non blog
		{
			$output_title=$ge_odd->as_text();
			$output_caption="";
			$date="";
			$img=$ge_odd->look_down(_tag=>'a')->attr('href');
			print_dbg ("preview TITLE:$output_title, URL:$img\n");
			$ct="";
		}

		if ($ispblog && defined $ge_odd )
		{
			$output_title="";
			$output_caption="";
			$output_date="";
			$output_title=$title->as_text if (defined($title));
			$output_caption=$caption->as_HTML if (defined($caption));
			$output_date=$date->as_text if (defined($date));
			$ct="";
			$ct=$caption->as_HTML if (defined($caption));
		}
		if (($ct =~ m/<iframe/) || ($ct =~ m/<object/)) # if its a youtube video, get the HTML version
		{
			$isvideo=1;
			print_dbg("Looks like this has an embedded video");
		}
		else
		{
		}
		$output_caption=$caption->as_HTML if($isvideo);

		# just to be safe, if the URL does not have pbase and image, its not an image :-)
		# if its a video file, then we need the captions so let it go
		if (   ($isvideo) || (($img =~ m/image/) && ($img =~ m/pbase/) && (!($img =~ m/&gcmd=/)))   )
		{
	    		print_dbg ("Trying to save image at $img.jpg...");
			$img=$img."/original" if ($img);
            		if ( !tryanddownload( $img, "DESPERATE",$imgcnt,1,$output_title,$output_date,$isvideo,$ct ) )
	   		 {
			    	print_dbg ("Bummer!");
	    		}
	    		else
	    		{
		    		print_dbg ("Success!");
	    		}
		} #isvideo
		elsif  (($img =~ m!http://www.pbase.com/$user/(.*)!i) && ($download_nested )) # gallery
		{
			print ("\nI found a gallery:$1\n");
			print_dbg ("I found a gallery:${img}, pushing to stack for later use");
			push @stackedgalleries, $1;
			push @stackedgalleries,cwd();
			 # add to gallery html
			 $image = new GD::Image(160,160);
			$grey = $image->colorAllocate(128,128,128);
			$image->fill(50,50,$grey);
			open (IMGFN,">thumbs/gallery.jpg");
			binmode IMGFN;
			print IMGFN $image->jpeg();
			close IMGFN;

			# $gal_str ="<td align=center><a href='$1/index.html'><img src='thumbs/gallery.jpg'/><br/>[ $1 ]</a></td>\n";
			 $gal_str ="<td align=center><a href='../$1/index.html'><img src='thumbs/gallery.jpg'/><br/>[ $1 ]</a></td>\n";
		   	 print GAL_HTML $gal_str;
		    	 $thumb_col++;

		   	 if ( $thumb_col == 5 ) {
       			 print GAL_HTML "</tr><tr valign=top>\n";

			 $thumb_col = 1;
    			 }

		}
		else
		{
			print_dbg( "$img looks like its not an image, nor a video - skipping ");
		}
		#print $ge_odd->as_HTML();
		$imgcnt++;
		if ($ispblog)
		{
			$ge_odd=$ge_odd->right();
		}
		else
		{
			$ge_cnt++;
			$ge_odd=$list_ge[$ge_cnt];
			#$ge_odd=undef if(ge_cnt>ge_size);
			if ($ge_cnt>$ge_size) { undef $ge_odd; };
		}

    printprogress();
	} # while there are pictures in one page
	print "\nMoving on to next page..\n";
	$g_tree->delete();
	print_dbg("\n\n************** NEXT PAGE *****************\n\n");
} # each page
 print GAL_HTML "</tr></table></center>\n" if ($pb_thumbs);
    print GAL_HTML "</body></html>\n";
    close(GAL_HTML);


    print ("\n\nFinished with $user_gal\n");
     chdir($curdir);
}#stacked galleries
chdir($origdir);
print "\n**** PBGRAB IS ALL DONE ******\n";
}



1;
