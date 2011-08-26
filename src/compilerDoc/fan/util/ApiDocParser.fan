//
// Copyright (c) 2011, Brian Frank and Andy Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   11 Aug 11  Brian Frank  Creation
//

**
** ApiDocParser is used to parse the text file syntax of the
** apidoc file generated by the compiler.  These files are
** designed to give us full access everything we need to build
** a documentation model of pods, types, and slots using a
** simple human readable format.
**
** The syntax is defined as:
**   <file>      :=  <type> ["\n" <slot>]*
**   <type>      :=  <facets> <attrs> <flags> "class " <id> [<inherit>] "\n" <doc>
**   <inherit>   :=  ":" [<typeRef> ","]*
**   <slot>      :=  <facets> <attrs> <flags> <slotSig> "\n" <doc>
**   <slotSig>   :=  <fieldSig> | <methodSig>
**   <fieldSig>  :=  <typeRef> " " <id> [":=" <expr>"]
**   <methodSig> :=  <typeRef> " " <id> "(" "\n" [<param> "\n"]* ")"
**   <param>     :=  <typeRef> <id> [":=" <expr>]
**   <doc>       :=  lines of text, empty lines indicated with "\"
**   <flags>     :=  [<flag> " "]*
**   <flag>      :=  standard Fantom flag keywords (public, const, etc)
**   <facets>    :=  [<facet> "\n"]*
**   <facet>     :=  "@" <type> [" {\n" [<id> "=" <expr> "\n"]* "}"]
**   <attrs>     :=  [<attr> "\n"]*
**   <attr>      :=  "%" <id> "=" <expr> "\n"
**   <expr>      :=  text until end of line
**   <id>        :=  Fantom identifier
**   <typeRef>   :=  Fantom type signature (no spaces allowed)
**
** Note spaces are significant.  Extra whitespace is not allowed.
** Also note that the grammar is defined such that expr to display
** in docs for field and parameter defaults is always positioned at
** the end of the line (avoiding nasty escaping problems).
**
** The following attributes are supported:
**   file: type source file name (slots implied by type's file)
**   line: integer line number of type/slot definition
**   docLine: first non-empty starting line of fandoc in source file
**
internal class ApiDocParser
{
  new make(Str podName, InStream in)
  {
    this.podName = podName
    this.in = in
    consumeLine
  }

  DocType parseType(Bool close := true)
  {
    try
    {
      // header
      parseTypeHeader

      // zero or more slots
      while (parseSlot) {}

      // sort slots by name
      slots.sort |a, b| { a.name <=> b.name }

      // construct DocType from my own fields
      return DocType
      {
        it.loc    = this.loc
        it.ref    = this.ref
        it.flags  = this.flags
        it.doc    = this.doc
        it.facets = this.facets
        it.base   = this.base
        it.mixins = this.mixins
        it.slots  = this.slots
      }
    }
    finally { if (close) in.close }
  }

  private Void parseTypeHeader()
  {
    // facets
    this.facets = parseFacets

    // attrs
    attrs := parseAttrs
    this.loc = attrs.loc

    // <flags> "class" <name> [":" extends]
    colon := cur.index(":")
    toks := (colon == null ? cur : cur[0..<colon]).split
    name := toks[-1]
    this.ref = DocTypeRef.makeSimple(podName, name)

    // parse flags
    flags := 0
    if (toks[-2] == "mixin") flags = DocFlags.Mixin
    toks.eachRange(0..-3) |flagName|
    {
      flags = flags.or(DocFlags.fromName(flagName))
    }
    this.flags = flags
    isMixin := flags.and(DocFlags.Mixin) != 0

    // extends
    if (colon == null)
    {
      if (!(podName == "sys" && name == "Obj") && !isMixin)
        this.base = DocTypeRef("sys::Obj")
    }
    else
    {
      typesSigs := cur[colon+1..-1].split(',')
      types := typesSigs.map |sig->DocTypeRef| { DocTypeRef(sig) }
      if (isMixin)
      {
        // mixins don't include base type
        this.mixins = types
      }
      else
      {
        // base class always first
        this.base   = types.first
        this.mixins = types[1..-1]
      }
    }

    // ready to parse doc
    consumeLine
    this.doc = parseDoc(attrs)
  }

  private Bool parseSlot()
  {
    // check if at end of file
    if (cur.isEmpty) return false

    // facets, loc
    facets := parseFacets
    attrs := parseAttrs

    if (cur[-1] == '(')
      slots.add(parseMethod(attrs, facets))
    else
      slots.add(parseField(attrs, facets))
    return true
  }

  private DocField parseField(DocAttrs attrs, DocFacet[] facets)
  {
    // cur is: <flags> <type> <name> [":=" <expr>]

    // first parse out init expression
    working   := this.cur
    Str? init := null
    initi := working.index(":=")
    if (initi != null)
    {
      init    = working[initi+2..-1]
      working = working[0..<initi]
    }

    // tokenize by space
    toks := working.split
    name := toks[-1]
    type := DocTypeRef(toks[-2])

    // tokens 0 to -3 are flags
    flags := 0
    toks.eachRange(0..-3) |tok| { flags = flags.or(DocFlags.fromName(tok)) }

    // parse fandoc
    consumeLine
    doc := parseDoc(attrs)

    return DocField(attrs, ref, name, flags, doc, facets, type, init)
  }

  private DocMethod parseMethod(DocAttrs attrs, DocFacet[] facets)
  {
    // cur is: <flags> <type> <name> "("

    // tokenize by space
    toks := cur.split
    name := toks[-1][0..-2]
    returns := DocTypeRef(toks[-2])

    // tokens 0 to -3 are flags
    flags := 0
    toks.eachRange(0..-3) |tok| { flags = flags.or(DocFlags.fromName(tok)) }

    // parse params
    params := DocParam[,]
    consumeLine
    while (cur != ")")
    {
      space := cur.index(" ")
      defi  := cur.index(":=", space+2)
      type  := DocTypeRef(cur[0..<space])
      pname := cur[space+1 ..< (defi ?: cur.size)]
      def   := defi == null ? null : cur[defi+2..-1]

      params.add(DocParam(type, pname, def))
      consumeLine
    }
    consumeLine  // trailing ")"

    // consume current line and parse docs
    doc := parseDoc(attrs)

    return DocMethod(attrs, ref, name, flags, doc, facets, returns, params)
  }

  private DocFacet[] parseFacets()
  {
    facet := parseFacet
    if (facet == null) return DocFacet#.emptyList
    acc := [facet]
    while ((facet = parseFacet) != null) acc.add(facet)
    return acc
  }

  private DocFacet? parseFacet()
  {
    if (!cur.startsWith("@")) return null

    complex := cur[-1] == '{'
    typeEnd := complex ? -3 : -1
    type := DocTypeRef(cur[1..typeEnd])
    fields := DocFacet.noFields

    consumeLine
    if (complex)
    {
      fields = Str:Str[:]
      fields.ordered = true
      while (cur != "}")
      {
        eq := cur.index("=")
        name := cur[0..<eq]
        val  := cur[eq+1..-1]
        fields[name] = val
        consumeLine
      }
      consumeLine  // trailing "}"
    }

    return DocFacet(type, fields)
  }

  private DocAttrs parseAttrs()
  {
    attrs := DocAttrs()

    // the only attributes we care about are location (file, line)
    Str? file    := null
    Int? line    := null
    Int? docLine := null
    while (cur.startsWith("%"))
    {
      eq   := cur.index("=")
      name := cur[1..<eq]
      val  := cur[eq+1..-1]
      if (name == "line") line = val.toInt
      else if (name == "docLine") docLine = val.toInt
      else if (name == "file") file = val
      else if (name == "set") attrs.setterFlags = DocFlags.fromNames(val)
      consumeLine
    }

    // create or default docLoc
    if (docLine != null)
      attrs.docLoc = DocLoc(file ?: this.loc.file, docLine)
    else
      attrs.docLoc = DocLoc(this.loc.file, 1)

    // if file was specified then new fresh location
    // otherwise we derive file location from type definition
    if (file != null)
      attrs.loc = DocLoc("${podName}::${file}", line)
    else
      attrs.loc = DocLoc(this.loc.file, line)

    return attrs
  }

  private DocFandoc parseDoc(DocAttrs attrs)
  {
    if (cur.isEmpty) { consumeLine; return DocFandoc(attrs.docLoc, "") }
    s := StrBuf(256)
    while (!cur.isEmpty)
    {
      if (cur != "\\") s.add(cur)
      s.addChar('\n')
      consumeLine
    }
    consumeLine
    return DocFandoc(attrs.docLoc, s.toStr)
  }

  private Void consumeLine()
  {
    cur = in.readLine ?: ""
  }

  private InStream in
  private const Str podName
  private Str cur := ""
  private DocTypeRef? ref
  private Int flags
  private DocLoc loc := DocLoc("Unknown", 0)
  private DocFandoc? doc
  private DocFacet[]? facets
  private DocTypeRef? base
  private DocTypeRef[] mixins := [,]
  private DocSlot[] slots := [,]
}

internal class DocAttrs
{
  DocLoc? loc
  DocLoc? docLoc
  Int? setterFlags
}