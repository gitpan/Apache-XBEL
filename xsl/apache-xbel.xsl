<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
<xsl:output method="xml" />

<xsl:param name = "crumbs" select = "''" />
<xsl:param name = "noescape" select = "''" />

<!-- $Id: apache-xbel.xsl,v 1.1 2002/06/11 15:58:20 asc Exp $ -->

<!-- 
  This is based on work originally developed by Joris Graaumans
  http://www.cs.ruu.nl/~joris/stuff.html 
-->

<xsl:template match="/">

<html xmlns="http://www.w3.org/1999/xhtml" lang="en-US">
 <head>
   <title><xsl:value-of select = "/xbel/title" /></title>
   <meta>
     <xsl:attribute name = "name">author</xsl:attribute>
     <xsl:attribute name = "content"><xsl:value-of select = "/xbel/info/metadata/@owner" /></xsl:attribute>
   </meta>
   <meta>
     <xsl:attribute name = "name">description</xsl:attribute>
     <xsl:attribute name = "content"><xsl:value-of select = "/xbel/desc" /></xsl:attribute>
   </meta>

   <xsl:call-template name = "js-code" />
   <xsl:call-template name = "css-code" />

 </head>
 <body onload="javascript:toggle_display(1);">

  <xsl:value-of select = "$crumbs" disable-output-escaping = "yes" />
        
  <xsl:variable name="rpos">
   <xsl:value-of select="position()" />
  </xsl:variable> 

  <div class = "root">
   <xsl:attribute name="id">
    <xsl:value-of select="$rpos" />
   </xsl:attribute>
   <div class = "title">
    <xsl:attribute name="id">t<xsl:value-of select="$rpos" /></xsl:attribute>

    <xsl:call-template name = "_print">
     <xsl:with-param name = "data"><xsl:value-of select="/xbel/title" /></xsl:with-param>
    </xsl:call-template>

    <div class = "folder-description">
     <xsl:call-template name = "_print">
      <xsl:with-param name = "data"><xsl:value-of select="/xbel/desc" /></xsl:with-param>
     </xsl:call-template>
    </div>
   </div>

   <xsl:for-each select = "xbel/*">
    <xsl:call-template name="travel-folder">
     <xsl:with-param name="pos" select="$rpos" />
    </xsl:call-template>
   </xsl:for-each>

  </div>
        
</body>
</html>
</xsl:template>

<!-- Folders // still need to add support for "folded" attr -->

<xsl:template name="folder">
  <xsl:param name="pos" />
  <div class = "folder">

   <xsl:attribute name="id">
        <xsl:value-of select="$pos" />
          <xsl:value-of select="-position()" />
          </xsl:attribute>
          <xsl:attribute name="style">display:none;</xsl:attribute>
	<div>
          <!-- id is <xsl:value-of select="$pos" /><xsl:value-of select="-position()" />. -->
        <span class = "toggle-indicator">
	<xsl:attribute name="id">t<xsl:value-of select="$pos" /><xsl:value-of select="-position()" />
	</xsl:attribute>
        <xsl:attribute name="onclick">onclick_icon('<xsl:value-of select="$pos" /><xsl:value-of select="-position()" />')</xsl:attribute>
        <xsl:attribute name="onmouseover">onover_icon('<xsl:value-of select="$pos" /><xsl:value-of select="-position()" />')</xsl:attribute>
        <xsl:attribute name="onmouseout">onout_icon('<xsl:value-of select="$pos" /><xsl:value-of select="-position()" />')</xsl:attribute>
	f</span>

        <a><xsl:attribute name = "href"><xsl:for-each select="ancestor::*"><xsl:if test="(@id)"><xsl:value-of select="./@id" />/</xsl:if></xsl:for-each><xsl:value-of select="@id" />/</xsl:attribute><xsl:attribute name = "style">padding-left:10px;</xsl:attribute><xsl:call-template name = "_print"><xsl:with-param name = "data"><xsl:value-of select="title" /></xsl:with-param></xsl:call-template></a>

	<xsl:call-template name="folder-description"/>
	</div>

	<xsl:variable name="fpos">
	 <xsl:value-of select="$pos" />
	 <xsl:value-of select="-position()" />
        </xsl:variable>

        <xsl:for-each select = "./*">

         <xsl:call-template name="travel-folder">
          <xsl:with-param name="pos" select="$fpos" />
         </xsl:call-template>

        </xsl:for-each>

 </div>
