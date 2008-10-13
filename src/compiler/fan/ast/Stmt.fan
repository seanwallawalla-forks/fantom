//
// Copyright (c) 2006, Brian Frank and Andy Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   19 Jul 06  Brian Frank  Creation
//

**
** Stmt
**
abstract class Stmt : Node
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  new make(Location location, StmtId id)
    : super(location)
  {
    this.id = id
  }

//////////////////////////////////////////////////////////////////////////
// Stmt
//////////////////////////////////////////////////////////////////////////

  **
  ** Does this statement always cause us to exit the method (or does it
  ** cause us to loop forever without a break to the next statement)
  **
  abstract Bool isExit()

//////////////////////////////////////////////////////////////////////////
// Tree
//////////////////////////////////////////////////////////////////////////

  Void walk(Visitor v, VisitDepth depth)
  {
    v.enterStmt(this)
    walkChildren(v, depth)
    v.visitStmt(this)
    v.exitStmt(this)
  }

  virtual Void walkChildren(Visitor v, VisitDepth depth)
  {
  }

  static Expr walkExpr(Visitor v, VisitDepth depth, Expr expr)
  {
    if (depth === VisitDepth.expr && expr != null)
      return expr.walk(v)
    else
      return expr
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  readonly StmtId id

}

**************************************************************************
** NopStmt
**************************************************************************

**
** NopStmt is no operation do nothing statement.
**
class NopStmt : Stmt
{
  new make(Location location) : super(location, StmtId.nop) {}

  override Bool isExit() { return false }

  override Void print(AstWriter out)
  {
    out.w("nop").nl
  }
}

**************************************************************************
** ExprStmt
**************************************************************************

**
** ExprStmt is a statement with a stand along expression such
** as an assignment or method call.
**
class ExprStmt : Stmt
{
  new make(Expr expr)
    : super(expr.location, StmtId.expr)
  {
    this.expr = expr
  }

  override Bool isExit() { return false }

  override Void walkChildren(Visitor v, VisitDepth depth)
  {
    expr = walkExpr(v, depth, expr)
  }

  override Void print(AstWriter out)
  {
    printOpt(out)
  }

  Void printOpt(AstWriter out, Bool nl := true)
  {
    expr.print(out)
    if (nl) out.nl
  }

  Expr expr
}

**************************************************************************
** LocalDefStmt
**************************************************************************

**
** LocalDefStmt models a local variable declaration and its
** optional initialization expression.
**
class LocalDefStmt : Stmt
{
  new make(Location location)
    : super(location, StmtId.localDef)
  {
    isCatchVar = false
  }

  override Bool isExit() { return false }

  override Void walkChildren(Visitor v, VisitDepth depth)
  {
    init = walkExpr(v, depth, init)
  }

  new makeCatchVar(Catch c)
    : super.make(c.location, StmtId.localDef)
  {
    ctype = c.errType
    name  = c.errVariable
    isCatchVar = true
  }

  override Void print(AstWriter out) { printOpt(out) }

  Void printOpt(AstWriter out, Bool nl := true)
  {
    if (ctype != null) out.w("$ctype ")
    out.w(name)
    if (init != null) out.w(" init: $init")
    if (nl) out.nl
  }

  CType ctype       // type of the variable (or null if inferred)
  Str name          // variable name
  Expr init         // rhs of init; in ResolveExpr it becomes full assign expr
  Bool isCatchVar   // is this auto-generated var for "catch (Err x)"
  MethodVar var     // variable binding
}

**************************************************************************
** IfStmt
**************************************************************************

**
** IfStmt models an if or if/else statement.
**
class IfStmt : Stmt
{
  new make(Location location) : super(location, StmtId.ifStmt) {}

  override Bool isExit()
  {
    if (falseBlock == null) return false
    return trueBlock.isExit && falseBlock.isExit
  }

  override Void walkChildren(Visitor v, VisitDepth depth)
  {
    condition = walkExpr(v, depth, condition)
    trueBlock.walk(v, depth)
    if (falseBlock != null) falseBlock.walk(v, depth)
  }

