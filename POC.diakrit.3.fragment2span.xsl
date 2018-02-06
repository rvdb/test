<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:span="http://ctb.kantl.be/span"
  xmlns:tei="http://www.tei-c.org/ns/1.0"
  xmlns="http://www.tei-c.org/ns/1.0"
  exclude-result-prefixes="#all"
  version="2.0">
  
  <!-- diakrit step 3:
    join adjacent spans 
    -->
  
  <xsl:param name="debug" select="false()" as="xs:boolean"/>
  
  <xsl:template match="/">
    <xsl:call-template name="fragment2span"/>
  </xsl:template>
  
  <xsl:template name="fragment2span">
    <xsl:variable name="fragment-merge">
      <xsl:apply-templates select="." mode="fragment-merge"/>
    </xsl:variable>
    <xsl:apply-templates select="$fragment-merge" mode="fragment-link"/>
  </xsl:template>
  
  <xsl:template match="*[*/@span:type='span']" mode="fragment-merge">
    <xsl:copy>
      <xsl:apply-templates select="@*" mode="#current"/>
      <xsl:call-template name="fragment-merge">
<!--        <xsl:with-param name="context" select="node()"/>
-->      </xsl:call-template>
    </xsl:copy>
  </xsl:template>
  
  <xsl:template match="@span:type[. = 'span']" mode="fragment-merge">
    <xsl:attribute name="{name()}">
      <xsl:text>group</xsl:text>
    </xsl:attribute>
  </xsl:template>

  <xsl:template name="fragment-merge">
    <xsl:param name="context" select="node()"/>
      <xsl:for-each-group select="$context" group-adjacent="boolean(self::*[@span:type='span'][@span:corresp][@span:corresp = (preceding-sibling::node()[not(self::text()[not(normalize-space())])][1]|following-sibling::node()[not(self::text()[not(normalize-space())])][1])[@span:type='span'][@span:corresp]/@span:corresp] or self::text()[not(normalize-space())][preceding-sibling::node()[1][@span:type='span'][@span:corresp]/@span:corresp = following-sibling::node()[1][@span:type='span'][@span:corresp]/@span:corresp])">    
        
      <xsl:choose>
        <xsl:when test="current-group()[@span:type='span'] and current-grouping-key()(:[normalize-space()]:)">
          <xsl:element name="{(current-group()/self::*)[1]/name()}">
            <xsl:apply-templates select="current-group()[1]/@*" mode="#current"/>
            <xsl:variable name="newcontext">
              <xsl:copy-of select="current-group()/(self::*/node()|self::node()[not(self::*)])"/>
              </xsl:variable>
                            
              <xsl:call-template name="fragment-merge">
                <xsl:with-param name="context" select="$newcontext/node()"/>
              </xsl:call-template>

          </xsl:element>
        </xsl:when>
        <xsl:otherwise>
          <!--<KJIKKIJK><xsl:copy-of select="current-group()"/></KJIKKIJK>            
-->            <xsl:apply-templates select="current-group()" mode="#current"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:for-each-group>
  </xsl:template>
    
  <!-- convert tei:choice with tei:del|tei:add to tei:subst -->
  <xsl:template match="tei:choice[tei:del]" mode="fragment-link">
    <subst>
      <xsl:choose>
        <xsl:when test="@span:type=('span', 'group')">
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
        <xsl:when test="@span:type=('span', 'group')">
          <xsl:call-template name="regroup-attributes"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:apply-templates select="@*" mode="#current"/>
        </xsl:otherwise>
      </xsl:choose>
      <xsl:apply-templates select="@*|node()" mode="#current"/>
    </supplied>
  </xsl:template>
  
  <xsl:template match="*[@span:type=('span', 'group')]" mode="fragment-link" priority="-.5">
    <xsl:copy copy-namespaces="no">
      <xsl:call-template name="regroup-attributes"/>
      <xsl:apply-templates select="node()" mode="#current"/>
    </xsl:copy>
  </xsl:template>
  
  <xsl:template name="regroup-attributes">
    <xsl:variable name="span.prev" select="preceding::*[@span:type=('span', 'group')][@span:corresp = current()/@span:corresp]"/>
    <xsl:variable name="span.next" select="following::*[@span:type=('span', 'group')][@span:corresp = current()/@span:corresp]"/>
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