</xsl:template>

<!-- Bookmarks -->

<xsl:template name="bookmark">

 <div class = "bookmark">
  <xsl:attribute name="style">display:none;</xsl:attribute>

   <xsl:choose>
    <xsl:when test = "@href">
     <a>
      <xsl:attribute name="href"><xsl:value-of select="@href" /></xsl:attribute>
      <xsl:attribute name="visited"><xsl:value-of select="@visited" /></xsl:attribute>
      <xsl:attribute name="modified"><xsl:value-of select="@modified" /></xsl:attribute>
      <xsl:call-template name = "_print">
       <xsl:with-param name = "data"><xsl:value-of select = "title" /></xsl:with-param>
      </xsl:call-template>
     </a>
    </xsl:when>
    <xsl:otherwise>
     <xsl:call-template name = "_print">
      <xsl:with-param name = "data"><xsl:value-of select = "title" /></xsl:with-param>
     </xsl:call-template>
    </xsl:otherwise>
   </xsl:choose>

   <xsl:if test = "./desc">
    <xsl:call-template name="bookmark-description"/>     
   </xsl:if>

  </div>
</xsl:template>

<!-- Descriptions -->

<xsl:template name="bookmark-description">
 <div class = "bookmark-description">
  <xsl:call-template name = "_print">
   <xsl:with-param name = "data"><xsl:value-of select = "desc" /></xsl:with-param>
  </xsl:call-template>
 </div>
</xsl:template>

<xsl:template name="folder-description">
 <div class = "folder-description">
  <xsl:call-template name = "_print">
   <xsl:with-param name = "data"><xsl:value-of select = "desc" /></xsl:with-param>
  </xsl:call-template>
 </div>
</xsl:template>

<!-- Other XBEL widgets -->

<xsl:template name="separator">
  <div class = "separator-wrapper"><div class = "separator">.</div></div>
</xsl:template>

<xsl:template name="alias">
  <span class = "alias">aliases don't work yet</span>
</xsl:template>

<!-- -->

<xsl:template name = "travel-folder">
  <xsl:param name="pos" />

     <xsl:if test = "name()='folder'">
      <xsl:call-template name="folder">
       <xsl:with-param name="pos" select="$pos" />
      </xsl:call-template>
     </xsl:if>

     <xsl:if test = "name()='bookmark'">
      <xsl:call-template name="bookmark"/> 
     </xsl:if>

     <xsl:if test = "name()='separator'">
      <xsl:call-template name="separator"/>
     </xsl:if>

     <xsl:if test = "name()='alias'">
      <xsl:call-template name="alias"/>
     </xsl:if>
  
</xsl:template>

<xsl:template name = "_print">
 <xsl:param name = "data" />
 <xsl:choose>
  <xsl:when test = "$noescape='yes'">
   <xsl:value-of select = "$data" disable-output-escaping = "yes" />
  </xsl:when>
  <xsl:otherwise>
   <xsl:value-of select = "$data" />
  </xsl:otherwise>
 </xsl:choose>
</xsl:template>

<!-- Formatting and client-side magic -->

<xsl:template name = "js-code">
<script type="text/javascript" language="JavaScript">
  //<![CDATA[

function onover_icon (id) {
     set_icon_bgcolor(id,"orange");
     toggle_icon_cursor(id);
}

function onout_icon (id) {
    toggle_icon_bgcolor(id);
}

