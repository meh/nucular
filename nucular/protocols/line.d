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

module nucular.protocols.line;

import std.algorithm;
import std.array;
import std.exception;

import nucular.connection;

class Protocol : Connection {
	void receiveData (ubyte[] data) {
		if (_buffer.empty) {
			_buffer = data;
		}
		else {
			_buffer ~= data;
		}

		while (_buffer.canFind("\n")) {
			auto result = _buffer.findSplit("\n");

			if (result[0].back == '\r') {
				result[0].length--;
			}

			if (!result[0].empty) {
				receiveLine(cast (string) result[0]);
			}

			_buffer = result[2];
		}
	}

	void receiveLine (string line) {
		// this is just a place holder
	}

	void sendLine (string line) {
		enforce(!line.canFind("\n") && !line.canFind("\r"), "the line cannot include line endings");

		sendData(cast (ubyte[]) (line ~ "\r\n"));
	}

	void sendLines (string[] lines) {
		foreach (line; lines) {
			sendLine(line);
		}
	}

private:
	ubyte[] _buffer;
}
