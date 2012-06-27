/* Copyleft meh. [http://meh.paranoid.pk | meh@paranoici.org]
 *
 * This file is part of nucular.
 *
 * nucular is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as published
 * by the Free Software Foundation, either version 3 of the License,
 * or (at your option) any later version.
 *
 * nucular is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with nucular. If not, see <http://www.gnu.org/licenses/>.
 ****************************************************************************/

module nucular.connection;

import std.stdio : writeln;

import std.conv;
import std.exception;
import std.array;
import std.socket;
import std.string;

import core.sync.mutex;
import core.stdc.errno;

public import Security = nucular.security;

import nucular.reactor : Reactor;
import nucular.descriptor;
import nucular.queue;
import nucular.server;

version (Posix) {
	import core.sys.posix.sys.socket;
	import core.sys.posix.netinet.in_;
	import core.sys.posix.netinet.tcp;
}
else version (Windows) {
	static assert (0);
}
else {
	static assert(0);
}

class Connection
{
	static struct Data
	{
		ubyte[] content;
		Address address;
		bool    encrypt;

		this (ubyte[] data, bool enc = false)
		{
			content = data;
			encrypt = enc;
		}

		this (Address addr, ubyte[] data, bool enc = false)
		{
			content = data;
			address = addr;
			encrypt = enc;
		}
	}

	static class Errno
	{
		this (int value)
		{
			_value = value;
		}

		@property message ()
		{
			return std.c.string.strerror(_value).to!string;
		}

		int to(T : int) ()
		{
			return _value;
		}

		override string toString ()
		{
			return "Errno(" ~ message ~ ")";
		}

	private:
		int _value;
	}

	final ref created (Reactor reactor, Descriptor descriptor = null)
	{
		_reactor    = reactor;
		_mutex      = new Mutex;
		_descriptor = descriptor;

		_readable = true;
		_writable = true;

		return this;
	}

	final ref watched (Reactor reactor, Descriptor descriptor)
	{
		created(reactor, descriptor);

		return this;
	}

	final ref accepted (Server server, Descriptor descriptor)
	{
		created(server.reactor, descriptor);

		_server = server;

		if (isSocket) {
			reuseAddr = true;
		}

		asynchronous = true;

		return this;
	}

	final ref connecting (Reactor reactor, Descriptor descriptor)
	{
		watched(reactor, descriptor);
		_client = true;

		if (protocol == "tcp") {
			noDelay = true;
		}

		asynchronous = true;

		return this;
	}

	~this ()
	{
		if (_descriptor) {
			_descriptor.close();
		}
	}

	final Connection exchange (Connection to)
	{
		reactor.exchangeConnections(this, to);

		return to;
	}

	final Descriptor exchange (Descriptor descriptor)
	{
		auto old = _descriptor;
		_descriptor = descriptor;

		return old;
	}

	/**
	 * This method gets called when the Connection is initialized, always
	 * AFTER the creation block has been called.
	 */
	void initialized ()
	{
		// this is just a placeholder
	}

	/**
	 * This method gets called when the Connection has been exchanged with
	 * another one.
	 */
	void exchanged (Connection other)
	{
		// this is just a placeholder
	}

	/**
	 * This method gets called when the connection has been established.
	 */
	void connected () {
		// this is just a placeholder
	}

	/**
	 * This method is called when security certificate verfication is enabled
	 * and must return true to specify succesful verification, false otherwise.
	 */
	bool verify (Security.Certificate certificate)
	{
		return true;
	}

	/**
	 * This method is called when the security handshake has been completed.
	 */
	void handshakeCompleted ()
	{
		// this is just a placeholder
	}

	/**
	 * This method is called when the security handshake has been interrupted.
	 */
	void handshakeInterrupted ()
	{
		// this is just a placeholder
	}

	/**
	 * This method is called everytime data arrives on the Connection.
	 */
	void receiveData (ubyte[] data)
	{
		// this is just a placeholder
	}

