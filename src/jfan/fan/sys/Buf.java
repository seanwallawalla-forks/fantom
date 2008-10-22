//
// Copyright (c) 2006, Brian Frank and Andy Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   2 Apr 06  Brian Frank  Creation
//
package fan.sys;

import java.io.*;
import java.math.*;
import java.nio.*;

/**
 * Buf
 */
public abstract class Buf
  extends FanObj
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  public static Buf make() { return new MemBuf(1024); }
  public static Buf make(long capacity) { return new MemBuf((int)capacity); }

  public static Buf random(long s)
  {
    int size = (int)s;
    byte[] buf = new byte[size];

    for (int i=0; i<size;)
    {
      int x = FanInt.random.nextInt();
      buf[i++] = (byte)(x >> 24);
      if (i < size)
      {
        buf[i++] = (byte)(x >> 16);
        if (i < size)
        {
          buf[i++] = (byte)(x >> 8);
          if (i < size) buf[i++] = (byte)x;
        }
      }
    }

    return new MemBuf(buf);
  }

//////////////////////////////////////////////////////////////////////////
// Obj
//////////////////////////////////////////////////////////////////////////

  public final boolean equals(Object that)
  {
    return this == that;
  }

  public String toStr()
  {
    return type().name() + "(pos=" + pos() + " size=" + size() + ")";
  }

  public Type type() { return Sys.BufType; }

//////////////////////////////////////////////////////////////////////////
// Support
//////////////////////////////////////////////////////////////////////////

  abstract int getByte(long pos);
  abstract void getBytes(long pos, byte[] dst, int off, int len);
  abstract void setByte(long pos, int x);

  abstract void pipeTo(byte[] dst, int dstPos, int len);
  abstract void pipeTo(OutputStream dst, long len) throws IOException;
  abstract void pipeTo(RandomAccessFile dst, long len) throws IOException;
  abstract void pipeTo(ByteBuffer dst, int len);

  abstract void pipeFrom(byte[] src, int srcPos, int len);
  abstract long pipeFrom(InputStream src, long len) throws IOException;
  abstract long pipeFrom(RandomAccessFile src, long len) throws IOException;
  abstract int pipeFrom(ByteBuffer src, int len);

//////////////////////////////////////////////////////////////////////////
// Access
//////////////////////////////////////////////////////////////////////////

  public final boolean empty()
  {
    return size() == 0;
  }

  public long capacity()
  {
    return Long.MAX_VALUE;
  }

  public void capacity(long c)
  {
  }

  public abstract long size();

  public abstract void size(long s);

  public abstract long pos();

  abstract void pos(long p);

  public final long remaining()
  {
    return size()-pos();
  }

  public final boolean more()
  {
    return size()-pos() > 0;
  }

  public final Buf seek(long pos)
  {
    long size = size();
    if (pos < 0) pos = size + pos;
    if (pos < 0 || pos > size) throw IndexErr.make(pos).val;
    pos(pos);
    return this;
  }

  public final Buf flip()
  {
    size(pos());
    pos(0);
    return this;
  }

  public final long get(long pos)
  {
    long size = size();
    if (pos < 0) pos = size + pos;
    if (pos < 0 || pos >= size) throw IndexErr.make(pos).val;
    return getByte(pos);
  }

  public final Buf slice(Range range)
  {
    long size = size();
    long s = range.start(size);
    long e = range.end(size);
    int n = (int)(e - s + 1);
    if (n < 0) throw IndexErr.make(range).val;

    byte[] slice = new byte[n];
    getBytes(s, slice, 0, n);

    Buf result = new MemBuf(slice, n);
    result.charset(charset());
    return result;
  }

//////////////////////////////////////////////////////////////////////////
// Modification
//////////////////////////////////////////////////////////////////////////

  public final Buf set(long pos, long b)
  {
    long size = size();
    if (pos < 0) pos = size + pos;
    if (pos < 0 || pos >= size) throw IndexErr.make(pos).val;
    setByte(pos, (int)b);
    return this;
  }

  public Buf trim()
  {
    return this;
  }

  public final Buf clear()
  {
    pos(0);
    size(0);
    return this;
  }

  public Buf flush()
  {
    return this;
  }

  public boolean close()
  {
    return true;
  }

  public final Charset charset()
  {
    return out.charset();
  }

  public final void charset(Charset charset)
  {
    out.charset(charset);
    in.charset(charset);
  }

//////////////////////////////////////////////////////////////////////////
// OutStream
//////////////////////////////////////////////////////////////////////////

  public final OutStream out() { return out; }

  public final Buf write(long b) { out.write(b); return this; }

  public final Buf writeBuf(Buf other) { out.writeBuf(other); return this; }
  public final Buf writeBuf(Buf other, long n) { out.writeBuf(other, n); return this; }

  public final Buf writeI2(long x) { out.writeI2(x); return this; }

  public final Buf writeI4(long x) { out.writeI4(x); return this; }

  public final Buf writeI8(long x) { out.writeI8(x); return this; }

  public final Buf writeF4(double x) { out.writeF4(x); return this; }

  public final Buf writeF8(double x) { out.writeF8(x); return this; }

  public final Buf writeDecimal(BigDecimal x) { out.writeDecimal(x); return this; }

  public final Buf writeBool(boolean x) { out.writeBool(x); return this; }

  public final Buf writeUtf(String x) { out.writeUtf(x); return this; }

  public final Buf writeChar(long c) { out.writeChar(c); return this; }

  public final Buf writeChars(String s) { out.writeChars(s); return this; }
  public final Buf writeChars(String s, long off) { out.writeChars(s, off); return this; }
  public final Buf writeChars(String s, long off, long len) { out.writeChars(s, off, len); return this; }

  public final Buf print(Object obj) { out.print(obj); return this; }

  public final Buf printLine() { out.printLine(); return this; }
  public final Buf printLine(Object obj) { out.printLine(obj); return this; }

  public final Buf writeObj(Object obj) { out.writeObj(obj); return this; }
  public final Buf writeObj(Object obj, Map opt) { out.writeObj(obj, opt); return this; }

