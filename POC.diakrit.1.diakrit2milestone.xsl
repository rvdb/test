<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:tei="http://www.tei-c.org/ns/1.0"
  xmlns="http://www.tei-c.org/ns/1.0"
  exclude-result-prefixes="#all"
  version="2.0">
  
  <!-- diakrit step 1:
    parse diacritical codes and transform them to milestone tags, indicating the start and end 
    -->
  
  <!-- regex for separator of author ID codes in diacritical start codes -->
  <xsl:variable name="regex.idsep">#</xsl:variable>
  <!-- regex for author ID codes in diacritical start codes -->
  <xsl:variable name="regex.id" select="concat('(', $regex.idsep, '([^', $regex.idsep, ']+)', $regex.idsep, ')?')"/>
  <!-- regex for diacritical omission markers -->
  <xsl:variable name="regex.gap">(x.*?|\.+?|…)</xsl:variable>
  <!-- regex for diacritical line ending markers -->
  <xsl:variable name="regex.lb">//</xsl:variable>
  <!-- regex for diacritical grouping markers -->
  <xsl:variable name="regex.group">([{{}}])</xsl:variable>
  
  <xsl:template match="/">
    <xsl:apply-templates mode="diakrit2milestone"/>
  </xsl:template>
  
  <!-- parse text and replace matching diacritical markers with milestone tags -->
  <xsl:template match="text()" mode="diakrit2milestone">
    <xsl:analyze-string select="." regex="\[{$regex.id}{$regex.gap}\]" flags="i">
      <xsl:matching-substring>
        <gap n="{regex-group(3)}" resp="{regex-group(2)}"/>
      </xsl:matching-substring>
      <xsl:non-matching-substring>
        <xsl:analyze-string select="." regex="{$regex.lb}">
          <xsl:matching-substring>
            <lb/>
          </xsl:matching-substring>
          <xsl:non-matching-substring>
            <xsl:analyze-string select="." regex="{$regex.group}{$regex.id}">
              <xsl:matching-substring>
                <xsl:choose>
                  <xsl:when test="regex-group(1) = '{'">
                    <milestone unit="choice" type="group" subtype="start">
                      <xsl:for-each select="normalize-space(regex-group(3))">
                        <xsl:attribute name="resp">
                          <xsl:value-of select="."/>
                        </xsl:attribute>
                      </xsl:for-each>
                    </milestone>
                  </xsl:when>
                  <xsl:otherwise>
                    <anchor type="group" subtype="end"/>
                  </xsl:otherwise>
                </xsl:choose> 
              </xsl:matching-substring>
              <xsl:non-matching-substring>
                <xsl:analyze-string select="." regex="\[(:\+?|\+|-|\?|=){$regex.id}">
                  <xsl:matching-substring>
                    <xsl:variable name="tag">
                      <xsl:choose>
                        <xsl:when test="regex-group(1) = (':+', ':')">supplied-damage</xsl:when>
                        <xsl:when test="regex-group(1) = '+'">supplied</xsl:when>
                        <xsl:when test="regex-group(1) = '-'">orig</xsl:when>
                        <xsl:when test="regex-group(1) = '?'">unclear</xsl:when>                <xsl:when test="regex-group(1) = '='">expan</xsl:when>
                      </xsl:choose>
                    </xsl:variable>
                    <milestone unit="{$tag}" type="editor" subtype="start" resp="{regex-group(3)}">
                      <xsl:for-each select="normalize-space(regex-group(3))">
                        <xsl:attribute name="resp">
                          <xsl:value-of select="."/>
                        </xsl:attribute>
                      </xsl:for-each>
                    </milestone>
                  </xsl:matching-substring>
                  <xsl:non-matching-substring>
                    <xsl:analyze-string select="." regex="&lt;(\+|-|=){$regex.id}">
                      <xsl:matching-substring>
                        <xsl:variable name="tag">
                          <xsl:choose>
                            <xsl:when test="regex-group(1) = '+'">add</xsl:when>
                            <xsl:when test="regex-group(1) = '-'">del</xsl:when>
                            <xsl:when test="regex-group(1) = '='">abbr</xsl:when>
                          </xsl:choose>
                        </xsl:variable>
                        <milestone unit="{$tag}" type="author" subtype="start">
                          <xsl:for-each select="normalize-space(regex-group(3))">
                            <xsl:attribute name="resp">
                              <xsl:value-of select="."/>
                            </xsl:attribute>
                          </xsl:for-each>
                        </milestone>
                      </xsl:matching-substring>
                      <xsl:non-matching-substring>
                        <xsl:analyze-string select="." regex="(\]|>)">
                          <xsl:matching-substring>
                            <anchor type="{if (regex-group(1) = ']') then 'editor' else 'author'}" subtype="end"/>
                          </xsl:matching-substring>
                          <xsl:non-matching-substring>
                            <xsl:value-of select="."/>
                          </xsl:non-matching-substring>
                        </xsl:analyze-string>
                      </xsl:non-matching-substring>
                    </xsl:analyze-string>
                  </xsl:non-matching-substring>
                </xsl:analyze-string>
              </xsl:non-matching-substring>
            </xsl:analyze-string>
          </xsl:non-matching-substring>
        </xsl:analyze-string>
      </xsl:non-matching-substring>
    </xsl:analyze-string>
  </xsl:template>
  
  <xsl:template match="@*|node()" priority="-1" mode="diakrit2milestone">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()" mode="#current"/>
    </xsl:copy>
  </xsl:template>
  
</xsl:stylesheet>