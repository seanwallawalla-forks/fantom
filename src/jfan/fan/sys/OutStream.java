//
// Copyright (c) 2006, Brian Frank and Andy Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   27 Mar 06  Brian Frank  Creation
//
package fan.sys;

import java.math.*;
import fanx.serial.*;

/**
 * OutStream.
 */
public class OutStream
  extends FanObj
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  public static OutStream makeForStrBuf(StrBuf buf)
  {
    return new StrBufOutStream(buf);
  }

  public static OutStream make(OutStream out)
  {
    OutStream self = new OutStream();
    make$(self, out);
    return self;
  }

  public static void make$(OutStream self, OutStream out)
  {
    self.out = out;
  }

//////////////////////////////////////////////////////////////////////////
// Obj
//////////////////////////////////////////////////////////////////////////

  public Type type() { return Sys.OutStreamType; }

//////////////////////////////////////////////////////////////////////////
// Java OutputStream
//////////////////////////////////////////////////////////////////////////

  /**
   * Write a byte using a Java primitive int.  Most
   * writes route to this method for efficient mapping to
   * a java.io.OutputStream.  If we aren't overriding this
   * method, then route back to write(Int) for the
   * subclass to handle.
   */
  public OutStream w(int b)
  {
    return write(Long.valueOf(b));
  }

