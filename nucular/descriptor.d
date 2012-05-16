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

module nucular.descriptor;

import std.conv;
import std.exception;
import std.socket;

version (Posix) {
	import core.sys.posix.fcntl;
	import core.sys.posix.unistd;
}
else version (Windows) {
	static assert (0);
}
else {
	static assert(0);
}

class Descriptor {
	this (int fd) {
		_fd = fd;
	}

	this (Socket socket) {
		_fd     = socket.handle;
		_socket = socket;
	}

	ubyte[] read (size_t length) {
		auto      buffer = new ubyte[](length);
		ptrdiff_t result;

		errnoEnforce((result = .read(_fd, cast (void*) buffer.ptr, length)) >= 0);

		if (result == 0) {
			return null;
		}

		buffer.length = result;

		return buffer;
	}

	ptrdiff_t write (ubyte[] data) {
		ptrdiff_t result;

		errnoEnforce((result = .write(_fd, cast (void*) data.ptr, data.length)) >= 0);

		return result;
	}

	ptrdiff_t write (string text) {
		return write(cast (ubyte[]) text);
	}

	void close () {
		.close(_fd);
	}

	@property asynchronous () {
		version (Posix) {
			return (fcntl(_fd, F_GETFL, 0) & O_NONBLOCK) != 0;
		}
	}

	@property asynchronous (bool value) {
		if (value) {
			version (Posix) {
				int old = fcntl(_fd, F_GETFL, 0);

				errnoEnforce(fcntl(_fd, F_SETFL, old | O_NONBLOCK) >= 0);
			}
		}
		else {
			version (Posix) {
				int old = fcntl(_fd, F_GETFL, 0);

				errnoEnforce(fcntl(_fd, F_SETFL, old & ~O_NONBLOCK) >= 0);
			}
		}
	}

	equals_t opEquals (Descriptor other) {
		return _fd == cast (int) other;
	}

	equals_t opEquals (int other) {
		return _fd == other;
	}

	int opCmp (Descriptor other) {
		int fd = cast (int) other;

		return (_fd < fd) ? -1 : (_fd > fd) ? 1 : 0;
	}

	int opCmp (int other) {
		return (_fd < fd) ? -1 : (_fd > fd) ? 1 : 0;
	}

	int opCast(T : int) () {
		return _fd;
	}

	hash_t toHash () {
		return _fd;
	}

	string toString () {
		return "Descriptor(" ~ _fd.to!string ~ ")";
	}

private:
	int _fd;

	Socket _socket;
}
