use strict;

BEGIN { $| = 1; print "1..1\n"; }

use Apache::XBEL;

use Cwd;
use File::Copy;

my $cwd = &Cwd::getcwd();
my $xsl_dir = $cwd."/xsl";

if (! -d $xsl_dir) {
  print "Unable to locate 'xsl_dir' directory inside Apache-XBEL directory\n";
  print "1..not ok\n";
  exit;
}

foreach ("apache-xbel.xsl","opml2xbel.xsl") {

  if (! &install_xsl($_)) {
    print "1..not ok\n";
    exit;
  }
}

print "1..ok\n";

sub install_xsl {
  my $xsl_sheet = shift;

  if (! -f "$xsl_dir/$xsl_sheet") {
    print "Unable to locate '$xsl_sheet' file inside $xsl_dir directory.\n";
    return 0;
  }
  
  print "Would you like to install the '$xsl_sheet' stylesheet? ";
  
  my $answer = <STDIN>;
  chomp $answer;
  
  unless ($answer =~ /^y/) {
    return 1;
  }

  print "Please enter a directory path where you would like the stylesheet to be installed ";
  
  my $answer = <STDIN>;
  chomp $answer;

  if (! -d $answer) {
    print "'$answer is not a directory.\n";
    return 0;
  }

  if (! copy "$xsl_dir/$xsl_sheet" , "$answer/$xsl_sheet") {
    print "Unable to copy '$xsl_sheet' to $answer, $!\n";
    return 0;
  }

  return 1;
}
