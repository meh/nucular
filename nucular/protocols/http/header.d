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

module nucular.protocols.http.header;

import std.string;
import std.uni;
import std.conv;

import nucular.protocols.http.parser;

class Header
{
	static string normalize (string name)
	{
		string result;
		bool   up = true;

		for (int i = 0; i < name.length; i++) {
			if (up) {
				result ~= name[i].toUpper();
				up = false;
			}
			else {
				result ~= name[i].toLower();
			}

			if (name[i] == '-') {
				up = true;
			}
		}

		return result;
	}

	static Header parse (string text)
	{
		auto tree = HTTP.MessageHeader.parse(text);

		return new Header(tree.capture[0].to!string, tree.capture[1].to!string);
	}

	this (string name, string value)
	{
		_name  = Header.normalize(name);
		_value = value;
	}

	@property name ()
	{
		return _name;
	}

	@property value ()
	{
		return _value;
	}

	override string toString ()
	{
		return _name ~ ": " ~ _value;
	}

private:
	string _name;
	string _value;
}

unittest {
	auto h = Header.parse("content-length: 23");

	assert(h.name == "Content-Length");
	assert(h.value == "23");
	assert(h.toString == "Content-Length: 23");
}
