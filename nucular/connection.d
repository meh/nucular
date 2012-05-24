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

import nucular.reactor : Reactor;
import nucular.descriptor;
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

		this (ubyte[] data)
		{
			content = data;
		}

		this (Address addr, ubyte[] data)
		{
			content = data;
			address = addr;
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

		int opCast(T : int) ()
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

	Connection created (Reactor reactor)
	{
		_reactor = reactor;
		_mutex   = new Mutex;

		return this;
	}

	Connection watched (Reactor reactor, Descriptor descriptor)
	{
		created(reactor);

		_descriptor = descriptor;

		return this;
	}

	Connection accepted (Server server, Descriptor descriptor)
	{
		created(server.reactor);

		_server = server;

		_descriptor = descriptor;

		reuseAddr    = true;
		asynchronous = true;

		return this;
	}

	Connection connecting (Reactor reactor, Descriptor descriptor)
	{
		watched(reactor, descriptor);

		noDelay      = true;
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

	void receiveData (ubyte[] data)
	{
		// this is just a placeholder
	}

	void sendData (ubyte[] data)
	{
		enforce(!isClosing, "you cannot write data when the connection is closing");

		if (protocol == "udp") {
			enforce(defaultTarget, "there is no default target");

			sendDataTo(defaultTarget, data);
		}
		else {
			synchronized (_mutex) {
				_to_write ~= Data(data);
			}
		}

		reactor.wakeUp();
	}

	void sendDataTo (Address address, ubyte[] data)
	{
		enforce(!isClosing, "you cannot write data when the connection is closing");

		synchronized (_mutex) {
			_to_write ~= Data(address, data);
		}

		reactor.wakeUp();
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
			errnoEnforce(.shutdown(cast (int) _descriptor, 2) == 0);
		}
	}

	void close ()
	{
		_descriptor.close();
	}

	ubyte[] read ()
	{
		ubyte[] result;

		try {
			ubyte[] tmp;

			while ((tmp = _descriptor.read(1024)) !is null) {
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

		if (_descriptor.isClosed) {
			closeConnection();
		}

		return result;
	}

	bool write ()
	{
		if (_descriptor.isClosed) {
			return true;
		}

		synchronized (_mutex) {
			while (!_to_write.empty) {
				Data      current = _to_write.front;
				ptrdiff_t written;

				if (current.address) {
					written = sendTo(current.address, current.content);
				}
				else {
					written = _descriptor.write(current.content);
				}

				if (written != current.content.length) {
					_to_write[0].content = current.content[written .. $];

					return false;
				}
				else {
					_to_write.popFront();
				}
			}
		}

		return true;
	}

	Data receiveFrom (int length)
	{
		ubyte[] data;
		Address address;

		_descriptor.socket.receiveFrom(data, SocketFlags.NONE, address);

		return Data(address, data);
	}

	ptrdiff_t sendTo (Address address, ubyte[] data)
	{
		return _descriptor.socket.sendTo(data, SocketFlags.NONE, address);
	}

	@property remoteAddress ()
	{
		if (defaultTarget) {
			return defaultTarget;
		}

		if (_descriptor.socket) {
			return _descriptor.socket.remoteAddress();
		}

		return null;
	}

	@property localAddress ()
	{
		if (_descriptor.socket) {
			return _descriptor.socket.localAddress();
		}

		return null;
	}

	@property error ()
	{
		if (_error || _descriptor.isClosed) {
			return _error;
		}

		version (Posix) {
			int       result;
			socklen_t resultSize = cast (socklen_t) result.sizeof;

			errnoEnforce(getsockopt(cast (int) _descriptor, SOL_SOCKET, SO_ERROR, cast (char*) &result, &resultSize) == 0);

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
		if (_descriptor.isClosed) {
			return true;
		}

		if (!_descriptor.read(1) && _descriptor.isClosed) {
			return true;
		}

		return false;
	}

	@property isAlive ()
	{
		if (_descriptor.isClosed) {
			return false;
		}

		version (Posix) {
			int       result;
			socklen_t resultSize = cast (socklen_t) result.sizeof;

			return !getsockopt(cast (int) _descriptor, SOL_SOCKET, SO_TYPE, cast (char*) &result, &resultSize);
		}
	}

	@property reuseAddr ()
	{
		version (Posix) {
			int       result;
			socklen_t resultSize = cast (socklen_t) result.sizeof;

			errnoEnforce(getsockopt(cast (int) _descriptor, SOL_SOCKET, SO_REUSEADDR, cast (char*) &result, &resultSize) == 0);

			return cast (bool) result;
		}
	}

	@property reuseAddr (bool enable)
	{
		version (Posix) {
			int value = cast (int) enable;

			errnoEnforce(setsockopt(cast (int) _descriptor, SOL_SOCKET, SO_REUSEADDR, cast (char*) &value, value.sizeof) == 0);
		}
	}

	@property noDelay ()
	{
		version (Posix) {
			int       result;
			socklen_t resultSize = cast (socklen_t) result.sizeof;

			errnoEnforce(getsockopt(cast (int) _descriptor, IPPROTO_TCP, TCP_NODELAY, cast (char*) &result, &resultSize) == 0);

			return cast (bool) result;
		}
	}

	@property noDelay (bool enable)
	{
		version (Posix) {
			int value = cast (int) enable;

			errnoEnforce(setsockopt(cast (int) _descriptor, IPPROTO_TCP, TCP_NODELAY, cast (char*) &value, value.sizeof) == 0);
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
		return !_server;
	}

	@property isWritePending ()
	{
		return !_to_write.empty;
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

	@property server ()
	{
		return _server;
	}

	@property reactor ()
	{
		return _reactor;
	}

	Descriptor opCast(T : Descriptor) ()
	{
		return _descriptor;
	}

	// FIXME: remove when the bug is fixed
	Object opCast(T : Object) ()
	{
		return this;
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

	Data[] _to_write;
	Errno  _error;
	bool   _closing;
}
