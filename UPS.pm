#!/usr/local/bin/perl
#
#	Figure UPS shipping 
#	Started 01/07/1998 Mark Solomon 
#

package Business::UPS;
use LWP::Simple;

require 5.003;

BEGIN {
	# set the version for version checking
        # if using RCS/CVS, this may be preferred
        $VERSION = do { my @r = (q$Revision: 1.7 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; # must be all one line, for MakeMaker
}

sub main::getUPS {

	my ($product, $origin, $dest, $weight, $country , $length,
		$width, $height, $oversized, $cod) = @_;

	my $ups_cgi = 'http://www.ups.com/using/services/rave/qcostcgi.cgi';
	my $workString = "?";
	$workString .= "accept_UPS_license_agreement=yes&";
	$workString .= "10_action=3&";
	$workString .= "13_product=" . $product . "&";
	$workString .= "15_origPostal=" . $origin . "&";
	$workString .= "19_destPostal=" . $dest . "&";
	$workString .= "23_weight=" . $weight;
	$workString .= "&22_destCountry=" . $country if $country;
	$workString .= "&25_length=" . $length if $length;
	$workString .= "&26_width=" . $width if $width;
	$workString .= "&27_height=" . $height if $height;
	$workString .= "&30_cod=" . $cod if $cod;
	$workString .= "&29_oversized=1" if $oversized;
	$workString .= "&30_cod=1" if $cod;
	$workString = "${ups_cgi}${workString}";

	my @ret = split( '%', get($workString) );

	if (! $ret[5]) {
		# Error
		return (undef,undef,$ret[1]);
	}
	else {
		# Good results
		my $total_shipping = $ret[10];
		my $ups_zone = $ret[6];
		return ($total_shipping,$ups_zone,undef);
	}
}


#
#	UPStrack sub added 2/27/1998
#


sub main::UPStrack {
	my ($tracking_number) = @_;
	my %retValue = {};
	$tracking_number || die "No number to track!";
	#my $h = `cat output`;
	#my $h = `cat err`;
	$h = get("http://wwwapps.ups.com/tracking/tracking.cgi?tracknum=$tracking_number");

	$h =~ s#<.*?>##gi;	# Remove html tags
	$h =~ s#\&nbsp;##gi;	# Remove '&nbsp' separators

	# Get top and bottom of data
	#
	my $scan_sep = 'Scanning Information';
	my $notice_sep = 'Notice';
	my ($head, $scan_info) = split($scan_sep,$h);	# Separate scanning info
	my ($head,$notice) = split($notice_sep,$head);	# Separate notice

	# Check if there's an error
	#
	$error_key = 'Unable to track';
	if ($head =~ /($error_key\s.*)\s\s\s\s/ ) {
		$error = $1;
		$error =~ s/\s+$/ /g;
		$retValue{'error'} = $error;
		return %retValue;
	}

	# Assign Notice
	$notice =~ s/[\r\n]//g;
	$retValue{'Notice'} = $notice;

	# Prepare 'scanning info' for hash
	#
	($scan_info) = split('\n\n',$scan_info);	# Remove bottom junk
	$scan_info =~ s/^\n//;				# Remove first blank
	my @scan_info = split('\n',$scan_info);		# Break into lines
	my %scan_info;
	# Iterate and make hash of scan code and status
	for ($i=0 ; $i < $#scan_info ; $i = $i + 2) {
		# print "$i: \$scan_info{ \$scan_info[ $i ] } = \$scan_info[ $i+1 ]\n";
		$scan_info{$scan_info[$i]} = $scan_info[$i+1];
		# $i++;
	}
	$retValue{'scan'} = \%scan_info;		# Assign reference to return value

	my @html = split('\n',$head);			# Start work on line
	my $line;					#   separated above
	foreach $line (@html) {
		next if ! $line;
		my ($key,$value) = ($line =~ /(.*?):(.*)/); # Split on ':'
		$retValue{$key} = $value if $value;	# Assign to main hash
		# print "$0: $key : $value\n" if $value;
	}
	return %retValue;
}



END {}

__END__

=head1 NAME

	Business::UPS - A UPS Interface Module

=head1 SYNOPSIS

    use Business::UPS;

    my ($shipping,$ups_zone,$error) = getUPS(qw/GNDCOM 23606 23607 50/);
    $error and die "ERROR: $error\n";
    print "Shipping is \$$shipping\n";
    print "UPS Zone is $ups_zone\n";

    %t = UPStrack("z10192ixj29j39");
    *scan = $t{scan};
    $t{error} and die "ERROR: $t{error};
    print "This package is $t{'Current Status'}\n"; # 'Delivered' or 'In-transit'

=head1 DESCRIPTION

	A way of sending four arguments to a module to get 
	shipping charges that can be used in, say, a CGI.

=head1 REQUIREMENTS

	I've tried to keep this package to a minimum, so you'll need:

=over 4

=item *

Perl 5.003 or higher

=item *

LWP Module

=back 4

=head1 ARGUMENTS for getUPS()

	Call the subroutine with the following values:
		1. Product code
		2. Origin Zip Code
		3. Destination Zip Code
		4. Weight of Package

	and optionally:

		5.  Country Code,
		6.  Length,
		7.  Width,
		8.  Height,
		9.  Oversized (defined if oversized), and
		10. COD (defined if C.O.D.)

=item 1.

	Product Codes:

		  1DM		Next Day Air Early AM
		  1DML		Next Day Air Early AM Letter
		  1DA		Next Day Air
		  1DAL		Next Day Air Letter
		  1DP		Next Day Air Saver
		  1DPL		Next Day Air Saver Letter
		  2DM		2nd Day Air A.M.
		  2DA		2nd Day Air
		  2DML		2nd Day Air A.M. Letter
		  2DAL		2nd Day Air Letter
		  3DS		3 Day Select
		  GNDCOM	Ground Commercial
		  GNDRES	Ground Residential
		  XPR		Worldwide Express
		  XDM		Worldwide Express Plus
		  XPRL		Worldwide Express Letter
		  XDML		Worldwide Express Plus Letter
		  XPD		Worldwide Expedited


	In an HTML "option" input it might look like this:

		  <OPTION VALUE="1DM">Next Day Air Early AM
		  <OPTION VALUE="1DML">Next Day Air Early AM Letter
		  <OPTION SELECTED VALUE="1DA">Next Day Air
		  <OPTION VALUE="1DAL">Next Day Air Letter
		  <OPTION VALUE="1DP">Next Day Air Saver
		  <OPTION VALUE="1DPL">Next Day Air Saver Letter
		  <OPTION VALUE="2DM">2nd Day Air A.M.
		  <OPTION VALUE="2DA">2nd Day Air
		  <OPTION VALUE="2DML">2nd Day Air A.M. Letter
		  <OPTION VALUE="2DAL">2nd Day Air Letter
		  <OPTION VALUE="3DS">3 Day Select
		  <OPTION VALUE="GNDCOM">Ground Commercial
		  <OPTION VALUE="GNDRES">Ground Residential

=item 2.
	Origin Zip(tm) Code

		Origin Zip Code as a number or string (NOT +4 Format)

=item 3.
	Destination Zip(tm) Code

		Destination Zip Code as a number or string (NOT +4 Format)

=item 4.
	Weight

		Weight of the package in pounds


=head1 ARGUMENTS for UPStrack()

	The tracking number.


=head1 RETURN VALUES

=item getUPS()

	The raw http get() returns a list with the following values:

	  ##  Desc		Typical Value
	  --  ---------------   -------------
	  0.  Name of server: 	UPSOnLine3
	  1.  Product code:	GNDCOM
	  2.  Orig Postal:	23606
	  3.  Country:		US
	  4.  Dest Postal:	23607
	  5.  Country:		US
	  6.  Shipping Zone:	002
	  7.  Weight (lbs):	50
	  8.  Sub-total Cost:	7.75
	  9.  Addt'l Chrgs:	0.00
	  10. Total Cost:	7.75
	  11. ???:		-1

	If anyone wants these available for some reason, let me know.

=item UPStrack()
	
	The hash that's returned is like the following:
		'Delivered on' 	=> '1-22-1998 at 2:58 PM'
		'Notice' 	=> 'UPS authorizes you to use UPS...'
		'Received by'	=> 'DR PORCH'
		'Addressed to'	=> 'NEWPORT NEWS, VA US'
		'scan'		=>  HASH(0x146e0c) (more later...)
		'Current Status'=> 'Delivered'
		'Delivered to'	=> 'RESIDENTIAL'
		'Sent on'	=> '1-20-1998'
		'UPS Service'	=> '2ND DAY AIR'
		'Tracking Number' => '1ZX29W29025xxxxxx'

	Notice the %hash{scan} is a reference to another hash for
	the scanning information and is like the following:
		'1-22-19982:58 PMNEWPORT NEWS-OYSTER, VA US' => 'DELIVERED'
		'1-21-199811:37 PMRICHMOND, VA US'	     => 'LOCATION SCAN'
		'2:05 PMPHILA AIR HUB, PA US' 		     => 'LOCATION SCAN'
		'1-20-199811:35 PMPHILA AIR HUB, PA US'	     => 'LOCATION SCAN'

=head1 EXAMPLE

=item getUPS()

	To retreive the shipping of a 'Ground Commercial' Package 
	weighing 25lbs. sent from 23001 to 24002 this package would 
	be called like this:

	  #!/usr/local/bin/perl

	  use Business::UPS;

	  my ($shipping,$ups_zone,$error) = getUPS(qw/GNDCOM 23001 23002 25/);
	  $error and die "ERROR: $error\n";
	  print "Shipping is \$$shipping\n";
	  print "UPS Zone is $ups_zone\n";

=item UPStrack()

	#!/usr/local/bin/perl

	use Business:UPS;

	%t = UPStrack("z10192ixj29j39");
	*scan = $t{scan};
	$t{error} and die "ERROR: $t{error};
	
	print "This package is $t{'Current Status'}\n"; # 'Delivered' or 'In-transit'
	print "More info:\n";
	foreach $key (keys %t) {
		print "KEY: $key = $t{$key}\n";
	}
	foreach $key (keys %scan) {
		print "SCANKEY $key = $scan{$key}\n";
	}


=head1 BUGS

	* I don't like the way the scanning information is returned.  It's not
	in chronological order, and the way the html tags are removed, the city
	and am/pm is not spaced.


=head1 AUTHOR

	Mark Solomon <msolomon@seva.net>
	mailto:msolomon@seva.net
	http://www.seva.net/~msolomon/

	NOTE: UPS is a registered trademark of United Parcel Service.

=cut