	final void sendData (ubyte[] data)
	{
		enforce(!isClosing, "you cannot write data when the connection is closing");

		if (!isWritable) {
			return;
		}

		if (protocol == "udp") {
			enforce(defaultTarget, "there is no default target");

			sendDataTo(defaultTarget, data);
		}
		else {
			synchronized (_mutex) {
				if (security) {
					_to_write.pushBack(new Data(data, true));
				}
				else {
					_to_write.pushBack(new Data(data));
				}
			}
		}

		reactor.writeHappened();
	}

	final void sendDataTo (Address address, ubyte[] data)
	{
		enforce(!isClosing, "you cannot write data when the connection is closing");

		synchronized (_mutex) {
			_to_write.pushBack(new Data(address, data));
		}

		reactor.writeHappened();
	}

	final void secure (bool verify = false)
	{
		enforce(protocol == "tcp", "secure connections aren't supported on this protocol");

		_security = new Security.Box(isServer, verify, this);
	}

	final void secure (Security.Context context, bool verify = false)
	{
		enforce(protocol == "tcp", "secure connections aren't supported on this protocol");

		_security = new Security.Box(isServer, context, verify, this);
	}

	final void secure (Security.Type type, bool verify = false)
	{
		enforce(protocol == "tcp", "secure connections aren't supported on this protocol");

		_security = new Security.Box(isServer, verify, this, type);
	}

	final void secure (Security.PrivateKey key, bool verify = false)
	{
		enforce(protocol == "tcp", "secure connections aren't supported on this protocol");

		_security = new Security.Box(isServer, key, verify, this);
	}

	final void secure (string key, bool verify = false)
	{
		enforce(protocol == "tcp", "secure connections aren't supported on this protocol");

		_security = new Security.Box(isServer, key, verify, this);
	}

	final void secure (Security.Type type, Security.PrivateKey key, bool verify = false)
	{
		enforce(protocol == "tcp", "secure connections aren't supported on this protocol");

		_security = new Security.Box(isServer, key, verify, this, type);
	}

	final void secure (Security.Type type, string key, bool verify = false)
	{
		enforce(protocol == "tcp", "secure connections aren't supported on this protocol");

		_security = new Security.Box(isServer, key, verify, this, type);
	}

	final void secure (Security.PrivateKey key, Security.Certificate certificate, bool verify = false)
	{
		enforce(protocol == "tcp", "secure connections aren't supported on this protocol");

		_security = new Security.Box(isServer, key, certificate, verify, this);
	}

	final void secure (string key, string certificate, bool verify = false)
	{
		enforce(protocol == "tcp", "secure connections aren't supported on this protocol");

		_security = new Security.Box(isServer, key, certificate, verify, this);
	}

	final void secure (Security.Type type, Security.PrivateKey key, Security.Certificate certificate, bool verify = false)
	{
		enforce(protocol == "tcp", "secure connections aren't supported on this protocol");

		_security = new Security.Box(isServer, key, certificate, verify, this, type);
	}

	final void secure (Security.Type type, string key, string certificate, bool verify = false)
	{
		enforce(protocol == "tcp", "secure connections aren't supported on this protocol");

		_security = new Security.Box(isServer, key, certificate, verify, this, type);
	}

	final void closeConnection (bool after_writing = false)
	{
		if (isClosing) {
			return;
		}

		_closing = true;

		reactor.closeConnection(this, after_writing);
	}

	final void closeConnectionAfterWriting ()
	{
		closeConnection(true);
	}

	/**
	 * This method is called when the Connection is closed, either by an error or normally.
	 */
	void unbind ()
	{
		// this is just a placeholder
	}

	final void shutdown ()
	{
		version (Posix) {
			errnoEnforce(.shutdown(_descriptor.to!int, 2) == 0);
		}
	}

	final void close ()
	{
		_descriptor.close();
	}

