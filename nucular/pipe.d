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

module nucular.pipe;

extern (C) int pipe (ref int[2]);
extern (C) long write (int, void*, ulong);
extern (C) long read (int, void*, ulong);
extern (C) int close (int);

class Pipe {
	struct Descriptors {
		int read;
		int write;
	}

	this () {
		int[2] pipes;

		pipe(pipes);

		_descriptors = Descriptors(pipes[0], pipes[1]);
	}

	~this () {
		close();
	}

	@property descriptors () {
		return _descriptors;
	}

	string read (ulong length) {
		auto buffer = new string(length);

		.read(_descriptors.read, cast (void*) buffer.ptr, length);

		return buffer;
	}

	long write (string text) {
		return .write(_descriptors.write, cast (void*) text.ptr, text.length);
	}

	void close () {
		if (_closed) {
			return;
		}

		_closed = true;

		.close(_descriptors.read);
		.close(_descriptors.write);
	}

private:
	Descriptors _descriptors;

	bool _closed;
}
