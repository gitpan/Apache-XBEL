{

=head1 NAME

Apache::XBEL - mod_perl to transform XBEL into exciting and fooy HTML documents.

=head1 SYNOPSIS

 <Location />
  SetHandler  perl-script
  PerlHandler Apache::XBEL

  PerlSetVar  XbelPath     /path/to/yer-xbel-file.xbel
  PerlSetVar  XslPath      /path/to/apache-xbel.xsl
  PerlSetVar  CacheDir     /path/to/yer-cache-dir

  # This can be any valid "type" attribute as
  # defined by the Text::Outline constructor      
  PerlSetVar ConvertOutline    opml

  # If set to "On", output-escaping will be disabled
  # for title and description nodes in the XSL stylesheet
  PerlSetVar DisableEscaping   On
 </Location> 

=head1 DESCRIPTION

Apache::XBEL is an Apache mod_perl handler that uses XSLT to transform XML Bookmarks Exchange Language (XBEL) files into exciting and foofy dynamic HTML documents. Documents are rendered as collapsible outlines and individual nodes may be viewed and bookmarked as unique pages, so you don't have to click through a gazillion nested leaves to find what you're looking for.

If you have the Text::Outline package installed on your server, you can use it to convert a number of outline(r) formats as XBEL for use with the handler. 

Once individual nodes/pages have been rendered, they are cached to reduce the load on the server. Cache files are updated whenever any of the widgets involved in the transformation are modified.

=head1 IMPORTANT

If you are running this handler on a server that is also running AxKit, pre version 1.5, Apache::XBEL may periodically fail and return a server error. Some reports have suggested that reloading the page may cause the widget to load properly. Or not.

=cut

package Apache::XBEL;
use strict;

$Apache::XBEL::VERSION = '1.2.1';

use Apache::Constants qw(:common :response);
use Apache::File;
use Apache::Log;
use Apache::URI;

use Digest::MD5;
use FileHandle;
use File::Basename;

use XML::Generator;
use XML::LibXML;
use XML::LibXSLT;
use XML::XPath;

my $gObj_xpath;
my $gObj_xml_writer;

my $gObj_xml_parser;
my $gObj_xsl_parser;
my $gObj_xsl_stylesheet;
my $gObj_xsl_transformer;

my $gObj_digest;
my $gObj_outline;

my $gVar_xbel_file;
my $gVar_xbel_bak;
my $gVar_xsl_file;

sub handler {
    my $apache = shift;
    $apache->register_cleanup(sub{&cleanup($apache)});

    #
    #

    my $root       = $apache->location();
    my $root_uri   = $apache->uri($root);
    $root_uri      =~ /($root)(.*)/;
    my $path       = $2;

    my $uri        = Apache::URI->parse($apache);
    my $uri_scheme = $uri->scheme();
    my $uri_host   = $uri->hostname();

    if (! ($root_uri =~ /(.*)\/$/)) {
	my $redirect = "$uri_scheme://$uri_host$root_uri/";
	$apache->headers_out->set("Location"=>$redirect);
	return REDIRECT;
    }

    #
    #

    $gVar_xbel_file = $apache->dir_config("XbelPath");
	
    if (! -e $gVar_xbel_file) {
	$apache->log->error("Unable to locate '$gVar_xbel_file'.\n");
	return NOT_FOUND;
    }

    $gVar_xsl_file = $apache->dir_config("XslPath");
    
    if (! -e $gVar_xsl_file) {
	$apache->log->error("Unable to locate '$gVar_xsl_file'.\n");
	return NOT_FOUND;
    }

    #
    #

    if (! -e $apache->dir_config("CacheDir")) {
	$apache->log->error("Unable to locate the cache directory.\n");
	return SERVER_ERROR;
    }
    
    #
    #

    $gObj_xml_writer ||= new XML::Generator(pretty=> 2,conformance=>"strict");

    if (! $gObj_xml_writer) {
	$apache->log->alert("Unable to create XML::Generator object. $!");
	return SERVER_ERROR;
    }

    #
    #

    if (! $gObj_xml_parser) {

	$gObj_xml_parser = XML::LibXML->new();
	
	if (! $gObj_xml_parser) {
	    $apache->log->alert("Unable to create XML::LibXML object. $!");
	    return SERVER_ERROR;
	} 
	
	$gObj_xml_parser->validation(1);
    }

    #
    #

    $gObj_xsl_parser ||= XML::LibXSLT->new();

    if (! $gObj_xsl_parser) {
	$apache->log->alert("Unable to create XML::LibXSLT object. $!");
	return SERVER_ERROR;
    }

    #
    #

    $gObj_xsl_stylesheet ||= $gObj_xml_parser->parse_file($gVar_xsl_file);

    if (! $gObj_xsl_stylesheet) {
	$apache->log->alert("Failed to parse file $gVar_xsl_file");
	return SERVER_ERROR;
    };

    #
    #

    $gObj_xsl_transformer ||= $gObj_xsl_parser->parse_stylesheet($gObj_xsl_stylesheet);
	
    if (! $gObj_xsl_transformer) {
	$apache->log->alert("Failed to parse stylesheet object.");
	return SERVER_ERROR;
    }

    #
    #

    $gObj_digest ||= new Digest::MD5->new();

    if (! $gObj_digest) {
	$apache->log->alert("Unable to create MD5 object : $!\n");
	return SERVER_ERROR;
    }

    #
    #

    $path =~ s/\/$//;
    $path =~ s/^\///;
    $root =  &basename($root);

    #
    #
    
    if (my $type = $apache->dir_config("ConvertOutline")) {
	
	my $as_xbel = &convert_outline($apache,$type,$path)
	    || return SERVER_ERROR;

	$gVar_xbel_bak  = $gVar_xbel_file;
	$gVar_xbel_file = $as_xbel;
    }
    
    #
    #
    
    my ($cache_file,$exists) = &fetch_cache($apache,$path);
    
    if ($exists) {
	$apache->content_type("text/html");
	$apache->send_http_header();
	$apache->send_fd( Apache::File->new($cache_file) );
	return OK;
    }
    
    #
    #

    $gObj_xpath = new XML::XPath(filename=>$gVar_xbel_file);

    if (! $gObj_xpath) {
	$apache->log->alert("Unable to create XPath object : $!\n");
	return SERVER_ERROR;
    }

    #
    #

    my @path   = split("/",$path);
    my $lookup = &path2node(@path);

    my @nodes  = $gObj_xpath->findnodes($lookup);
    
    if (! @nodes) {
	$apache->log->error("Lookup for '$lookup' failed.\n");
	return NOT_FOUND;
    }

    #
    #

    my $fh = Apache::File->new();

    if (! $fh->open(">$cache_file")) { 
	$apache->log->error("Failed to open $cache_file for writing : $!\n"); 
	return SERVER_ERROR;
    }

    $fh = &lock_cache($apache,$fh) || return SERVER_ERROR;

    print $fh $gObj_xml_writer->xmldecl( version => "1.0",encoding=>"ISO-8859-1" );

    if ($nodes[0]->getName eq "xbel") {
	print $fh $nodes[0]->toString();
    }

    else{
	print $fh $gObj_xml_writer->xbel( &build_node($gObj_xml_writer,$nodes[0] ));
    }
    
    $fh->close();

    #
    #

    my @breadcrumbs = ("$root",split("/",$path));
    my @nav_bar     = ();

    my $location = $apache->location();

    for (my $j = 0; $breadcrumbs[$j]; $j++) {
	next unless $breadcrumbs[$j+1];

	my $p = join("/",@breadcrumbs[1..$j]);
	my $h = "$uri_scheme://$uri_host$location/".join("/",@breadcrumbs[1..$j]);

	$p    = $gObj_xpath->findvalue(join("/",&path2node(split("/",$p)),"title"));
	$p    = "<a href = \"$h\">$p</a>";

	push(@nav_bar,"<span class = \"navbar-item\">$p</span>");
    }

    my $crumbs = "<div class = \"navbar\">".join("\n",@nav_bar)."</div>";
    my $escape = ($apache->dir_config("DisableEscaping") =~ /^(on)$/i) ? "yes" : "no";

    #
    #

    $gObj_xpath->cleanup();
    
    #
    #

    my $xmldoc  = $gObj_xml_parser->parse_file($cache_file);
    my $html    = $gObj_xsl_transformer->transform(
						   $xmldoc,
						   &XML::LibXSLT::xpath_to_string(crumbs=>$crumbs),
						   &XML::LibXSLT::xpath_to_string(noescape=>$escape),
						   );

    $gObj_xsl_transformer->output_file($html,$cache_file);

    #
    #

    # Send the stupid file, already
    $apache->content_type("text/html");
    $apache->send_http_header();

    $apache->send_fd(new Apache::File($cache_file));
    return OK;
}

# =head2 &cleanup($apache)
#
# =cut

sub cleanup {
    my $apache = shift;

    if ($gVar_xbel_bak) {
	$gVar_xbel_file = $gVar_xbel_bak;
	$gVar_xbel_bak  = undef;
    }


    return 1;
}

# =head2 fetch_cache($apache,$path)
#
# =cut

sub fetch_cache {
    my $apache    = shift;
    my $path      = shift;

    # First determine cache name
    $gObj_digest->add(join("/",$gVar_xbel_file,$path));

    my $cache = join("/",$apache->dir_config("CacheDir"),$gObj_digest->hexdigest());

    $apache->log->debug("Cache is $cache");

    # Check for existence
    if (! -e $cache) {
	$apache->log->debug("Cachefile '$cache' does not exist.");
	return ($cache,0);
    }

    # Is older ?
    my $cache_mtime = (stat($cache))[9];

    if ((stat(__FILE__))[9] > $cache_mtime ) {
	$apache->log->debug("Cache is out of sync with handler.");
	return ($cache,0);
    }

    if ((stat($gVar_xbel_file))[9] > $cache_mtime ) {
	$apache->log->debug("Cache is out of sync with XBEL file.");
	return ($cache,0);
    }

    if ((stat($gVar_xsl_file))[9] > $cache_mtime) {
	$apache->log->debug("Cache is out of sync with stylesheet.");

	$gObj_xsl_stylesheet  = $gObj_xml_parser->parse_file($gVar_xsl_file);
	$gObj_xsl_transformer = $gObj_xsl_parser->parse_stylesheet($gObj_xsl_stylesheet);
	
	return ($cache,0);
    }

    return ($cache,1);
}

# =head2 &path2node(@path)
#
# =cut

sub path2node {
    my @path = @_;
    map { $_ = "folder[\@id=\"$_\"]"; } @path;
    return join("/","","xbel",@path);
}

# =head2 &build_node($xbel,$node)
#
# =cut

sub build_node {
    my $xbel = shift;
    my $node = shift;
    
    my $author   = "";
    my $desc     = "";

    my @children = $node->getChildNodes();
    my @body;

    for (my $i = 1; $children[$i]; $i++) {
	my $child = $node->getChildNode($i)->getName();
	push(@body,\$node->getChildNode($i)->toString());
    }
    
    my $n = join("",(
		     $xbel->info($xbel->metadata({ owner => $author })),
		     $xbel->desc($desc),
		     map { $$_ } @body,
		     ));
    
    return $n;
}

# =head2 &lock_cache($apache,$fh)
#
# =cut

sub lock_cache {
    my $apache = shift;
    my $fh     = shift;

    my $success = 0;
    my $tries   = 0;

    while ($tries++ < 10) {
	return $fh if ($success = flock($fh,2));
	sleep(1);
    }

    $apache->log->error("Failed to lock file for writing.");
    return undef;
}

# =head2 &convert_outline($apache,$type,$path)
#
# =cut

sub convert_outline {
    my $apache = shift;
    my $type   = shift;
    my $path   = shift;

    my $class  = "Text::Outline";

    if (! $gObj_outline) {

	eval "require $class";
	
	if ($@) {
	    $apache->log->error("Unable to instantiate '$class' : $@");
	    return 0;
	}
    }

    $gObj_outline = $class->new(load=>$gVar_xbel_file,type=>$type);
    
    if (! $gObj_outline) { 
	$apache->log->error("Unable to load outline '$gVar_xbel_file' : $@");
	return 0;
    }
    
    if (! $gObj_outline->can("asXBEL")) {
	$apache->log->error("This version of $class is unable to convert outlines as XBEL.");
	return 0;
    }

    #
    #

    my ($xbel_cache,$exists) = &fetch_cache($apache,join("-",$path,$type));
    if ($exists) { return $xbel_cache; }

    #
    #

    my $fh = Apache::File->new();
    $fh->open(">$xbel_cache");

    $fh = &lock_cache($apache,$fh) || return SERVER_ERROR;
    
    print $fh $gObj_outline->asXBEL();
    $fh->close();

    #
    #

    return $xbel_cache;
}

=head1 VERSION

1.2.1

=head1 DATE

June 11, 2002

=head1 AUTHOR

Aaron Straup Cope <ascope@cpan.org>

=head1 TO DO

=over

=item *

Use XML::LibXML, or maybe XML::SAX::Writer, instead of XML::Generator, to write XBEL node(s) to disk

=item *

Add hooks to specify XSLT engine in httpd.conf

=item *

Pass breadcrumbs as a node rather than a string?

=item *

Add hooks to check for valid DOM support in browser

=item *

Write a plain vanila stylesheet and write DOM related functions.

=item *

Write a proper test file - if there is a document outlining how to do this for mod_perl handlers, I'd love to hear about it.

=back

=head1 SEE ALSO

http://pyxml.sourceforge.net/topics/xbel/

http://simon.kittle.info/text_outline

http://aaronland.net/toys/apache-xbel

=head1 LICENSE

Copyright (c) 2001-2002 Aaron Straup Cope. All Rights Reserved.

This is free software, you may use it and distribute it under the same terms as Perl itself.

=cut

return 1;

}
