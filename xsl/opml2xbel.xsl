<?xml version="1.0" encoding="ISO-8859-1"?>

<!-- $Id: opml2xbel.xsl,v 1.1 2002/06/11 15:58:20 asc Exp $ -->

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
<xsl:output method = "xml" version = "1.0" encoding="UTF-8" indent = "yes" />

<xsl:template match = "/opml" >
<xbel>
 <title><xsl:value-of select="head/title" /></title>
 <info>
  <metadata>
   <xsl:attribute name = "owner"><xsl:value-of select="head/ownerName" /></xsl:attribute>
  </metadata>
  </info>
 <desc>
  Created <xsl:value-of select="head/dateCreated" />
  Last-modified <xsl:value-of select="head/dateModified" />
 </desc>
 <folder id = "root">
  <title>Root</title>
  <xsl:apply-templates select = "body"/>
 </folder>
</xbel>
</xsl:template>

<xsl:template match = "outline" >

<!-- This is here for debugging purposes. -->

<!--
  Current : <xsl:value-of select = "@text" />
 <xsl:if test="child::node()[1]">
  Has children
 </xsl:if>
 .
-->

 <xsl:choose>
  <xsl:when test="child::node()[1]">
   <xsl:call-template name = "folder" />
  </xsl:when>
  <xsl:otherwise>
   <xsl:call-template name = "bookmark" />
  </xsl:otherwise>
 </xsl:choose>
</xsl:template>

<xsl:template name = "bookmark">
<!--<xsl:if test="@isComment!='true'">-->
 <bookmark id = "{generate-id()}">

  <xsl:choose>
   <xsl:when test="@type='link'">
    <title><xsl:value-of select = "@text" /></title>
    <url><xsl:value-of select = "@url" /></url>
   </xsl:when>
   <xsl:otherwise>
    <title>*</title>
    <url>#</url>
    <desc><xsl:value-of select = "@text" /></desc>
   </xsl:otherwise>
  </xsl:choose>

 </bookmark>
<!--</xsl:if>-->
</xsl:template>

<xsl:template name = "folder">
 <folder id = "{generate-id()}">
 <xsl:choose>
  <xsl:when test="@isComment='true'">
   <title />
   <desc>
    <xsl:call-template name = "comment" />
   </desc>
  </xsl:when>
  <xsl:otherwise>
   <title>
    <xsl:value-of select = "@text" disable-output-escaping = "yes" />
   </title>
   <desc>
    <xsl:call-template name = "comment" />
   </desc>
  </xsl:otherwise>
 </xsl:choose>
 <xsl:apply-templates />
 </folder>

</xsl:template>

<xsl:template name = "comment">
 <xsl:for-each select = "child::node()">
  <xsl:if test="@isComment='true'">[ <xsl:value-of select = "@text" /> ]</xsl:if>
 </xsl:for-each>
</xsl:template>

</xsl:stylesheet>
