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

import std.array;
import std.algorithm;
import std.container;

public import nucular.protocols.http.header : Header;

class Headers
{
	Header add (Header header)
	{
		return this[header.name] = header;
	}

	Header opIndex (string name)
	{
		if (_internal.empty) {
			return null;
		}

		     name   = Header.normalize(name);
		auto result = _internal.find!(a => a.name == name);
		
		return result.empty ? null : result.front;
	}

	string opIndex (string name, bool _)
	{
		if (auto h = this[name]) {
			return h.value;
		}
		else {
			return null;
		}
	}

	Header opIndexAssign (Header header, string name)
	{
		if (auto h = this[name]) {
			if (h.type == Header.Type.List) {
				h.concat(header.value);

				return h;
			}
			else {
				_internal = _internal.remove(_internal.countUntil!(a => a.name == name));
				_internal ~= header;
			}
		}
		else {
			_internal ~= header;
		}

		return header;
	}

	Header opIndexAssign (string value, string name)
	{
		return this[name] = new Header(name, value);
	}

	Header[] opSlice ()
	{
		return _internal;
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
	Header[] _internal;
}

unittest {
	auto hs = new Headers;

	hs["content-length"] = "23";
	hs["host"]           = "dlang.org";

	assert(hs.toString() == "Host: dlang.org\r\nContent-Length: 23\r\n");
}
