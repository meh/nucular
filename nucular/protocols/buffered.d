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

module nucular.protocols.buffered;

import std.algorithm;
import std.array;
import std.exception;

import nucular.connection;

class Protocol : Connection
{
	override void receiveData (ubyte[] data)
	{
		_buffer ~= data;

		if (_buffer.length >= _minimum) {
			ulong old = _minimum;

			receiveBufferedData(_buffer);

			if (_auto_reset && old == _minimum) {
				_minimum = 0;
			}
		}
	}

	void receiveBufferedData (ref ubyte[] data)
	{
		// this is just a place holder
	}

	@property minimum (ulong value)
	{
		_minimum = value;
	}

	@property autoReset (bool value)
	{
		_auto_reset = value;
	}

	@property ref buffer ()
	{
		return _buffer;
	}

private:
	ubyte[] _buffer;

	ulong _minimum    = 0;
	bool  _auto_reset = true;
}