  override Void print(AstWriter out)
  {
    out.w("if ($condition)").nl
    trueBlock.print(out)
    if (falseBlock != null)
    {
      out.w("else").nl
      falseBlock.print(out)
    }
  }

  Expr condition      // test expression
  Block trueBlock     // block to execute if condition true
  Block falseBlock    // else clause or null
}

**************************************************************************
** ReturnStmt
**************************************************************************

**
** ReturnStmt returns from the method
**
class ReturnStmt : Stmt
{
  new make(Location location, Expr? expr := null)
    : super(location, StmtId.returnStmt)
  {
    this.expr = expr
  }

  override Bool isExit() { return true }

  override Void walkChildren(Visitor v, VisitDepth depth)
  {
    expr = walkExpr(v, depth, expr)
  }

  override Void print(AstWriter out)
  {
    out.w("return")
    if (expr != null) out.w(" $expr")
    out.nl
  }


  Expr? expr          // expr to return of null if void return
  MethodVar leaveVar  // to stash result for leave from protected region
}

**************************************************************************
** ThrowStmt
**************************************************************************

**
** ThrowStmt throws an exception
**
class ThrowStmt : Stmt
{
  new make(Location location) : super(location, StmtId.throwStmt) {}

  override Bool isExit() { return true }

  override Void walkChildren(Visitor v, VisitDepth depth)
  {
    exception = walkExpr(v, depth, exception)
  }

  override Void print(AstWriter out)
  {
    out.w("throw $exception").nl
  }

  Expr exception   // exception to throw
}

**************************************************************************
** ForStmt
**************************************************************************

**
** ForStmt models a for loop of the format:
**   for (init; condition; update) block
**
class ForStmt : Stmt
{
  new make(Location location) : super(location, StmtId.forStmt) {}

  override Bool isExit()
  {
    return false
  }

  override Void walkChildren(Visitor v, VisitDepth depth)
  {
    if (init != null) init.walk(v, depth)
    condition = walkExpr(v, depth, condition)
    update = walkExpr(v, depth, update)
    block.walk(v, depth)
  }

  override Void print(AstWriter out)
  {
    out.w("for (")
    if (init != null) init->printOpt(out, false)
    out.w("; ")
    if (condition != null) condition.print(out)
    out.w("; ")
    if (update != null) update.print(out)
    out.w(")").nl
    block.print(out)
  }

  Stmt init         // loop initialization
  Expr condition    // loop condition
  Expr update       // loop update
  Block block       // code to run inside loop
}

**************************************************************************
** WhileStmt
**************************************************************************

**
** WhileStmt models a while loop of the format:
**   while (condition) block
**
class WhileStmt : Stmt
{
  new make(Location location) : super(location, StmtId.whileStmt) {}

  override Bool isExit()
  {
    return false
  }

  override Void walkChildren(Visitor v, VisitDepth depth)
  {
    condition = walkExpr(v, depth, condition)
    block.walk(v, depth)
  }

  override Void print(AstWriter out)
  {
    out.w("while ($condition)").nl
    block.print(out)
  }

  Expr condition     // loop condition
  Block block        // code to run inside loop
}

**************************************************************************
** BreakStmt
**************************************************************************

**
** BreakStmt breaks out of a while/for loop.
**
class BreakStmt : Stmt
{
  new make(Location location) : super(location, StmtId.breakStmt) {}

  override Bool isExit() { return false }

  override Void print(AstWriter out)
  {
    out.w("break").nl
  }

   Stmt loop   // loop to break out of
}

**************************************************************************
** ContinueStmt
**************************************************************************

**
** ContinueStmt continues a while/for loop.
**
class ContinueStmt : Stmt
{
  new make(Location location) : super(location, StmtId.continueStmt) {}

  override Bool isExit() { return false }

  override Void print(AstWriter out)
  {
    out.w("continue").nl
  }

