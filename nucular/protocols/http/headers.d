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

module nucular.protocols.http.headers;

import std.algorithm;

import nucular.protocols.http.header;
import std.stdio : writeln;

class Headers
{
	Header add (Header header)
	{
		return _map[header.name] = header;
	}

	Header opIndex (string name)
	{
		return _map[Header.normalize(name)];
	}

	Header opIndexAssign (Header header, string name)
	{
		return _map[Header.normalize(name)] = header;
	}

	Header opIndexAssign (string value, string name)
	{
		return _map[Header.normalize(name)] = new Header(name, value);
	}

	Header[] opSlice ()
	{
		return _map.values;
	}

	int opApply (int delegate (ref Header) block)
	{
		int result = 0;

		foreach (header; _map) {
			result = block(header);

			if (result) {
				break;
			}
		}

		return result;
	}

	int opApplyReverse (int delegate (ref Header) block)
	{
		int result = 0;

		foreach_reverse (header; _map) {
			result = block(header);

			if (result) {
				break;
			}
		}

		return result;
	}

	override string toString ()
	{
		string result;

		foreach (header; this) {
			result ~= header.toString() ~ "\r\n";
		}

		return result;

		// why doesn't this work?
		// return this[].map("a.toString()").join("\r\n");
	}

private:
	Header[string] _map;
}

unittest {
	auto hs = new Headers;

	hs["content-length"] = "23";
	hs["host"]           = "dlang.org";

	assert(hs.toString() == "Host: dlang.org\r\nContent-Length: 23\r\n");
}
