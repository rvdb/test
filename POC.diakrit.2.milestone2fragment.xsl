<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:tei="http://www.tei-c.org/ns/1.0"
  xmlns:span="span"
  xmlns:local="local"
  xmlns="http://www.tei-c.org/ns/1.0"
  exclude-result-prefixes="#all"
  version="2.0">
  
  <!-- ==================================================== -->
  <!-- diakrit step 2:                                      -->
  <!-- convert start and end milestones to discrete,        -->
  <!-- linked fragmented spans of full content elements     -->
  <!-- ==================================================== -->
  <!-- e.g.: 
       <p>test an <milestone unit="choice" type="group" subtype="start"/><milestone unit="abbr" type="author" subtype="start"/>abbreviation<anchor type="author" subtype="end"/><milestone unit="expan" type="author" subtype="start"/>expansion<anchor type="author" subtype="end"/><anchor type="group" subtype="end"/> here</p>
       ==>
       <p>test an 
         <choice span:type="fragment" span:corresp="#d2e17" xml:id="d1e10.d1t12">
           <abbr span:type="fragment" span:corresp="#d2e13" xml:id="d1e11.d1t12">abbreviation</abbr>
         </choice>
         <choice span:type="fragment" span:corresp="#d2e17" xml:id="d1e10.d1t15">
           <expan span:type="fragment" span:corresp="#d2e16" xml:id="d1e14.d1t15">expansion</expan>
         </choice> 
       here</p>
  -->
  
  <!-- a key for more efficient location of corresponding end milestones -->
  <xsl:key name="span-end" match="tei:anchor[@subtype='end']" use="@xml:id"/>
  
  <xsl:template match="/">
    <xsl:apply-templates mode="wrapfragment"/>
  </xsl:template>
  
  <xsl:template match="tei:anchor|tei:milestone" mode="wrapfragment" priority="1"/>
  
  <!-- determine if elements or text need to be wrapped:
    -if so: wrap them in all "active" span markers at that point
    -if not: copy them 
  -->  
  <xsl:template match="*(:[not(self::tei:milestone[@subtype='start']|self::tei:anchor[@subtype='end'])]:)[local:inWrappableContext(.)][local:isSpanned(.)]|
    text()(:[local:inWrappableContext(.)]:)[local:isSpanned(.)][normalize-space()]
    " mode="wrapfragment">
    <!-- a stack of all "active" spans for the current node -->
    <xsl:param name="spans.active" as="node()*" tunnel="yes"/>
    <!-- determine if the node is inside a 'new' span (which has not already converted to a wrapper element -->
    <xsl:variable name="spans.new" select="local:isSpanned(.) except $spans.active"/>
    <!-- if a node is spanned, convert all "new" active spans to wrapper elements -->
    <xsl:choose>
      <xsl:when test="$spans.new[.]">
        <xsl:call-template name="wrap">
          <xsl:with-param name="wrap.content" select="." tunnel="yes"/>
          <xsl:with-param name="spans.new" select="$spans.new"/>          
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
    <xsl:variable name="node.root" select="$node/root()"/>
    <xsl:variable name="span.start" select="$node/preceding::tei:milestone[@subtype='start'][key('span-end', replace(@spanTo, '^#', ''), $node.root) >> $node]
      [. &lt;&lt; $node or not(preceding::node()
      [not(self::text()[not(normalize-space())])][1] >> $node)]
      "/>
    <xsl:if test="$span.start">
      <xsl:variable name="span.end" select="for $i in $span.start return key('span-end', replace($i/@spanTo, '^#', ''), $node.root)[. >> $i]
        [not(following::node()
        [not(self::text()[not(normalize-space())])][1] intersect $node/descendant::node())]"/>
      <!-- could also be done in 1 step by extending the predicate tests for $span.start, but a separate step improves transparency -->
      <xsl:variable name="span.start.balanced" select="$span.start[key('span-end', replace(@spanTo, '^#', ''), $node.root) intersect $span.end]"/>
      <xsl:if test="$span.start.balanced">
        <xsl:sequence select="$span.start.balanced"/>
        <xsl:sequence select="$span.end"/>
      </xsl:if>
    </xsl:if>
  </xsl:function>
  
  <!-- template that wraps a node in a (hierarchy of) wrapping element(s) -->
  <xsl:template name="wrap">
    <!-- the content to be wrapped -->
    <xsl:param name="wrap.content" tunnel="yes"/>
    <!-- all "active" spans for the current node -->
    <xsl:param name="spans.active" tunnel="yes" as="node()*"/>
    <!-- the "new" spans (that haven't been turned yet into wrapper elements) for a node -->
    <xsl:param name="spans.new" select="$spans.active"/>
    <!-- the start of the outermost "new" span -->
    <xsl:param name="currentSpan.start" select="$spans.new[@subtype='start'][1]"/>
    <!-- the end of the outermost "new" span -->
    <xsl:variable name="currentSpan.end" select="(key('span-end', $currentSpan.start/@spanTo/replace(., '^#', '')) intersect $spans.new)[1]"/>
    <xsl:choose>
      <!-- if there is a new span, wrap the contents in a (hierarchy of) wrapper element(s) -->
      <xsl:when test="$currentSpan.start">
        <xsl:element name="{$currentSpan.start/@unit}">
          <!-- only identify a fragmented span if the start and end are no siblings -->
          <xsl:if test="not($currentSpan.start/parent::*[local:inWrappableContext(.)] is $currentSpan.end/parent::*)">
            <!-- NOTE: this identification is crucial for later joining of connected spans ==> therefore, a reference to a more complex test is kept here, too -->
            <!--           
          <xsl:if test="$wrap.content[1] >> $currentSpan.start[not(following-sibling::node()[1] is $wrap.content[1]/ancestor-or-self::*[1])] or $wrap.content[last()] &lt;&lt; $currentSpan.end[not(preceding-sibling::node()[1] is $wrap.content[l]/ancestor-or-self::*[1])]">
-->
            <!-- identifies a span as a fragment of a bigger span -->
            <xsl:attribute name="span:type">
              <xsl:text>fragment</xsl:text>
            </xsl:attribute>
            <!-- identifies the corresponding fragments for the current span -->
            <xsl:attribute name="span:corresp">
              <xsl:value-of select="$currentSpan.start/@spanTo"/>
            </xsl:attribute>
          </xsl:if>
          <xsl:attribute name="xml:id">
            <xsl:value-of select="string-join(($currentSpan.start/generate-id(), generate-id()), '.')"/>
          </xsl:attribute>
          <xsl:copy-of select="$currentSpan.start/@resp"/>
          <!-- further traverse the hierarchy of "active" spans, until the content has been wrapped in the entire wrapping hierarchy -->
          <xsl:call-template name="wrap">
            <!-- remove the outermost milestone markers from the "new" stack -->
            <xsl:with-param name="spans.new" select="subsequence($spans.new, 2)"/>
            <!-- pass along the list of active spans for further processing -->
            <xsl:with-param name="spans.active" select="$spans.active|$spans.new" tunnel="yes"/>
          </xsl:call-template>
        </xsl:element>
      </xsl:when>
      <!-- if there are no (more) active spans, apply further processing to the content -->
      <xsl:otherwise>
        <xsl:apply-templates select="$wrap.content" mode="#current"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
    
  <xsl:template match="@*|node()" mode="wrapfragment" priority="-1">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()" mode="#current"/>
    </xsl:copy>
  </xsl:template>
  
  <!-- function that checks if a node can be wrapped (i.e. if it is at sub-chunk level) -->  
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