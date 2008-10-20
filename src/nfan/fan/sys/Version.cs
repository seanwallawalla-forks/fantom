//
// Copyright (c) 2006, Brian Frank and Andy Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   14 Jan 06  Andy Frank  Creation
//

using System.Text;

namespace Fan.Sys
{
  /// <summary>
  /// Version.
  /// </summary>
  public sealed class Version : FanObj
  {

  //////////////////////////////////////////////////////////////////////////
  // Construction
  //////////////////////////////////////////////////////////////////////////

    public static Version fromStr(Str str) { return fromStr(str.val, true); }
    public static Version fromStr(Str str, Boolean check) { return fromStr(str.val, check.booleanValue()); }
    public static Version fromStr(string s) { return fromStr(s, true); }
    public static Version fromStr(string s, bool check)
    {
      List segments = new List(Sys.IntType, 4);
      int seg = -1;
      bool valid = true;
      int len = s.Length;
      for (int i=0; i<len; ++i)
      {
        int c = s[i];
        if (c == '.')
        {
          if (seg < 0 || i+1>=len) { valid = false; break; }
          segments.add(Long.valueOf(seg));
          seg = -1;
        }
        else
        {
          if ('0' <= c && c <= '9')
          {
            if (seg < 0) seg = c-'0';
            else seg = seg*10 + (c-'0');
          }
          else
          {
            valid = false; break;
          }
        }
      }
      if (seg >= 0) segments.add(Long.valueOf(seg));

      if (!valid || segments.sz() == 0)
      {
        if (check)
          throw ParseErr.make("Version", s).val;
        else
          return null;
      }

      return new Version(segments);
    }

    public static Version make(List segments)
    {
      bool valid = segments.sz() > 0;
      for (int i=0; i<segments.sz(); i++)
        if (((Long)segments.get(i)).longValue() < 0) valid = false;
      if (!valid) throw ArgErr.make("Invalid Version: '" + segments + "'").val;
      return new Version(segments);
    }

    internal Version(List segments)
    {
      this.m_segments = segments.ro();
    }

  //////////////////////////////////////////////////////////////////////////
  // Identity
  //////////////////////////////////////////////////////////////////////////

    public override Boolean _equals(object obj)
    {
      if (obj is Version)
        return toStr()._equals(((Version)obj).toStr());
      else
        return Boolean.False;
    }

    public override Long compare(object obj)
    {
      Version that = (Version)obj;
      List a = this.m_segments;
      List b = that.m_segments;
      for (int i=0; i<a.sz() && i<b.sz(); i++)
      {
        long ai = ((Long)a.get(i)).longValue();
        long bi = ((Long)b.get(i)).longValue();
        if (ai < bi) return FanInt.LT;
        if (ai > bi) return FanInt.GT;
      }
      if (a.sz() < b.sz()) return FanInt.LT;
      if (a.sz() > b.sz()) return FanInt.GT;
      return FanInt.EQ;
    }

    public override int GetHashCode()
    {
      return toStr().GetHashCode();
    }

    public override Long hash()
    {
      return toStr().hash();
    }

    public override Type type()
    {
      return Sys.VersionType;
    }

    public override Str toStr()
    {
      if (m_str == null)
      {
        StringBuilder s = new StringBuilder();
        for (int i=0; i<m_segments.sz(); i++)
        {
          if (i > 0) s.Append('.');
          s.Append(((Long)m_segments.get(i)).longValue());
        }
        m_str = Str.make(s.ToString());
      }
      return m_str;
    }

  //////////////////////////////////////////////////////////////////////////
  // Methods
  //////////////////////////////////////////////////////////////////////////

    public List segments()
    {
      return m_segments;
    }

    public int segment(int index)
    {
      return ((Long)m_segments.get(index)).intValue();
    }

    public Long major()
    {
      return (Long)m_segments.get(0);
    }

    public Long minor()
    {
      if (m_segments.sz() < 2) return null;
      return (Long)m_segments.get(1);
    }

    public Long build()
    {
      if (m_segments.sz() < 3) return null;
      return (Long)m_segments.get(2);
    }

    public Long patch()
    {
      if (m_segments.sz() < 4) return null;
      return (Long)m_segments.get(3);
    }

  //////////////////////////////////////////////////////////////////////////
  // Fields
  //////////////////////////////////////////////////////////////////////////

    private readonly List m_segments;
    private Str m_str;

  }
}