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

module nucular;

import std.conv;
import std.exception;

version (Posix) {
	extern (C) int fcntl (int, int, ...);
	extern (C) long write (int, void*, ulong);
	extern (C) long read (int, void*, ulong);
	extern (C) int close (int);

	const F_GETFL = 3;
	const F_SETFL = 4;

	const O_NONBLOCK = octal!4000;
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

	@property asynchronous () {
		return _asynchronous;
	}

	@property asynchronous (bool value) {
		if (value) {
			_asynchronous = true;

			int old = fcntl(_fd, F_GETFL, 0);

			errnoEnforce(fcntl(_fd, F_SETFL, old | O_NONBLOCK) >= 0);
		}
		else {
			_asynchronous = false;

			int old = fcntl(_fd, F_GETFL, 0);

			errnoEnforce(fcntl(_fd, F_SETFL, old & ~O_NONBLOCK) >= 0);
		}
	}

	string read (ulong length) {
		auto buffer = new string(length);
		long result;

		errnoEnforce((result = .read(_fd, cast (void*) buffer.ptr, length)) >= 0);

		if (result == 0) {
			return null;
		}

		buffer.length = result;

		return buffer;
	}

	long write (string text) {
		long result;

		errnoEnforce((result = .write(_fd, cast (void*) text.ptr, text.length)) >= 0);

		return result;
	}

	int opCast () {
		return _fd;
	}

private:
	int  _fd;
	bool _asynchronous;
}