  Stmt loop   // loop to continue
}

**************************************************************************
** TryStmt
**************************************************************************

**
** TryStmt models a try/catch/finally block
**
class TryStmt : Stmt
{
  new make(Location location)
    : super(location, StmtId.tryStmt)
  {
    catches = Catch[,]
  }

  override Bool isExit()
  {
    if (!block.isExit) return false
    return catches.all |Catch c->Bool| { return c.block.isExit }
  }

  override Void walkChildren(Visitor v, VisitDepth depth)
  {
    block.walk(v, depth)
    catches.each |Catch c| { c.block.walk(v, depth) }
    if (finallyBlock != null)
    {
      v.enterFinally(this)
      finallyBlock.walk(v, depth)
      v.exitFinally(this)
    }
  }

  override Void print(AstWriter out)
  {
    out.w("try").nl
    block.print(out)
    catches.each |Catch c| { c.print(out) }
    if (finallyBlock != null)
    {
      out.w("finally").nl
      finallyBlock.print(out)
    }
  }

  Expr exception      // expression which leaves exception on stack
  Block block         // body of try block
  Catch[] catches     // list of catch clauses
  Block finallyBlock  // body of finally block or null
}

**
** Catch models a single catch clause of a TryStmt
**
class Catch : Node
{
  new make(Location location) : super(location) {}

  override Void print(AstWriter out)
  {
    out.w("catch")
    if (errType != null) out.w("($errType $errVariable)")
    out.nl
    block.print(out)
  }

  TypeRef errType      // Err type to catch or null for catch-all
  Str errVariable      // name of err local variable
  Block block          // body of catch block
  Int start            // start offset generated in CodeAsm
  Int end              // end offset generated in CodeAsm
}

**************************************************************************
** SwitchStmt
**************************************************************************

**
** SwitchStmt models a switch and its case and default block
**
class SwitchStmt : Stmt
{
  new make(Location location)
    : super(location, StmtId.switchStmt)
  {
    cases = Case[,]
  }

  override Bool isExit()
  {
    if (defaultBlock == null) return false
    if (!defaultBlock.isExit) return false
    return cases.all |Case c->Bool| { return c.block.isExit }
  }

  override Void walkChildren(Visitor v, VisitDepth depth)
  {
    condition = walkExpr(v, depth, condition)
    cases.each |Case c| { c.walk(v, depth) }
    if (defaultBlock != null) defaultBlock.walk(v, depth)
  }

  override Void print(AstWriter out)
  {
    out.w("switch ($condition)").nl
    out.w("{").nl
    out.indent
    cases.each |Case c| { c.print(out) }
    if (defaultBlock != null)
    {
      out.w("default:").nl
      out.indent
      defaultBlock.printOpt(out, false)
      out.unindent
    }
    out.unindent
    out.w("}").nl
  }

  Expr condition        // test expression
  Case[] cases          // list of case blocks
  Block defaultBlock    // default block (or null)
  Bool isTableswitch    // just for testing
}

**
** Case models a single case block of a SwitchStmt
**
class Case : Node
{
  new make(Location location)
    : super(location)
  {
    cases = Expr[,]
  }

  Void walk(Visitor v, VisitDepth depth)
  {
    if (depth === VisitDepth.expr)
      cases = Expr.walkExprs(v, cases)

    block.walk(v, depth)
  }

  override Void print(AstWriter out)
  {
    cases.each |Expr c| { out.w("case $c:").nl }
    out.indent
    if (block != null) block.printOpt(out, false)
    out.unindent
  }

  Expr[] cases     // list of case target (literal expressions)
  Block block      // code to run for case
  Int startOffset  // start offset for CodeAsm
}

**************************************************************************
** StmtId
**************************************************************************

enum StmtId
{
  nop,
  expr,
  localDef,
  ifStmt,
  returnStmt,
  throwStmt,
  forStmt,
  whileStmt,
  breakStmt,
  continueStmt,
  tryStmt,
  switchStmt
}