function onclick_icon (id) {
    toggle_icon_cursor(id);
    toggle_display(id);
}

function toggle_display (id) {

    var parent   = document.getElementById(id);
    var children = parent.childNodes.length;

    for (var i = 1; children > i; i++) {
       var child   = parent.childNodes[i];
       var node    = child.nodeName;
       var display = child.style.display;

       if (node == "DIV") {
        // alert(i + " - display is " + display);
          if (display == "none")  { child.style.display = "block"; }
	  if (display == "block") { child.style.display = "none";  }
       }
    }
}

function toggle_icon_bgcolor (id) {
    if (get_display_state(id) == "none") {
        set_icon_bgcolor(id,"beige");
    } else {
        set_icon_bgcolor(id,"#cccccc");
    }
}

function toggle_icon_cursor (id) {
    if (get_display_state(id) == "none") {
        set_icon_cursor(id,"s-resize");
    } else {
        set_icon_cursor(id,"n-resize");
    }
}

function get_display_state (id) { 
    var parent = document.getElementById(id);
    var child  = parent.childNodes[1];	
    var state  = child.style.display; 
    return state;
}

function set_icon_bgcolor (id,colour) { 
    var icon = document.getElementById("t"+id).style;
    icon.backgroundColor = colour; 
}

function set_icon_cursor (id,cursor) { 
    var icon = document.getElementById("t"+id).style;	
    icon.cursor = cursor; 
}

//]]> 
</script>
</xsl:template>

<xsl:template name = "css-code">
<style type = "text/css">
//<![CDATA[

foo {}

body {
     margin-right:0px; 
     margin-left:0px;
     margin-top:0px;

     background:beige;
     font-family:sans-serif;
}

a { 
  color:#666666;
  text-decoration : none;
}

a:hover { 
	text-decoration : none; 
	color:orange; 
}

.wrapper {

}

.navbar {
	width : 100%;
	background:beige;
	padding-right:10px;
	padding-left:10px;
	padding-top:5px;
	padding-bottom:5px;
	font-family:sans-serif;
	font-weight:bold;
	font-size:14pt;
}

.navbar .navbar-item {
	padding-right:25px;
}

.navbar .navbar-item a:hover { cursor:w-resize; }

.root { 
      background:#ffffff;
      width : 60%;	
      font-size:14pt;
      font-weight:bold;
      font-family:sans-serif;
      color:maroon; 
      padding-left:10px;
      padding-top:10px;
      padding-bottom:25px;
      padding-right:10px;
      border-bottom:1px dashed darkslategray;
      border-top:1px dashed darkslategray;
      border-right:1px dashed darkslategray;
}

.title {
        border-bottom : 1px dashed #ccc;
        margin-bottom:10px;
        }
               
.folder {
	font-size:12pt;
	color:darkslategray;
	padding-left:25px;
	padding-top:5px;
}

.folder a:hover { cursor:e-resize; }

.bookmark { 
	  font-weight:normal;
	  font-size:10pt;
	  padding-left:50px;
	  color:maroon;
}

.bookmark a { 
	  color:maroon; 
          text-decoration:underline;
}

.bookmark a:hover { 
	  color:blue;	  
	  cursor:e-resize;   
}

.bookmark-description {
        color : #666666;
        margin-bottom:10px;
}

.folder-description {
        font-size:12pt;
        color:beige;
}

.separator-wrapper {
        padding-top:5px;padding-bottom:5px;
}

.separator {
        border-top : 3px dashed #ccc;
        font-size  : 1px;
        color      : #ffffff;
}

.toggle-indicator { 
		  font-size:10pt; 
		  background:beige;
		  border:1px solid darkslategray; 
		  width:17px;
		  height:10px;
		  clear:right; 
		  color:#cccccc;
		  text-align:center;
}

.description {
	     padding-left:10px;
	     color:darkslategray;
}

//]]>
</style>  
</xsl:template>

</xsl:stylesheet>