//////////////////////////////////////////////////////////////////////////
// OutStream
//////////////////////////////////////////////////////////////////////////

  public OutStream write(Long x)
  {
    try
    {
      out.write(x);
      return this;
    }
    catch (NullPointerException e)
    {
      if (out == null)
        throw UnsupportedErr.make(type().qname() + " wraps null OutStream").val;
      else
        throw e;
    }
  }

  public OutStream writeBuf(Buf buf) { return writeBuf(buf, buf.remaining()); }
  public OutStream writeBuf(Buf buf, Long n)
  {
    try
    {
      out.writeBuf(buf, n);
      return this;
    }
    catch (NullPointerException e)
    {
      if (out == null)
        throw UnsupportedErr.make(type().qname() + " wraps null OutStream").val;
      else
        throw e;
    }
  }

  public OutStream writeI2(Long x)
  {
    int v = x.intValue();
    return this.w((v >>> 8) & 0xFF)
               .w((v >>> 0) & 0xFF);
  }

  public OutStream writeI4(Long x) { return writeI4(x.intValue()); }
  public OutStream writeI4(int v)
  {
    return this.w((v >>> 24) & 0xFF)
               .w((v >>> 16) & 0xFF)
               .w((v >>> 8)  & 0xFF)
               .w((v >>> 0)  & 0xFF);
  }

  public OutStream writeI8(Long x) { return writeI8(x.longValue()); }
  public OutStream writeI8(long v)
  {
    return this.w((int)(v >>> 56) & 0xFF)
               .w((int)(v >>> 48) & 0xFF)
               .w((int)(v >>> 40) & 0xFF)
               .w((int)(v >>> 32) & 0xFF)
               .w((int)(v >>> 24) & 0xFF)
               .w((int)(v >>> 16) & 0xFF)
               .w((int)(v >>> 8)  & 0xFF)
               .w((int)(v >>> 0)  & 0xFF);
  }

  public OutStream writeF4(double x)
  {
    return writeI4(Float.floatToIntBits((float)x));
  }

  public OutStream writeF8(double x)
  {
    return writeI8(Double.doubleToLongBits(x));
  }

  public OutStream writeDecimal(BigDecimal x)
  {
    return writeUtf(x.toString());
  }

  public OutStream writeBool(boolean x)
  {
    return w(x ? 1 : 0);
  }

  public OutStream writeUtf(String s)
  {
    int slen = s.length();
    int utflen = 0;

    // first we have to figure out the utf length
    for (int i=0; i<slen; ++i)
    {
      int c = s.charAt(i);
      if (c <= 0x007F)
        utflen +=1;
      else if (c > 0x07FF)
        utflen += 3;
      else
        utflen += 2;
    }

    // sanity check
    if (utflen > 65536) throw IOErr.make("String too big").val;

    // write length as 2 byte value
    w((utflen >>> 8) & 0xFF);
    w((utflen >>> 0) & 0xFF);

    // write characters
    for (int i=0; i<slen; ++i)
    {
      int c = s.charAt(i);
      if (c <= 0x007F)
      {
        w(c);
      }
      else if (c > 0x07FF)
      {
        w(0xE0 | ((c >> 12) & 0x0F));
        w(0x80 | ((c >>  6) & 0x3F));
        w(0x80 | ((c >>  0) & 0x3F));
      }
      else
      {
        w(0xC0 | ((c >>  6) & 0x1F));
        w(0x80 | ((c >>  0) & 0x3F));
      }
    }
    return this;
  }

  public Charset charset()
  {
    return charset;
  }

  public void charset(Charset charset)
  {
    this.charsetEncoder = charset.newEncoder();
    this.charset = charset;
  }

  public OutStream writeChar(Long c)
  {
    charsetEncoder.encode((char)c.longValue(), this);
    return this;
  }

  public OutStream writeChar(char c)
  {
    charsetEncoder.encode(c, this);
    return this;
  }

  public OutStream writeChars(String s) { return writeChars(s, 0, s.length()); }
  public OutStream writeChars(String s, Long off) { return writeChars(s, off.intValue(), s.length()-off.intValue()); }
  public OutStream writeChars(String s, Long off, Long len) { return writeChars(s, off.intValue(), len.intValue()); }
  public OutStream writeChars(String s, int off, int len)
  {
    int end = off+len;
    for (int i=off; i<end; ++i)
      charsetEncoder.encode(s.charAt(i), this);
    return this;
  }

  public OutStream print(Object obj)
  {
    String s = obj == null ? "null" : toStr(obj);
    return writeChars(s, 0, s.length());
  }

  public OutStream printLine() { return printLine(""); }
  public OutStream printLine(Object obj)
  {
    String s = obj == null ? "null" : toStr(obj);
    writeChars(s, 0, s.length());
    return writeChar('\n');
  }

  public OutStream writeObj(Object obj) { return writeObj(obj, null); }
  public OutStream writeObj(Object obj, Map options)
  {
    new ObjEncoder(this, options).writeObj(obj);
    return this;
  }

  public OutStream writeProps(Map props) { return writeProps(props, true); }
  public OutStream writeProps(Map props, boolean close)
  {
    Charset origCharset = charset();
    charset(Charset.utf8());
    try
    {
      List keys = props.keys().sort();
      int size = keys.sz();
      Long eq = FanInt.pos['='];
      Long nl = FanInt.pos['\n'];
      for (int i=0; i<size; ++i)
      {
        String key = (String)keys.get(i);
        String val = (String)props.get(key);
        writePropStr(key);
        writeChar(eq);
        writePropStr(val);
        writeChar(nl);
      }
      return this;
    }
    finally
    {
      try { if (close) close(); } catch (Exception e) { e.printStackTrace(); }
      charset(origCharset);
    }
  }

  private void writePropStr(String s)
  {
    int len = s.length();
    for (int i=0; i<len; ++i)
    {
      int ch = s.charAt(i);
      int peek = i+1<len ? s.charAt(i+1) : -1;

      // escape special chars
      switch (ch)
      {
        case '\n': writeChar(FanInt.pos['\\']).writeChar(FanInt.pos['n']); continue;
        case '\r': writeChar(FanInt.pos['\\']).writeChar(FanInt.pos['r']); continue;
        case '\t': writeChar(FanInt.pos['\\']).writeChar(FanInt.pos['t']); continue;
        case '\\': writeChar(FanInt.pos['\\']).writeChar(FanInt.pos['\\']); continue;
      }

      // escape control chars, comments, and =
      if ((ch < ' ') || (ch == '/' && (peek == '/' || peek == '*')) || (ch == '='))
      {
        Long nib1 = FanInt.toDigit(FanInt.pos[(ch>>4)&0xf], FanInt.pos[16]);
        Long nib2 = FanInt.toDigit(FanInt.pos[(ch>>0)&0xf], FanInt.pos[16]);

        this.writeChar(FanInt.pos['\\']).writeChar(FanInt.pos['u'])
            .writeChar(FanInt.pos['0']).writeChar(FanInt.pos['0'])
            .writeChar(nib1).writeChar(nib2);
        continue;
      }

      // normal character
      writeChar(Long.valueOf(ch));
    }
  }

  public OutStream flush()
  {
    if (out != null) out.flush();
    return this;
  }

  public boolean close()
  {
    if (out != null) return out.close();
    return true;
  }

//////////////////////////////////////////////////////////////////////////
// Java Utils
//////////////////////////////////////////////////////////////////////////

  public OutStream indent(int num)
  {
    for (int i=0; i<num; ++i)
      charsetEncoder.encode(' ', this);
    return this;
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  OutStream out;
  Charset charset = Charset.utf8();
  Charset.Encoder charsetEncoder = charset.newEncoder();

}