//////////////////////////////////////////////////////////////////////////
// InStream
//////////////////////////////////////////////////////////////////////////

  public final InStream in() { return in; }

  public final Long read() {  return in.read(); }

  public final Long readBuf(Buf other, long n) { return in.readBuf(other, n); }

  public final Buf unread(long n) { in.unread(n); return this; }

  public final Buf readBufFully(Buf buf, long n) { return in.readBufFully(buf, n); }

  public final Buf readAllBuf() { return in.readAllBuf(); }

  public final Long peek() { return in.peek(); }

  public final long readU1() { return in.readU1(); }

  public final long readS1() { return in.readS1(); }

  public final long readU2() { return in.readU2(); }

  public final long readS2() { return in.readS2(); }

  public final long readU4() { return in.readU4(); }

  public final long readS4() { return in.readS4(); }

  public final long readS8() { return in.readS8(); }

  public final double readF4() { return in.readF4(); }

  public final double readF8() { return in.readF8(); }

  public final BigDecimal readDecimal() { return in.readDecimal(); }

  public final boolean readBool() { return in.readBool(); }

  public final String readUtf() { return in.readUtf(); }

  public final Long readChar() { return in.readChar(); }

  public final Buf unreadChar(long c) { in.unreadChar(c); return this; }

  public final Long peekChar() { return in.peekChar(); }

  public final String readLine() { return in.readLine(); }
  public final String readLine(Long max) { return in.readLine(max); }

  public final String readStrToken() { return in.readStrToken(); }
  public final String readStrToken(Long max) { return in.readStrToken(max); }
  public final String readStrToken(Long max, Func f) { return in.readStrToken(FanInt.Chunk, f); }

  public final List readAllLines() { return in.readAllLines(); }

  public final void eachLine(Func f) { in.eachLine(f); }

  public final String readAllStr() { return in.readAllStr(); }
  public final String readAllStr(boolean normalizeNewlines)  { return in.readAllStr(normalizeNewlines); }

  public final Object readObj() { return in.readObj(); }
  public final Object readObj(Map opt) { return in.readObj(opt); }

//////////////////////////////////////////////////////////////////////////
// Hex
//////////////////////////////////////////////////////////////////////////

  public String toHex()
  {
    throw UnsupportedErr.make(type()+".toHex").val;
  }

  public static Buf fromHex(String str)
  {
    String s = str;
    int slen = s.length();
    byte[] buf = new byte[slen/2];
    int[] hexInv = Buf.hexInv;
    int size = 0;

    for (int i=0; i<slen; ++i)
    {
      int c0 = s.charAt(i);
      int n0 = c0 < 128 ? hexInv[c0] : -1;
      if (n0 < 0) continue;

      int n1 = -1;
      if (++i < slen)
      {
        int c1 = s.charAt(i);
        n1 = c1 < 128 ? hexInv[c1] : -1;
      }
      if (n1 < 0) throw IOErr.make("Invalid hex str").val;

      buf[size++] = (byte)((n0 << 4) | n1);
    }

    return new MemBuf(buf, size);
  }

  static char[] hexChars = "0123456789abcdef".toCharArray();
  static int[] hexInv    = new int[128];
  static
  {
    for (int i=0; i<hexInv.length; ++i) hexInv[i] = -1;
    for (int i=0; i<10; ++i)  hexInv['0'+i] = i;
    for (int i=10; i<16; ++i) hexInv['a'+i-10] = hexInv['A'+i-10] = i;
  }

//////////////////////////////////////////////////////////////////////////
// Base64
//////////////////////////////////////////////////////////////////////////

  public String toBase64()
  {
    throw UnsupportedErr.make(type()+".toBase64").val;
  }

  public static Buf fromBase64(String s)
  {
    int slen = s.length();
    int si = 0;
    int max = slen * 6 / 8;
    byte[] buf = new byte[max];
    int size = 0;

    while (si < slen)
    {
      int n = 0;
      int v = 0;
      for (int j=0; j<4 && si<slen;)
      {
        int ch = s.charAt(si++);
        int c = ch < 128 ? base64inv[ch] : -1;
        if (c >= 0)
        {
          n |= c << (18 - j++ * 6);
          if (ch != '=') v++;
        }
      }

      if (v > 1) buf[size++] = (byte)(n >> 16);
      if (v > 2) buf[size++] = (byte)(n >> 8);
      if (v > 3) buf[size++] = (byte)n;
    }

    return new MemBuf(buf, size);
  }

  static char[] base64chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/".toCharArray();
  static final int[] base64inv = new int[128];
  static
  {
    for (int i=0; i<base64inv.length; ++i)   base64inv[i] = -1;
    for (int i=0; i<base64chars.length; ++i) base64inv[base64chars[i]] = i;
    base64inv['='] = 0;
  }

//////////////////////////////////////////////////////////////////////////
// Digest
//////////////////////////////////////////////////////////////////////////

  public Buf toDigest(String algorithm)
  {
    throw UnsupportedErr.make(type()+".toDigest").val;
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  OutStream out;
  InStream in;

}