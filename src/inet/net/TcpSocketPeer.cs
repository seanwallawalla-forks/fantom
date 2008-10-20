//
// Copyright (c) 2007, Brian Frank and Andy Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   29 Nov 07  Andy Frank  Ported to .NET
//

using System;
using System.Net;
using System.Net.Sockets;
using Fan.Sys;

namespace Fan.Inet
{
  public class TcpSocketPeer
  {

  //////////////////////////////////////////////////////////////////////////
  // Peer Factory
  //////////////////////////////////////////////////////////////////////////

    public static TcpSocketPeer make(TcpSocket fan)
    {
      return new TcpSocketPeer();
    }

    // TODO - hardcoded to IPv4!
    public TcpSocketPeer()
      : this(new Socket(AddressFamily.InterNetwork, SocketType.Stream, ProtocolType.Tcp))
    {
    }

    public TcpSocketPeer(Socket socket)
    {
      this.m_net = socket;

      // turn off Nagle's algorithm since we should
      // always be doing buffering in the virtual machine
      try { m_net.NoDelay = true; } catch {}
    }

  //////////////////////////////////////////////////////////////////////////
  // State
  //////////////////////////////////////////////////////////////////////////

    public Fan.Sys.Boolean isBound(TcpSocket fan)
    {
      return Fan.Sys.Boolean.valueOf(m_net.IsBound);
    }

    public Fan.Sys.Boolean isConnected(TcpSocket fan)
    {
      return Fan.Sys.Boolean.valueOf(m_net.Connected);
    }

    public Fan.Sys.Boolean isClosed(TcpSocket fan)
    {
      return Fan.Sys.Boolean.valueOf(m_closed);
    }

  //////////////////////////////////////////////////////////////////////////
  // End Points
  //////////////////////////////////////////////////////////////////////////

    public IpAddress localAddress(TcpSocket fan)
    {
      if (!m_net.IsBound) return null;
      IPEndPoint pt = m_net.LocalEndPoint as IPEndPoint;
      if (pt == null) return null;
      return IpAddressPeer.make(pt.Address);
    }

    public Long localPort(TcpSocket fan)
    {
      if (!m_net.IsBound) return null;
      IPEndPoint pt = m_net.LocalEndPoint as IPEndPoint;
      if (pt == null) return null;
      // TODO - default port?
      return Long.valueOf(pt.Port);
    }

    public IpAddress remoteAddress(TcpSocket fan)
    {
      if (!m_net.Connected) return null;
      return m_remoteAddr;
    }

    public Long remotePort(TcpSocket fan)
    {
      if (!m_net.Connected) return null;
      return Long.valueOf(m_remotePort);
    }

  //////////////////////////////////////////////////////////////////////////
  // Communication
  //////////////////////////////////////////////////////////////////////////

    public TcpSocket bind(TcpSocket fan, IpAddress addr, Long port)
    {
      try
      {
        IPAddress netAddr = (addr == null) ? IPAddress.Any : addr.m_peer.m_net;
        int netPort = (port == null) ? 0 : port.intValue();
        m_net.Bind(new IPEndPoint(netAddr, netPort));
        return fan;
      }
      catch (SocketException e)
      {
        throw IOErr.make(e).val;
      }
    }

    public TcpSocket connect(TcpSocket fan, IpAddress addr, Long port, Duration timeout)
    {
      if (timeout != null)
      {
        IAsyncResult result = m_net.BeginConnect(addr.m_peer.m_net, port.intValue(), null, null);
        bool success = result.AsyncWaitHandle.WaitOne((int)timeout.millis(), true);
        if (!success)
        {
          m_net.Close();
          throw new System.IO.IOException("Connection timed out.");
        }
      }
      else
      {
        m_net.Connect(addr.m_peer.m_net, port.intValue());
      }
      connected(fan);
      return fan;
    }

