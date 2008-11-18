//
// Copyright (c) 2008, Brian Frank and Andy Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   17 Nov 08  Brian Frank  Creation
//

**
** CBridge is the base class for compiler FFI plugins to expose
** external type systems to the Fan compiler as CPods, CTypes, and
** CSlots.  Subclasses are registered for with the "compilerBridge"
** facet and must declare a constructor with a CNamespace arg.
**
abstract class CBridge
{

  **
  ** Resolve the specified foreign namespace to a CPod.
  ** Throw a CompilerErr with appropriate message if name
  ** cannot be resolved.
  **
  abstract CPod resolvePod(Str name, Location? loc)

}