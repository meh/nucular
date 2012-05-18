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
import core.stdc.errno;

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

		result = .read(_fd, cast (void*) buffer.ptr, length);

		if (result == 0) {
			_closed = true;

			return null;
		}

		if (result < 0 && (getErrno() == EAGAIN || getErrno() == EWOULDBLOCK)) {
			return null;
		}

		errnoEnforce(result > 0);

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
		if (isClosed) {
			return;
		}

		_closed = true;

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

	@property isClosed () {
		return _closed;
	}

	override equals_t opEquals (Object other) {
		if (this is other) {
			return true;
		}

		if (auto descriptor = cast (Descriptor) other) {
			return _fd == cast (int) descriptor;
		}

		return false;
	}

	override int opCmp (Object other) {
		if (this is other) {
			return 0;
		}

		if (auto descriptor = cast (Descriptor) other) {
			int fd = cast (int) descriptor;

			return (_fd < fd) ? -1 : (_fd > fd) ? 1 : 0;
		}

		return 1;
	}

	int opCast(T : int) () {
		return _fd;
	}

	override hash_t toHash () {
		return _fd;
	}

	override string toString () {
		return "Descriptor(" ~ _fd.to!string ~ ")";
	}

private:
	int    _fd;
	Socket _socket;

	bool _closed;
}