    internal void connected(TcpSocket fan)
    {
      IPEndPoint endPoint = m_net.RemoteEndPoint as IPEndPoint;
      m_remoteAddr = IpAddressPeer.make(endPoint.Address);
      m_remotePort = endPoint.Port;
      m_in  = SysInStream.make(new NetworkStream(m_net), getInBufferSize(fan));
      m_out = SysOutStream.make(new NetworkStream(m_net), getOutBufferSize(fan));
    }

    public InStream @in(TcpSocket fan)
    {
      if (m_in == null) throw IOErr.make("not connected").val;
      return m_in;
    }

    public OutStream @out(TcpSocket fan)
    {
      if (m_out == null) throw IOErr.make("not connected").val;
      return m_out;
    }

    public Fan.Sys.Boolean close(TcpSocket fan)
    {
      try
      {
        close();
        return Fan.Sys.Boolean.True;
      }
      catch
      {
        return Fan.Sys.Boolean.False;
      }
    }

    public void close()
    {
      m_net.Close();
      m_in  = null;
      m_out = null;
      m_closed = true;
    }

  //////////////////////////////////////////////////////////////////////////
  // Threading
  //////////////////////////////////////////////////////////////////////////

  /* TODO - remove when I make final decision to keep TcpSocket const

    **
    ** Fork this socket onto another thread.  A new thread is automatically
    ** created with the given name (pass null to auto-generate a name).
    ** The new thread is started using the specified run method and this
    ** socket as the argument.  The run method must be a const method (it
    ** cannot capture state from the calling thread), otherwise NotImmutableErr
    ** is thrown.  Once a socket is forked onto a new thread,  it is detached
    ** from the calling thread and all methods will throw UnsupportedErr.
    **
    native Thread fork(Str threadName, |TcpSocket s->Obj| run)

    public Thread fork(TcpSocket oldSock, Str name, final Method run)
    {
      // error checking
      checkDetached();
      if (!run.isConst().val)
        throw NotImmutableErr.make("Run method not const: " + run).val;

      // increment fork counter
      int n = -1;
      synchronized (topLock) { n = forkCount++; }

      // generate name if null
      if (name == null) name = Str.make("inet.TcpSocket" + n);

      // create new detached thread-safe socket
      final TcpSocket newSock = detach(oldSock);

      // create new thread
      Thread thread = new Thread(name)
      {
        public Obj run()
        {
          return run.call1(newSock);
        }
      };

      // start thread
      return thread.start();
    }

    private TcpSocket detach(TcpSocket oldSock)
    {
      // detach old TcpSocket from this peer
      oldSock.peer = new TcpSocketPeer();
      oldSock.peer.detached = true;

      // create new thread safe TcpSocket
      final TcpSocket newSock = new TcpSocket();
      newSock.peer = this;
      return newSock;
    }

    private void checkDetached()
    {
      if (detached)
        throw UnsupportedErr.make("TcpSocket forked onto new thread").val;
    }
  */

  //////////////////////////////////////////////////////////////////////////
  // Streaming Options
  //////////////////////////////////////////////////////////////////////////

    public Long getInBufferSize(TcpSocket fan)
    {
      return (m_inBufSize <= 0) ? null : Long.valueOf(m_inBufSize);
    }

    public void setInBufferSize(TcpSocket fan, Long v)
    {
      if (m_in != null) throw Err.make("Must set inBufferSize before connection").val;
      m_inBufSize = (v == null) ? 0 : v.intValue();
    }

    public Long getOutBufferSize(TcpSocket fan)
    {
      return (m_outBufSize <= 0) ? null : Long.valueOf(m_outBufSize);
    }

    public void setOutBufferSize(TcpSocket fan, Long v)
    {
      if (m_in != null) throw Err.make("Must set outBufSize before connection").val;
      m_outBufSize = (v == null) ? 0 : v.intValue();
    }

  //////////////////////////////////////////////////////////////////////////
  // Socket Options
  //////////////////////////////////////////////////////////////////////////