	final ubyte[] read ()
	{
		if (isClosed || !isReadable) {
			return null;
		}

		ubyte[] result;

		try {
			ubyte[] tmp;

			while (!(tmp = _descriptor.read(1024)).empty) {
				result ~= tmp;

				if (tmp.length != 1024) {
					break;
				}
			}
		}
		catch (ErrnoException e) {
			_error = new Errno(e.errno);
			_descriptor.close();
		}

		if (isClosed) {
			closeConnection();
		}

		if (security) {
			auto buffer = new ubyte[2048];
			int         n;

			security.putCiphertext(result);
			result.clear();

			while ((n = security.getPlaintext(buffer)) > 0) {
				if (security.isHandshakeCompleted && !isHandshakeCompleted) {
					_handshake_completed = true;
					handshakeCompleted();
				}

				if (n != buffer.length) {
					result ~= buffer[0 .. n];

					break;
				}
				else {
					result ~= buffer;
				}
			}

			if (n == Security.Box.Result.Fatal) {
				closeConnection();
			}
			else if (n == Security.Box.Result.Interrupted) {
				handshakeInterrupted();
				_security = null;
			}
			else {
				if (security.isHandshakeCompleted && !isHandshakeCompleted) {
					_handshake_completed = true;
					handshakeCompleted();
				}
			}
		}

		return result;
	}

	final bool write ()
	{
		if (isClosed || !isWritable) {
			return true;
		}

		bool done = true;

		synchronized (_mutex) {
			while (!_to_write.empty) {
				Data*     current = _to_write.front;
				ptrdiff_t written;

				if (current.address) {
					written = sendTo(current.address, current.content);
				}
				else {
					if (current.encrypt) {
						auto result = security.putPlaintext(current.content);

						if (result == Security.Box.Result.Fatal) {
							closeConnection();
						}
						else if (result == Security.Box.Result.Worked) {
							written = current.content.length;
						}
						else {
							written = 0;
						}
					}
					else {
						written = _descriptor.write(current.content);
					}
				}

				if (written != current.content.length) {
					if (written > 0) {
						_to_write.front.content = current.content[written .. $];
					}

					done = false;

					break;
				}
				else {
					_to_write.popFront();
				}
			}

			if (security) {
				auto buffer  = new ubyte[2048];
				auto working = true;

				while (working && security.canGetCiphertext) {
					{
						auto result = security.getCiphertext(buffer);

						if (result < buffer.length) {
							working       = false;
							buffer.length = result;
						}
					}

					{
						auto result = _descriptor.write(buffer);

						if (result < buffer.length) {
							security.ungetCiphertext(buffer[result .. $]);
							working = false;
						}
					}
				}

				if (done) {
					done = working;
				}

				while (true) {
					auto result = security.putPlaintext();

					if (result == Security.Box.Result.Fatal) {
						closeConnection();
					}
					else if (result == Security.Box.Result.Worked) {
						continue;
					}
					else {
						break;
					}
				}
			}
		}

		return done;
	}

	final Data* receiveFrom (ulong length)
	{
		ubyte[]   data = new ubyte[length];
		Address   address;
		ptrdiff_t result;

		try {
			errnoEnforce((result = _descriptor.socket.receiveFrom(data, SocketFlags.NONE, address)) != Socket.ERROR);
		}
		catch (ErrnoException e) {
			if (e.errno == EAGAIN || e.errno == EWOULDBLOCK) {
				return null;
			}

			throw e;
		}

		data.length = result;

		return new Data(address, data);
	}

	final ptrdiff_t sendTo (Address address, ubyte[] data)
	{
		ptrdiff_t result;

		errnoEnforce((result = _descriptor.socket.sendTo(data, SocketFlags.NONE, address)) != Socket.ERROR);

		return result;
	}

	final void addresses (Descriptor descriptor = null)
	{
		if (!descriptor) {
			descriptor = _descriptor;
		}

		if (descriptor && descriptor.isSocket) {
			_remote_address = descriptor.socket.remoteAddress();
			_local_address  = descriptor.socket.localAddress();
		}
	}

	final @property remoteAddress ()
	{
		if (defaultTarget) {
			return defaultTarget;
		}

		return _remote_address;
	}

	final @property localAddress ()
	{
		return _local_address;
	}

	final @property peerCertificate ()
	{
		return security.peerCertificate;
	}

	final @property error ()
	{
		if (_error || isClosed || !isSocket) {
			return _error;
		}

		version (Posix) {
			int       result;
			socklen_t resultSize = cast (socklen_t) result.sizeof;

			errnoEnforce(getsockopt(_descriptor.to!int, SOL_SOCKET, SO_ERROR, cast (char*) &result, &resultSize) == 0);

			if (result != 0) {
				_error = new Errno(result);
			}
		}

		return _error;
	}

