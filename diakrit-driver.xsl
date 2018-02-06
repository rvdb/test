<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:tei="http://www.tei-c.org/ns/1.0"
  xmlns="http://www.tei-c.org/ns/1.0"
  exclude-result-prefixes="#all"
  version="2.0">
  
  <xsl:import href="POC.diakrit.1.diakrit2milestone.xsl"/>
  <xsl:import href="POC.diakrit.2.milestone2fragment.xsl"/>
  <xsl:import href="POC.diakrit.3.fragment2span.xsl"/>
  
  <xsl:template match="/">
    <!-- parse diacritical string flags to milestone markers --> 
    <xsl:variable name="diakrit2milestone">
      <xsl:call-template name="diakrit2milestone"/>
    </xsl:variable>
    <!-- transform milestones to discrete "content" fragments -->
    <xsl:variable name="fragmentspan">
      <xsl:apply-templates select="$diakrit2milestone" mode="wrapfragment"/>
    </xsl:variable>
    <!-- regroup adjacent fragments to larger chunks -->
    <xsl:for-each select="$fragmentspan">
      <xsl:call-template name="fragment2span"/>
    </xsl:for-each>
  </xsl:template>
  
</xsl:stylesheet>