    public SocketOptions options(TcpSocket fan)
    {
      if (m_options == null) m_options = SocketOptions.make(fan);
      return m_options;
    }

    public Fan.Sys.Boolean getKeepAlive(TcpSocket fan)
    {
      return Fan.Sys.Boolean.valueOf(Convert.ToBoolean(
        m_net.GetSocketOption(SocketOptionLevel.Socket, SocketOptionName.KeepAlive)));
    }

    public void setKeepAlive(TcpSocket fan, Fan.Sys.Boolean v)
    {
      m_net.SetSocketOption(SocketOptionLevel.Socket, SocketOptionName.KeepAlive, v.booleanValue());
    }

    public Long getReceiveBufferSize(TcpSocket fan)
    {
      return Long.valueOf(m_net.ReceiveBufferSize);
    }

    public void setReceiveBufferSize(TcpSocket fan, Long v)
    {
      m_net.ReceiveBufferSize = v.intValue();
    }

    public Long getSendBufferSize(TcpSocket fan)
    {
      return Long.valueOf(m_net.SendBufferSize);
    }

    public void setSendBufferSize(TcpSocket fan, Long v)
    {
      m_net.SendBufferSize = v.intValue();
    }

    public Fan.Sys.Boolean getReuseAddress(TcpSocket fan)
    {
      return Fan.Sys.Boolean.valueOf(Convert.ToBoolean(
        m_net.GetSocketOption(SocketOptionLevel.Socket, SocketOptionName.ReuseAddress)));
    }

    public void setReuseAddress(TcpSocket fan, Fan.Sys.Boolean v)
    {
      m_net.SetSocketOption(SocketOptionLevel.Socket, SocketOptionName.ReuseAddress, v.booleanValue());
    }

    public Duration getLinger(TcpSocket fan)
    {
      if (!m_net.LingerState.Enabled) return null;
      return Duration.makeSec(m_net.LingerState.LingerTime);
    }

    public void setLinger(TcpSocket fan, Duration v)
    {
      if (v == null)
      {
        m_net.LingerState = new LingerOption(false, 0);
      }
      else
      {
        m_net.LingerState = new LingerOption(true, (int)(v.sec()));
      }
    }

    public Duration getReceiveTimeout(TcpSocket fan)
    {
      if (m_net.ReceiveTimeout <= 0) return null;
      return Duration.makeMillis(m_net.ReceiveTimeout);
    }

    public void setReceiveTimeout(TcpSocket fan, Duration v)
    {
      if (v == null)
        m_net.ReceiveTimeout = 0;
      else
        m_net.ReceiveTimeout = (int)(v.millis());
    }

    public Fan.Sys.Boolean getNoDelay(TcpSocket fan)
    {
      return Fan.Sys.Boolean.valueOf(m_net.NoDelay);
    }

    public void setNoDelay(TcpSocket fan, Fan.Sys.Boolean v)
    {
      m_net.NoDelay = v.booleanValue();
    }

    public Long getTrafficClass(TcpSocket fan)
    {
      return Long.valueOf(Convert.ToInt32(
        m_net.GetSocketOption(SocketOptionLevel.IP, SocketOptionName.TypeOfService)));
    }

    public void setTrafficClass(TcpSocket fan, Long v)
    {
//try
//{
      m_net.SetSocketOption(SocketOptionLevel.IP, SocketOptionName.TypeOfService, v.longValue());
//}
//catch (System.Exception e)
//{
//  System.Console.WriteLine(" >>> " + v);
//  Err.dumpStack(e);
//}
    }

  //////////////////////////////////////////////////////////////////////////
  // Fields
  //////////////////////////////////////////////////////////////////////////

    private Socket m_net;

    private int m_inBufSize = 4096;
    private int m_outBufSize = 4096;
    private IpAddress m_remoteAddr;
    private int m_remotePort;
    private SysInStream m_in;
    private SysOutStream m_out;
    private SocketOptions m_options;
    private bool m_closed;

  }
}