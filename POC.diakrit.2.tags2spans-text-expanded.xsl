<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:tei="http://www.tei-c.org/ns/1.0"
  xmlns:span="http://ctb.kantl.be/span"
  xmlns:local="local"
  xmlns="http://www.tei-c.org/ns/1.0"
  exclude-result-prefixes="#all"
  version="2.0">
  
  <!-- diakrit step 3: convert boundary-crossing start and end milestones to linked spans of separate full content elements
    -->

  <xsl:template match="/">
    <xsl:apply-templates mode="wrapspan"/>
  </xsl:template>
  
  <xsl:template match="tei:anchor|tei:milestone" mode="wrapspan"/>
  
  <!-- make sure non-wrappable elements are just copied, not wrapped -->
  <!-- ==> shouldn't this be reformed to make use of  local:isWrappable()? --> 
  <xsl:template match="tei:text/*|tei:div|tei:ab" mode="wrapspan" priority="1">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()" mode="#current"/>
    </xsl:copy>
  </xsl:template>
  
  <!-- determine if elements need to be wrapped:
    -if so, wrap them
    -if not, copy them
  -->
  <xsl:template match="tei:text//*[not(self::tei:milestone[@subtype='start']|self::tei:anchor[@subtype='end'])]" mode="wrapspan">
    <xsl:param name="wrapSpans" as="node()*" tunnel="yes"/>
    <xsl:variable name="spanned" select="local:isSpanned(.) except $wrapSpans"/>
<!--<xsl:if test="$spanned[.]">
  <SPANS><xsl:copy-of select="$spanned"/></SPANS>
</xsl:if>    -->
    <xsl:choose>
      <xsl:when test="$spanned[.] and node() and not(local:inWrappableContext(.))">
        <xsl:message>pak kindjes in: <xsl:copy-of select="."/></xsl:message>
        <xsl:message>-- <xsl:copy-of select="$spanned"/></xsl:message>
        <xsl:copy>
          <xsl:apply-templates select="@*" mode="#current"/>
          <xsl:call-template name="wrap">
            <xsl:with-param name="wrapContent" select="node()" tunnel="yes"/>
            <xsl:with-param name="wrapSpans" select="$wrapSpans|$spanned" tunnel="yes"/>
            <xsl:with-param name="currentSpans" select="$spanned"/>
          </xsl:call-template>
        </xsl:copy>
      </xsl:when>
      <xsl:when test="$spanned[.] and local:inWrappableContext(.)">
        <xsl:message>pak in: <xsl:copy-of select="."/></xsl:message>
        <xsl:message>-- <xsl:copy-of select="$spanned"/></xsl:message>
        <xsl:call-template name="wrap">
          <xsl:with-param name="wrapContent" select="." tunnel="yes"/>
          <xsl:with-param name="wrapSpans" select="$wrapSpans|$spanned" tunnel="yes"/>
          <xsl:with-param name="currentSpans" select="$spanned"/>          
        </xsl:call-template>        
      </xsl:when>
      <xsl:otherwise>
        <xsl:next-match/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <!-- determine if text need to be wrapped:
    -if so, wrap 
    -if not, copy 
  -->
  <xsl:template match="text()[normalize-space()][local:isSpanned(.)]" mode="wrapspan">
    <xsl:param name="wrapSpans" as="node()*" tunnel="yes"/>
    <xsl:variable name="spanned" select="local:isSpanned(.) except $wrapSpans"/>
    <xsl:choose>
      <xsl:when test="$spanned[.]">
    <xsl:call-template name="wrap">
      <xsl:with-param name="wrapSpans" select="$wrapSpans|$spanned" tunnel="yes"/>
      <xsl:with-param name="wrapContent" select="." tunnel="yes"/>
      <xsl:with-param name="currentSpans" select="$spanned"/>
    </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:next-match/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <!-- function that determines if a node is enclosed by corresponding start and end milestones:
    -start marker occurs either before the current node or as first child
    -corresponding end marker occurs after start of current node 
  -->
  <xsl:function name="local:isSpanned">
    <xsl:param name="node"/>
    <xsl:variable name="span.start" select="$node/(preceding::tei:milestone|descendant::tei:milestone)[@subtype='start'][every $i in @spanTo satisfies following::tei:anchor[. >> $node][@subtype='end'][@xml:id = $i/replace(., '^#', '')]]
      [. &lt;&lt; $node or not(preceding::node()
      [not(self::text()[not(normalize-space())])][1] &gt;&gt; $node)]
      "/>
    <xsl:variable name="span.end" select="$span.start/following::tei:anchor[@subtype='end'][@xml:id = $span.start/@spanTo/replace(., '^#', '')]
      [not(following::node()
      [not(self::text()[not(normalize-space())])][1] intersect $node/descendant::node())]"/>
    <!--    <xsl:for-each select="$span.start[.]">
      <xsl:message>YES: <xsl:copy-of select="."/>
     node: <xsl:copy-of select="$node"/> 
      </xsl:message>
    </xsl:for-each>-->
    <!-- can also be done in 1 step by extending the predicate tests for $span.start, but a separate step improves transparency -->
    <xsl:variable name="span.start.balanced" select="$span.start[@spanTo/replace(., '^#', '') = $span.end/@xml:id]"/>
    <xsl:if test="$span.start.balanced">
