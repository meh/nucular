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

import std.conv;
import std.exception;
import std.array;
import std.socket;
import std.string;

import core.sync.mutex;
import core.stdc.errno;

public import SSL = nucular.ssl;

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
	struct Data {
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

	class Errno
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

	Connection created (Reactor reactor, Descriptor descriptor = null)
	{
		_reactor    = reactor;
		_mutex      = new Mutex;
		_descriptor = descriptor;

		_readable = true;
		_writable = true;

		return this;
	}

	Connection watched (Reactor reactor, Descriptor descriptor)
	{
		created(reactor, descriptor);

		return this;
	}

	Connection accepted (Server server, Descriptor descriptor)
	{
		created(server.reactor, descriptor);

		_server = server;

		if (isSocket) {
			reuseAddr = true;
		}

		asynchronous = true;

		return this;
	}

	Connection connecting (Reactor reactor, Descriptor descriptor)
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

	Connection exchange (Connection to)
	{
		reactor.exchangeConnections(this, to);

		return to;
	}

	Descriptor exchange (Descriptor descriptor)
	{
		auto old = _descriptor;
		_descriptor = descriptor;

		return old;
	}

	void initialized ()
	{
		// this is just a placeholder
	}

	void exchanged (Connection other)
	{
		// this is just a placeholder
	}

	void connected () {
		// this is just a placeholder
	}

	bool verify (SSL.Certificate certificate)
	{
		return true;
	}

	void handshakeCompleted ()
	{
		// this is just a placeholder
	}

	void handshakeInterrupted ()
	{
		// this is just a placeholder
	}

	void receiveData (ubyte[] data)
	{
		// this is just a placeholder
	}

	void sendData (ubyte[] data)
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
				if (ssl) {
					_to_write.pushBack(Data(data, true));
				}
				else {
					_to_write.pushBack(Data(data));
				}
			}
		}

		reactor.wakeUp();
	}

	void sendDataTo (Address address, ubyte[] data)
	{
		enforce(!isClosing, "you cannot write data when the connection is closing");

		synchronized (_mutex) {
			_to_write.pushBack(Data(address, data));
		}

		reactor.wakeUp();
	}

	void startTLS (SSL.PrivateKey key, SSL.Certificate certificate, bool verify = false)
	{
		enforce(protocol == "tcp" || protocol == "unix", "secure connections aren't supported on this protocol");

		_ssl = new SSL.Box(isServer, key, certificate, verify, this);
	}

	void closeConnection (bool after_writing = false)
	{
		if (isClosing) {
			return;
		}

		_closing = true;

		reactor.closeConnection(this, after_writing);
	}

	void closeConnectionAfterWriting ()
	{
		closeConnection(true);
	}

	void unbind ()
	{
		// this is just a placeholder
	}

	void shutdown ()
	{
		version (Posix) {
			errnoEnforce(.shutdown(_descriptor.to!int, 2) == 0);
		}
	}

	void close ()
	{
		_descriptor.close();
	}

	ubyte[] read ()
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

		if (ssl) {
			ubyte[] buffer = new ubyte[2048];
			int     n;

			ssl.putCiphertext(result);
			result.clear();

			while ((n = ssl.getPlaintext(buffer)) > 0) {
				if (ssl.isHandshakeCompleted && !isHandshakeCompleted) {
					_handshake_completed = true;
					handshakeCompleted();
				}

				result ~= buffer;
			}

			if (n == SSL.Box.Result.Fatal) {
				closeConnection();
			}
			else if (n == SSL.Box.Result.Interrupted) {
				handshakeInterrupted();
				_ssl = null;
			}
			else {
				if (ssl.isHandshakeCompleted && !isHandshakeCompleted) {
					_handshake_completed = true;
					handshakeCompleted();
				}
			}
		}

		return result;
	}

	bool write ()
	{
		if (isClosed || !isWritable) {
			return true;
		}

		bool done = true;

		synchronized (_mutex) {
			while (!_to_write.empty) {
				Data      current = _to_write.front;
				ptrdiff_t written;

				if (current.address) {
					written = sendTo(current.address, current.content);
				}
				else {
					if (current.encrypt) {
						auto result = ssl.putPlaintext(current.content);

						if (result == SSL.Box.Result.Fatal) {
							closeConnection();
						}
						else if (result == SSL.Box.Result.Worked) {
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

			if (ssl) {
				auto buffer  = new ubyte[1024];
				auto working = true;

				while (working && ssl.canGetCiphertext) {
					{
						auto result = ssl.getCiphertext(buffer);

						if (result < buffer.length) {
							working       = false;
							buffer.length = result;
						}
					}

					{
						auto result = _descriptor.write(buffer);

						if (result < buffer.length) {
							ssl.ungetCiphertext(buffer[result .. $]);
							working = false;
						}
					}
				}

				if (done) {
					done = working;
				}

				while (true) {
					auto result = ssl.putPlaintext();

					if (result == SSL.Box.Result.Fatal) {
						closeConnection();
					}
					else if (result == SSL.Box.Result.Worked) {
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

	Data receiveFrom (ulong length)
	{
		ubyte[]   data = new ubyte[length];
		Address   address;
		ptrdiff_t result;

		errnoEnforce((result = _descriptor.socket.receiveFrom(data, SocketFlags.NONE, address)) != Socket.ERROR);

		data.length = result;

		return Data(address, data);
	}

	ptrdiff_t sendTo (Address address, ubyte[] data)
	{
		ptrdiff_t result;

		errnoEnforce((result = _descriptor.socket.sendTo(data, SocketFlags.NONE, address)) != Socket.ERROR);

		return result;
	}

	void addresses (Descriptor descriptor = null)
	{
		if (!descriptor) {
			descriptor = _descriptor;
		}

		if (descriptor && descriptor.isSocket) {
			_remote_address = descriptor.socket.remoteAddress();
			_local_address  = descriptor.socket.localAddress();
		}
	}

	@property remoteAddress ()
	{
		if (defaultTarget) {
			return defaultTarget;
		}

		return _remote_address;
	}

	@property localAddress ()
	{
		return _local_address;
	}

	@property peerCertificate ()
	{
		return ssl.peerCertificate;
	}

	@property error ()
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

	@property isClosing ()
	{
		return _closing;
	}

	@property isEOF ()
	{
		if (isClosed) {
			return true;
		}

		if (!_descriptor.read(1) && isClosed) {
			return true;
		}

		return false;
	}

	@property isClosed ()
	{
		return _descriptor.isClosed;
	}

	@property isAlive ()
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

	@property isSocket ()
	{
		return _descriptor.isSocket;
	}

	@property isWritable ()
	{
		return _writable;
	}

	@property isWritable (bool value)
	{
		_writable = value;
	}

	@property isReadable ()
	{
		return _readable;
	}

	@property isReadable (bool value)
	{
		_readable = value;
	}

	@property reuseAddr ()
	{
		version (Posix) {
			int       result;
			socklen_t resultSize = cast (socklen_t) result.sizeof;

			errnoEnforce(getsockopt(_descriptor.to!int, SOL_SOCKET, SO_REUSEADDR, cast (char*) &result, &resultSize) == 0);

			return cast (bool) result;
		}
	}

	@property reuseAddr (bool enable)
	{
		version (Posix) {
			int value = cast (int) enable;

			errnoEnforce(setsockopt(_descriptor.to!int, SOL_SOCKET, SO_REUSEADDR, cast (char*) &value, value.sizeof) == 0);
		}
	}

	@property noDelay ()
	{
		version (Posix) {
			int       result;
			socklen_t resultSize = cast (socklen_t) result.sizeof;

			errnoEnforce(getsockopt(_descriptor.to!int, IPPROTO_TCP, TCP_NODELAY, cast (char*) &result, &resultSize) == 0);

			return cast (bool) result;
		}
	}

	@property noDelay (bool enable)
	{
		version (Posix) {
			int value = cast (int) enable;

			errnoEnforce(setsockopt(_descriptor.to!int, IPPROTO_TCP, TCP_NODELAY, cast (char*) &value, value.sizeof) == 0);
		}
	}

	@property asynchronous ()
	{
		return _descriptor.asynchronous;
	}

	@property asynchronous (bool value)
	{
		_descriptor.asynchronous = value;
	}

	@property isWatcher ()
	{
		return !_server && !_client;
	}

	@property isClient ()
	{
		return _client;
	}

	@property isServer ()
	{
		return cast (bool) _server;
	}

	@property isWritePending ()
	{
		return !_to_write.empty || ssl.canGetCiphertext;
	}
	
	@property isHandshakeCompleted ()
	{
		return _handshake_completed;
	}

	@property protocol ()
	{
		return _protocol;
	}

	@property protocol (string value)
	{
		_protocol = value.toLower();
	}

	@property defaultTarget ()
	{
		return _default_target;
	}

	@property defaultTarget (Address address)
	{
		_default_target = address;
	}

	@property ssl ()
	{
		return _ssl;
	}

	@property server ()
	{
		return _server;
	}

	@property reactor ()
	{
		return _reactor;
	}

	Descriptor to(T : Descriptor) ()
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

	Descriptor _descriptor;
	string     _protocol;
	Address    _default_target;
	Address    _remote_address;
	Address    _local_address;
	SSL.Box    _ssl;

	Queue!Data _to_write;

	Errno _error;
	bool  _client;
	bool  _closing;
	bool  _readable;
	bool  _writable;
	bool  _handshake_completed;
}
