<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:span="span"
  xmlns:tei="http://www.tei-c.org/ns/1.0"
  xmlns="http://www.tei-c.org/ns/1.0"
  exclude-result-prefixes="#all"
  version="2.0">
  
  <!-- ==================================================== -->
  <!-- diakrit step 3:                                      -->
  <!-- merge adjacent spans and their contents, and link    -->
  <!-- discontinuous spans                                  -->
  <!-- ==================================================== -->
  <!-- e.g.: 
       <p>test an 
         <choice span:type="fragment" span:corresp="#d2e17" xml:id="d1e10.d1t12">
           <abbr span:type="fragment" span:corresp="#d2e13" xml:id="d1e11.d1t12">abbreviation</abbr>
         </choice>
         <choice span:type="fragment" span:corresp="#d2e17" xml:id="d1e10.d1t15">
           <expan span:type="fragment" span:corresp="#d2e16" xml:id="d1e14.d1t15">expansion</expan>
         </choice> 
       here</p>
       ==>
       <p>test an 
         <choice>
           <abbr>abbreviation</abbr>
           <expan>expansion</expan>
         </choice> 
       here</p>
  -->  
  <xsl:param name="debug" select="false()" as="xs:boolean"/>
  
  <xsl:template match="/">
    <xsl:call-template name="fragment2span"/>
  </xsl:template>
  
  <!-- 2 passes:
    -fragment-merge: join adjacent spans, and their contents
    -fragment-link: link discontinuous span fragments with @next|@prev attributes
  -->
  <xsl:template name="fragment2span">
    <xsl:variable name="fragment-merge">
      <xsl:apply-templates select="." mode="fragment-merge"/>
    </xsl:variable>
    <xsl:apply-templates select="$fragment-merge" mode="fragment-link"/>
  </xsl:template>
  
  <!-- trigger regrouping mode for contents of elements containing span fragments -->
  <xsl:template match="*[*/@span:type='fragment']" mode="fragment-merge">
    <xsl:copy>
      <xsl:apply-templates select="@*" mode="#current"/>
      <xsl:call-template name="fragment-merge"/>
    </xsl:copy>
  </xsl:template>

  <!-- recursively join adjacent parts of fragmented spans, and their contents -->
  <xsl:template name="fragment-merge">
    <xsl:param name="context" select="node()"/>
    <!-- find all adjacent fragments with equal @span:corr values (and intervening empty text nodes) -->
    <!-- NOTE: 
      -string(): makes it possible to find groups in "mixed" node sets (even if they don't have a @span:corresp attribute) 
      -for empty text nodes: if they are enclosed between adjacent span fragments, use their @span:corresp value to include them in the current group 
    -->
    <xsl:for-each-group select="$context" group-adjacent="string(self::*/@span:corresp|
      self::text()[not(normalize-space())][preceding-sibling::node()[1][@span:type='fragment'][@span:corresp]/@span:corresp = following-sibling::node()[1][@span:type='fragment'][@span:corresp]/@span:corresp]
      /preceding-sibling::node()[1][@span:type='fragment'][@span:corresp]/@span:corresp)">
      <xsl:choose>
        <!-- for matching group: 
          -copy outer element
          -repeat merge for all descendant span fragments
          -->
        <xsl:when test="current-group()[@span:type='fragment'] and current-grouping-key()(:[normalize-space()]:)">
          <xsl:element name="{(current-group()/self::*)[1]/name()}">
            <xsl:apply-templates select="current-group()[1]/@*" mode="#current"/>
            <!-- child nodes have to be isolated as siblings in a new variable: otherwise they won't be recognised as adjacent nodes in a new merge operation -->
            <!-- NOTE: the slightly complicated selection is needed to include both child nodes of elements in the current group and (whitespace) text nodes of the current group
            -->
            <xsl:variable name="newcontext">
              <xsl:copy-of select="current-group()/(self::*/node()|self::node()[not(self::*)])"/>
            </xsl:variable>
            <xsl:call-template name="fragment-merge">
              <xsl:with-param name="context" select="$newcontext/node()"/>
            </xsl:call-template>
          </xsl:element>
        </xsl:when>
        <!-- for non-matching elements: just apply further processing -->
        <xsl:otherwise>
          <xsl:apply-templates select="current-group()" mode="#current"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:for-each-group>
  </xsl:template>
  
  <!-- convert tei:choice with tei:del|tei:add to tei:subst -->
  <xsl:template match="tei:choice[tei:del][tei:add]" mode="fragment-link">
    <subst>
      <xsl:choose>
        <xsl:when test="@span:type='fragment'">
          <xsl:call-template name="regroup-attributes"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:apply-templates select="@*" mode="#current"/>
        </xsl:otherwise>
      </xsl:choose>
      <xsl:apply-templates select="@*|node()" mode="#current"/>
    </subst>
  </xsl:template>
  
  <!-- convert tei:supplied-damage to tei:supplied[@reason='damage'] -->
  <xsl:template match="tei:supplied-damage" mode="fragment-link">
    <supplied reason="damage">
      <xsl:choose>
        <xsl:when test="@span:type='fragment'">
          <xsl:call-template name="regroup-attributes"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:apply-templates select="@*" mode="#current"/>
        </xsl:otherwise>
      </xsl:choose>
      <xsl:apply-templates select="@*|node()" mode="#current"/>
    </supplied>
  </xsl:template>

  <xsl:template match="*[@span:type='fragment']" mode="fragment-link" priority="-.5">
    <xsl:copy copy-namespaces="no">
      <xsl:call-template name="regroup-attributes"/>
      <xsl:apply-templates select="node()" mode="#current"/>
    </xsl:copy>
  </xsl:template>
  
  <!-- create @next and @prev attributes for discontinuous span fragments -->
  <xsl:template name="regroup-attributes">
    <xsl:variable name="span.prev" select="preceding::*[@span:type=('fragment'(:, 'group':))][@span:corresp = current()/@span:corresp]"/>
    <xsl:variable name="span.next" select="following::*[@span:type='fragment'][@span:corresp = current()/@span:corresp]"/>
      <xsl:apply-templates select="@* except @span:*" mode="#current"/>
      <xsl:if test="$span.next|$span.prev">
        <xsl:apply-templates select="@span:*" mode="#current"/>
      </xsl:if>
      <xsl:variable name="counter" select="count($span.prev) + 1"/>
      <xsl:attribute name="xml:id">
        <xsl:value-of select="string-join((replace(@span:corresp, '^#', ''), string($counter)), '.')"/>
      </xsl:attribute>
      <xsl:if test="$span.prev and $counter > 1">
        <xsl:attribute name="prev">
          <xsl:value-of select="string-join((@span:corresp, string($counter - 1)), '.')"/>
        </xsl:attribute>
      </xsl:if>
      <xsl:if test="$span.next">
        <xsl:attribute name="next">
          <xsl:value-of select="string-join((@span:corresp, string($counter + 1)), '.')"/>
        </xsl:attribute>
      </xsl:if>
  </xsl:template>
  
  <xsl:template match="@span:*" mode="fragment-link">
    <xsl:if test="$debug">
      <xsl:copy-of select="."/>
    </xsl:if>
  </xsl:template>
  
  <xsl:template match="@*|node()" priority="-1" mode="fragment-merge fragment-link">
    <xsl:copy copy-namespaces="no">
      <xsl:apply-templates select="@*|node()" mode="#current"/>
    </xsl:copy>
  </xsl:template>
  
</xsl:stylesheet>