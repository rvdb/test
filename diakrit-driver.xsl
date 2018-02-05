<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:tei="http://www.tei-c.org/ns/1.0"
  xmlns="http://www.tei-c.org/ns/1.0"
  exclude-result-prefixes="#all"
  version="2.0">
  
  <xsl:import href="POC.diakrit.1.diakrit2milestone.xsl"/>
  <!-- not needed anymore -->
  <xsl:import href="POC.diakrit.2a.milestone2tags.xsl"/>
  <xsl:import href="POC.diakrit.2.tags2spans-text-expanded.xsl"/>
  <xsl:import href="POC.diakrit.3.regroupspans.xsl"/>
  
  <xsl:template match="/">
    <!-- parse diacritical string flags to milestone markers --> 
    <xsl:variable name="diakrit2milestone">
      <xsl:call-template name="diakrit2milestone"/>
    </xsl:variable>
    <!-- create discrete spans for structure-crossing spans -->
    <xsl:variable name="wrapspans">
      <xsl:apply-templates select="$diakrit2milestone" mode="wrapspan"/>
    </xsl:variable>
    <!-- regroup adjacent spans to larger chunks -->
    <xsl:for-each select="$wrapspans">
      <xsl:call-template name="regroup"/>
    </xsl:for-each>
  </xsl:template>
  
  <xsl:template match="/" priority="-100">
    <!-- upconvert diacritical string flags to milestone tags --> 
    <xsl:variable name="diakrit2milestone">
      <xsl:apply-templates mode="diakrit2milestone-parse"/>
    </xsl:variable>
    <!-- upconvert diacritical milestone tags to full elements where possible --> 
    <xsl:variable name="diakrit2tags">
      <xsl:for-each select="$diakrit2milestone">
        <xsl:call-template name="diakrit2tags"/>
      </xsl:for-each>
    </xsl:variable>
    <!-- create discrete spans for structure-crossing spans -->
    <xsl:variable name="wrapspans">
      <xsl:apply-templates select="$diakrit2tags" mode="wrapspan"/>
    </xsl:variable>
    <!-- regroup adjacent spans to larger chunks -->
    <xsl:for-each select="$wrapspans">
      <xsl:call-template name="regroup"/>
    </xsl:for-each>
  </xsl:template>

</xsl:stylesheet>