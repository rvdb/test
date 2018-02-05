<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:tei="http://www.tei-c.org/ns/1.0"
  xmlns:local="local"
  xmlns="http://www.tei-c.org/ns/1.0"
  exclude-result-prefixes="#all"
  version="2.0">
  
  <!-- diakrit step 2:
    -convert "contiguous" (sibling) start and end milestones to full content elements
    -find, identify and link corresponding "cross-boundary" start and end milestones 
    -->
  
  <xsl:template match="/">
    <xsl:call-template name="diakrit2tags"/>
  </xsl:template>
    
  <!-- 2 passes:
    -diakrit2tags-prepare: convert "contiguous" (sibling) start and end milestones to full content elements
    -diakrit2tags-finish: find corresponding "cross-boundary" start and end milestone, and add (milestone|anchor)/@xml:id, milestone/@spanTo and anchor/@corresp
    -->
  <xsl:template name="diakrit2tags">
    <xsl:variable name="prepared">
      <xsl:apply-templates mode="diakrit2tags-prepare"/>
    </xsl:variable>
    <xsl:apply-templates select="$prepared" mode="diakrit2tags-finish"/>
  </xsl:template>
  
  <!-- find "wrappable" elements containing a start milestone, and convert it to a content tag if possible (i.e. if end milestone is sibling) -->
  <xsl:template match="*[tei:milestone[@subtype='start'][local:inWrappableContext(.)]]" mode="diakrit2tags-prepare">
    <xsl:copy>
      <xsl:apply-templates select="@*" mode="#current"/>
      <xsl:variable name="processed" select="local:wrap(.)"/>
      <xsl:apply-templates select="$processed" mode="#current"/>
    </xsl:copy>
  </xsl:template>
  
  <!-- convert temporary wrapper elements to corresponding TEI tags -->
  <xsl:template match="local:wrapper" mode="diakrit2tags-prepare" priority="1">
    <xsl:choose>
      <xsl:when test="tei:milestone[@subtype='start']">
        <xsl:apply-templates select="@*" mode="#current"/>
        <xsl:variable name="processed" select="local:wrap(.)"/>
        <xsl:apply-templates select="$processed" mode="#current"/>        
      </xsl:when>
      <xsl:otherwise>
        <xsl:apply-templates mode="#current"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <!-- remove debugging elements -->
  <xsl:template match="local:test" mode="diakrit2tags-prepare" priority="-100">
    <xsl:copy-of select="."/>
  </xsl:template>
  
  <!-- remove empty @resp attributes -->
  <xsl:template match="@resp[not(normalize-space())]" mode="diakrit2tags-prepare"/>
  
  <!-- -->
  <xsl:function name="local:wrap">
    <xsl:param name="node"/>
    <!-- $start: first start milestone -->
    <xsl:variable name="start" select="$node/tei:milestone[@subtype='start'][1]"/>
    <!-- $end: first corresponding end milestone sibling -->
    <xsl:variable name="end" select="$node/tei:anchor
        [. >> $start][@type=$start/@type][@subtype='end']
      [count(preceding-sibling::tei:milestone
        [. >> $start][@type=$start/@type][@subtype=$start/@subtype])
       = count(preceding-sibling::tei:anchor
         [. &gt;&gt; $start][@type = $start/@type][@subtype = 'end'])
      ][1]"/>
    <!-- just a debugging element -->
    <local:test> 
      START: <xsl:copy-of select="$start"/>
      END: <xsl:copy-of select="$end"/>
    </local:test>    
    
    <xsl:choose>
      <!-- if $start and $end are siblings: wrap their range in wrapper element -->
      <xsl:when test="$end">
        <xsl:variable name="wrap.content">
          <local:wrapper>
            <xsl:copy-of select="$node/node()[. &gt;&gt; $start][. &lt;&lt; $end]"/>
          </local:wrapper>
        </xsl:variable>
        <xsl:variable name="wrap.element" select="$start/@unit"/>
        <xsl:apply-templates select="$node/node()[. &lt;&lt; $start]" mode="diakrit2tags-prepare"/>  
        <xsl:element name="{$wrap.element}">
          <xsl:copy-of select="$start/@resp[normalize-space()]"/>
          <!--      <xsl:choose>
        <xsl:when test="$wrap.content[(tei:milestone|tei:anchor)[@subtype=('start', 'end')]]">
          <xsl:copy-of select="local:unanchor($wrap.content)"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:copy-of select="$wrap.content"/>
        </xsl:otherwise>
      </xsl:choose>-->
          <xsl:apply-templates select="$wrap.content" mode="diakrit2tags-prepare"/>
        </xsl:element>
        <!--    <xsl:apply-templates select="$node/node()[. >> $end]" mode="diakrit2tags-prepare"/>-->
        <xsl:variable name="rest">
          <local:wrapper>
            <xsl:copy-of select="$node/node()[. >> $end]"/>
          </local:wrapper>
        </xsl:variable>
        <xsl:apply-templates select="$rest" mode="diakrit2tags-prepare"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:apply-templates select="$node/node()[. &lt;&lt; $start or . is $start]" mode="diakrit2tags-prepare"/>
        <xsl:variable name="rest">
          <local:wrapper>
            <xsl:copy-of select="$node/node()[. >> $start]"/>
          </local:wrapper>
        </xsl:variable>
        <xsl:message>
          start: <xsl:copy-of select="$node/node()[. &lt;&lt; $start or . is $start]"/>
          rest: <xsl:copy-of select="$rest"/></xsl:message>
        <xsl:apply-templates select="$rest" mode="diakrit2tags-prepare"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>
  
  <!-- convert tei:choice with tei:del|tei:add to tei:subst -->
  <xsl:template match="tei:choice[tei:del]" mode="diakrit2tags-prepare">
    <subst>
      <xsl:apply-templates select="@*|node()" mode="#current"/>
    </subst>
  </xsl:template>
  
  <!-- convert tei:supplied-damage to tei:supplied[@reason='damage'] -->
  <xsl:template match="tei:supplied-damage" mode="diakrit2tags-prepare">
    <supplied reason="damage">
      <xsl:apply-templates select="@*|node()" mode="#current"/>
    </supplied>
  </xsl:template>

  <xsl:template match="local:test" mode="diakrit2tags-prepare" priority="10"/>
  
  <!-- find corresponding end milestone for boundary-crossing start marker, and link both -->
  <xsl:template match="tei:milestone[@subtype='start']" mode="diakrit2tags-finish">
    <xsl:variable name="start" select="."/>
    <xsl:variable name="end" select="$start/following::tei:anchor[@type=$start/@type][@subtype='end']
      [count(preceding::tei:milestone[. >> $start][@type = $start/@type][@subtype = $start/@subtype])  = count(preceding::tei:anchor[. >> $start][@type = $start/@type][@subtype = 'end'])][1]"/>
    <xsl:variable name="element.name" select="if (@type='editor') then 'milestone' else if (@n = 'del') then 'delSpan' else 'addSpan'"/>
    <xsl:copy>
      <xsl:apply-templates select="@*" mode="#current"/>
      <xsl:attribute name="xml:id">
        <xsl:value-of select="generate-id()"/>
      </xsl:attribute>
      <xsl:for-each select="$end">
        <xsl:attribute name="spanTo">
          <xsl:value-of select="concat('#', generate-id(.))"/>
        </xsl:attribute>
      </xsl:for-each>
    </xsl:copy>
  </xsl:template>
  
  <!-- find corresponding start milestone for boundary-crossing end marker, and link both -->
  <xsl:template match="tei:anchor[@subtype='end']" mode="diakrit2tags-finish">
    <xsl:variable name="end" select="."/>
    <xsl:variable name="start" select="$end/preceding::tei:milestone[@type=$end/@type][@subtype='start']
      [count(following::tei:anchor[. &lt;&lt; $end][@type = $end/@type][@subtype = $end/@subtype])  = count(following::tei:milestone[. &lt;&lt; $end][@type = $end/@type][@subtype = 'start'])][1]"/>
    <xsl:variable name="element.name" select="if (@type='editor') then 'milestone' else if (@n = 'del') then 'delSpan' else 'addSpan'"/>
    <xsl:copy>
      <xsl:apply-templates select="@*" mode="#current"/>
      <xsl:attribute name="xml:id">
        <xsl:value-of select="generate-id()"/>
      </xsl:attribute>
      <xsl:for-each select="$start">
        <xsl:attribute name="corresp">
          <xsl:value-of select="concat('#', generate-id(.))"/>
        </xsl:attribute>
      </xsl:for-each>
    </xsl:copy>
  </xsl:template>
  
  <!-- function that checks if a node can be wrapped (i.e. if it is sub-chunk level) -->
  <xsl:function name="local:inWrappableContext" as="xs:boolean">
    <xsl:param name="node"/>
    <xsl:value-of select="not($node[
      parent::tei:body|
      parent::tei:front|
      parent::tei:back|
      parent::tei:ab|
      parent::tei:div|
      parent::tei:opener|
      parent::tei:closer|
      parent::tei:postscript|
      parent::tei:lg
      ])"/>
  </xsl:function>
  
  <xsl:template match="@*|node()" priority="-1" mode="diakrit2tags-prepare diakrit2tags-finish">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()" mode="#current"/>
    </xsl:copy>
  </xsl:template>
  
</xsl:stylesheet>