	final @property isClosing ()
	{
		return _closing;
	}

	final @property isEOF ()
	{
		if (isClosed) {
			return true;
		}

		if (!_descriptor.read(1) && isClosed) {
			return true;
		}

		return false;
	}

	final @property isClosed ()
	{
		return _descriptor.isClosed;
	}

	final @property isAlive ()
	{
		if (isClosed) {
			return false;
		}

		version (Posix) {
			int       result;
			socklen_t resultSize = cast (socklen_t) result.sizeof;

			return !getsockopt(_descriptor.to!int, SOL_SOCKET, SO_TYPE, cast (char*) &result, &resultSize);
		}
	}

	final @property isSocket ()
	{
		return _descriptor.isSocket;
	}

	final @property isWritable ()
	{
		return _writable;
	}

	final @property isWritable (bool value)
	{
		_writable = value;
	}

	final @property isReadable ()
	{
		return _readable;
	}

	final @property isReadable (bool value)
	{
		_readable = value;
	}

	final @property reuseAddr ()
	{
		version (Posix) {
			int       result;
			socklen_t resultSize = cast (socklen_t) result.sizeof;

			errnoEnforce(getsockopt(_descriptor.to!int, SOL_SOCKET, SO_REUSEADDR, cast (char*) &result, &resultSize) == 0);

			return cast (bool) result;
		}
	}

	final @property reuseAddr (bool enable)
	{
		version (Posix) {
			int value = cast (int) enable;

			errnoEnforce(setsockopt(_descriptor.to!int, SOL_SOCKET, SO_REUSEADDR, cast (char*) &value, value.sizeof) == 0);
		}
	}

	final @property noDelay ()
	{
		version (Posix) {
			int       result;
			socklen_t resultSize = cast (socklen_t) result.sizeof;

			errnoEnforce(getsockopt(_descriptor.to!int, IPPROTO_TCP, TCP_NODELAY, cast (char*) &result, &resultSize) == 0);

			return cast (bool) result;
		}
	}

	final @property noDelay (bool enable)
	{
		version (Posix) {
			int value = cast (int) enable;

			errnoEnforce(setsockopt(_descriptor.to!int, IPPROTO_TCP, TCP_NODELAY, cast (char*) &value, value.sizeof) == 0);
		}
	}

	final @property asynchronous ()
	{
		return _descriptor.asynchronous;
	}

	final @property asynchronous (bool value)
	{
		_descriptor.asynchronous = value;
	}

	final @property isWatcher ()
	{
		return !_server && !_client;
	}

	final @property isClient ()
	{
		return _client;
	}

	final @property isServer ()
	{
		return cast (bool) _server;
	}

	final @property isWritePending ()
	{
		return !_to_write.empty || (security !is null && security.canGetCiphertext);
	}
	
	final @property isHandshakeCompleted ()
	{
		return _handshake_completed;
	}

	final @property protocol ()
	{
		return _protocol;
	}

	final @property protocol (string value)
	{
		_protocol = value.toLower();
	}

	final @property defaultTarget ()
	{
		return _default_target;
	}

	final @property defaultTarget (Address address)
	{
		_default_target = address;
	}

	final @property security ()
	{
		return _security;
	}

	final @property server ()
	{
		return _server;
	}

	final @property reactor ()
	{
		return _reactor;
	}

	final Descriptor to(T : Descriptor) ()
	{
		return _descriptor;
	}

	override string toString ()
	{
		if (_descriptor) {
			return "Connection(" ~ _descriptor.toString() ~ ")";
		}
		else {
			return "Connection()";
		}
	}

private:
	Server  _server;
	Reactor _reactor;
	Mutex   _mutex;

	Descriptor   _descriptor;
	string       _protocol;
	Address      _default_target;
	Address      _remote_address;
	Address      _local_address;
	Security.Box _security;

	Queue!(Data*) _to_write;

	Errno _error;
	bool  _client;
	bool  _closing;
	bool  _readable;
	bool  _writable;
	bool  _handshake_completed;
}
