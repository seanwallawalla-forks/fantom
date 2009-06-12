#! /usr/bin/env fan
//
// Copyright (c) 2009, Brian Frank and Andy Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   12 Jun 09  Brian Frank  Creation
//

using fand
using web
using webapp
using wisp
using compiler
using compilerJs

class Boot : BootScript
{
  override Service[] services :=
  [
    WispService
    {
      port = 8080
      pipeline = [FindResourceStep {}, FindViewStep {}, ServiceViewStep {}]
    }
  ]

  override Void setup()
  {
    Sys.ns.create(`/homePage`, Home#)
    Sys.ns.create(`/show-script`, ShowScript#)
  }
}

class Home : Widget
{
  File scriptDir := File(type->sourceFile->toUri->parent)
  override Void onGet()
  {
    res.headers["Content-Type"] = "text/html"
    out := res.out
    out.docType
    out.html
    out.head
      out.head.title.w("FWT Demo").titleEnd
    out.body
      out.h1.w("FWT Demo").h1End
      out.ul
      scriptDir.list.each |f|
      {
        if (f.ext == "fwt")
          out.li.a(`/show-script?$f.name`).w(f.name).aEnd.liEnd
      }
      out.ulEnd
    out.bodyEnd
    out.htmlEnd
  }
}

class ShowScript : Widget
{
  File scriptDir := File(type->sourceFile->toUri->parent)
  override Void onGet()
  {
    f := scriptDir + req.uri.queryStr.toUri
    if (!f.exists) { res.sendError(404); return }

    compile(f)
    qname := compiler.types[0].qname
    entryPoint := qname.replace("::", "_")

    res.headers["Content-Type"] = "text/html"
    out := res.out
    out.docType
    out.html
    out.head
      out.title.w("FWT Demo - $f.name").titleEnd
      out.includeJs(`/sys/pod/webappClient/webappClient.js`)
      out.includeJs(`/sys/pod/gfx/gfx.js`)
      out.includeJs(`/sys/pod/fwt/fwt.js`)
      out.style.w(
       "body { font: 10pt Arial; }
        a { color: #00f; }
        ").styleEnd
      out.script.w(js).w(
       "var hasRun = false;
        var shell  = null;
        var doLoad = function()
        {
          // safari appears to have a problem calling this event
          // twice, so make sure we short-circuit if already run
          if (hasRun) return;
          hasRun = true;

          // load fresco
          shell = ${entryPoint}.make();
          shell.open();
        }
        var doResize = function() { shell.relayout(); }
        if (window.addEventListener)
        {
          window.addEventListener('load', doLoad, false);
          window.addEventListener('resize', doResize, false);
        }
        else
        {
          window.attachEvent('onload', doLoad);
          window.attachEvent('onresize', doResize);
        }
        ").scriptEnd
    out.headEnd
    out.body
    out.bodyEnd
    out.htmlEnd
  }

  Void compile(File file)
  {
    input := CompilerInput.make
    input.podName        = file.basename
    input.version        = Version("0")
    input.description    = ""
    input.log.level      = LogLevel.error
    input.isScript       = true
    input.srcStr         = file.readAllStr
    input.srcStrLocation = Location.makeFile(file)
    input.mode           = CompilerInputMode.str
    input.output         = CompilerOutputMode.str
    this.compiler = JsCompiler(input)
    this.js = compiler.compile.str
  }

  JsCompiler? compiler
  Str? js
}

