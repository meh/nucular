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

	Descriptor exchange (Connection to)
	{
		auto old = _descriptor;
		_descriptor = null;

		reactor.exchangeConnection(this, to);

		return _descriptor;
	}

	Descriptor exchange (Descriptor descriptor)
	{
		auto old = _descriptor;
		_descriptor = descriptor;

		exchanged();

		return old;
	}

	void initialized ()
	{
		// this is just a placeholder
	}

	void exchanged ()
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
		synchronized (_mutex) {
			_to_write ~= data;
		}

		reactor.wakeUp();
	}

	void closeConnection (bool after_writing = false)
	{
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

	ubyte[] read ()
	{
		ubyte[] result;
		ubyte[] tmp;

		try {
			while ((tmp = _descriptor.read(1024)) !is null) {
				result ~= tmp;
			}
		}
		catch (ErrnoException e) {
			_error = new Errno(e.errno);
			_descriptor.close();
		}

		if (_descriptor.isClosed) {
			closeConnection();

			return null;
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
				ubyte[]   current = _to_write.front;
				ptrdiff_t written;

				if ((written = _descriptor.write(current)) != current.length) {
					_to_write[0] = current[written .. current.length];

					return false;
				}
				else {
					_to_write.popFront();
				}
			}
		}

		return true;
	}

	@property remoteAddress ()
	{
		return _descriptor.socket ? _descriptor.socket.remoteAddress() : null;
	}

	@property localAddress ()
	{
		return _descriptor.socket ? _descriptor.socket.localAddress() : null;
	}

	@property error ()
	{
		if (_error) {
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

	@property isAlive ()
	{
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
		return _server is null;
	}

	@property isWritePending ()
	{
		return !_to_write.empty;
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
		return "Connection(" ~ _descriptor.toString() ~ ")";
	}

private:
	Server  _server;
	Reactor _reactor;
	Mutex   _mutex;

	Descriptor _descriptor;

	ubyte[][] _to_write;
	Errno     _error;
}