<!--      <xsl:message>
        $span.start: <xsl:copy-of select="$span.start"/>
        $span.end: <xsl:copy-of select="$span.end"/>
        $node: <xsl:copy-of select="$node"/>
      </xsl:message>-->
      <xsl:sequence select="$span.start.balanced"/>
      <xsl:sequence select="$span.end"/>
    </xsl:if>
  </xsl:function>
  
  <!-- Template that ocnverts a spanned range to a matching wrapper TEI element -->
  <xsl:template name="wrap">
    <xsl:param name="wrapContent" tunnel="yes"/>
    <xsl:param name="wrapSpans" tunnel="yes"/>
    <xsl:param name="currentSpans" select="$wrapSpans"/>
    <xsl:param name="currentSpan.start" select="$currentSpans[@subtype='start'][1]"/>
    <xsl:variable name="currentSpan.end" select="$currentSpans[@subtype='end'][@xml:id = $currentSpan.start/@spanTo/replace(., '^#', '')][1]"/>
    <xsl:choose>  
      <xsl:when test="$currentSpan.start">
<!--        <HM xml:id="{($wrapContent/descendant-or-self::text()[normalize-space()])[1]/generate-id(.)}" prev="{($wrapContent[1]/preceding::text()[normalize-space()][. >> $currentSpan.start])[1]/generate-id()}" next="{(:$wrapContent[last()]/following::node()[descendant-or-self::text()[normalize-space()]][. &lt;&lt; $currentSpan.end][1]/descendant-or-self::text()[normalize-space()][. &lt;&lt; $currentSpan.end][1]/generate-id():)($wrapContent[last()]/following::text()[normalize-space()][. &lt;&lt; $currentSpan.end])[1]/generate-id()}"
          corresp="{$currentSpan.start/generate-id()}.{$currentSpan.start/@spanTo}"
          ><xsl:copy-of select="($wrapContent/descendant-or-self::text()[normalize-space()])[1]"/></HM>        
-->        <xsl:element name="{$currentSpan.start/@unit}">
          <xsl:attribute name="span:type">
            <xsl:text>span</xsl:text>
          </xsl:attribute>
          <xsl:attribute name="span:corresp">
            <xsl:value-of select="$currentSpan.start/@spanTo"/>
          </xsl:attribute>
          <xsl:attribute name="xml:id">
            <xsl:value-of select="string-join(($currentSpan.start/generate-id(), generate-id()), '.')"/>
          </xsl:attribute>
          <xsl:copy-of select="$currentSpan.start/@resp"/>
<!--          <xsl:for-each select="preceding::text()[normalize-space()][. >> $currentSpan.start][1]">
            <xsl:attribute name="prev">
              <xsl:value-of select="concat('#', string-join(($currentSpan.start/generate-id(), generate-id()), '.'))"/>
            </xsl:attribute>
          </xsl:for-each>
          <xsl:for-each select="following::text()[normalize-space()][. &lt;&lt; $currentSpan.end][1]">
            <xsl:attribute name="next">
              <xsl:value-of select="concat('#', string-join(($currentSpan.start/generate-id(), generate-id()), '.'))"/>
            </xsl:attribute>
          </xsl:for-each>
-->          <xsl:call-template name="wrap">
            <xsl:with-param name="currentSpans" select="subsequence($currentSpans, 2)"/>
          </xsl:call-template>
        </xsl:element>
      </xsl:when>
      <xsl:otherwise>
        <xsl:apply-templates select="$wrapContent" mode="#current"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <xsl:template match="@*|node()" mode="wrapspan" priority="-1">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()" mode="#current"/>
    </xsl:copy>
  </xsl:template>
  
  <xsl:function name="local:inWrappableContext" as="xs:boolean">
    <xsl:param name="node"/>
    <xsl:value-of select="not($node[
      (self::*|parent::*)/self::tei:text|
      (self::*|parent::*)/self::tei:body|
      (self::*|parent::*)/self::tei:front|
      (self::*|parent::*)/self::tei:div|
      self::tei:opener|
      self::tei:closer|
      self::tei:salute|
      self::tei:byline|
      self::tei:argument|
      self::tei:trailer|
      self::tei:dateline|
      self::tei:epigraph|
      self::tei:meeting|
      self::tei:postscript|
      self::tei:ab|
      self::tei:p|
      parent::tei:table|
      (self::*|parent::*)/self::tei:row|
      parent::tei:list|
      self::tei:head
      ])"/>
  </xsl:function>

</xsl:stylesheet>