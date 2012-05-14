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

import std.exception;

import nucular.reactor;
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

class Connection {
	this (Server server, Descriptor descriptor) {
		_server = server;

		_descriptor = descriptor;

		reuseAddr = true;
		noDelay   = true;
	}

	void postInit () {
		// nothing to see here
	}

	void receiveData (ubyte[] data) {
		// nothing to see here
	}

	void sendData (string data) {

	}

	void closeConnection (bool after_writing = false) {
		
	}

	void closeConnectionAfterWriting () {
		closeConnection(true);
	}

	void unbind () {
		// nothing to see here
	}

	@property error () {
		version (Posix) {
			int       result;
			socklen_t resultSize = cast (socklen_t) result.sizeof;

			errnoEnforce(getsockopt(cast (int) _descriptor, SOL_SOCKET, SO_ERROR, cast (char*) &result, &resultSize) == 0);

			return result;
		}
	}

	@property alive () {
		version (Posix) {
			int       result;
			socklen_t resultSize = cast (socklen_t) result.sizeof;

			return !getsockopt(cast (int) _descriptor, SOL_SOCKET, SO_TYPE, cast (char*) &result, &resultSize);
		}
	}

	@property reuseAddr () {
		version (Posix) {
			int       result;
			socklen_t resultSize = cast (socklen_t) result.sizeof;

			errnoEnforce(getsockopt(cast (int) _descriptor, SOL_SOCKET, SO_REUSEADDR, cast (char*) &result, &resultSize) == 0);

			return cast (bool) result;
		}
	}

	@property reuseAddr (bool enable) {
		version (Posix) {
			int value = cast (int) enable;

			errnoEnforce(setsockopt(cast (int) _descriptor, SOL_SOCKET, SO_REUSEADDR, cast (char*) &value, value.sizeof) == 0);
		}
	}

	@property noDelay () {
		version (Posix) {
			int       result;
			socklen_t resultSize = cast (socklen_t) result.sizeof;

			errnoEnforce(getsockopt(cast (int) _descriptor, IPPROTO_TCP, TCP_NODELAY, cast (char*) &result, &resultSize) == 0);

			return cast (bool) result;
		}
	}

	@property noDelay (bool enable) {
		version (Posix) {
			int value = cast (int) enable;

			errnoEnforce(setsockopt(cast (int) _descriptor, IPPROTO_TCP, TCP_NODELAY, cast (char*) &value, value.sizeof) == 0);
		}
	}

	@property server () {
		return _server;
	}

	@property reactor () {
		return _server.reactor;
	}

private:
	Server _server;

	Descriptor _descriptor;
}
