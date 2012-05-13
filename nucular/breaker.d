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

import core.memory;

import nucular.descriptor;
import nucular.available;

version (Posix) {
	import core.sys.posix.unistd;
}
else version (Windows) {
	static assert (0);
}
else {
	static assert (0);
}

class Breaker {
	version (Posix) {
		this () {
			int[2] pipes;

			.pipe(pipes);

			_read  = new Descriptor(pipes[0]);
			_write = new Descriptor(pipes[1]);

			_read.asynchronous  = true;
			_write.asynchronous = true;
		}

		~this () {
			.close(cast (int) _read);
			.close(cast (int) _write);
		}

		void act () {
			_write.write("x");
		}

		void flush () {
			try {
				while (_read.read(1024)) {
					continue;
				}
			}
			catch (ErrnoException e) { }
		}

		void wait () {
			available.readable([_read]);
		}

	private:
		Descriptor _read;
		Descriptor _write;
	}
	else version (Windows) {
		static assert (0);
	}
	else {
		static assert (0);
	}
}
