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

module nucular.uri;

import std.socket;
import std.regex;
import std.conv;
import std.array;
import std.algorithm;
import std.typecons;
import std.uri;

class Scheme
{
	this (string name, string protocol = null)
	{
		_service = new Service;
		_service.getServiceByName(name, protocol);
	}

	@property name ()
	{
		return _service.name;
	}

	@property protocolName ()
	{
		return _service.protocolName;
	}

	@property port ()
	{
		return _service.port;
	}

	override string toString ()
	{
		return name;
	}

private:
	Service _service;
}

class Query
{
	struct Parameter
	{
		string name;
		string value;

		@property empty ()
		{
			return name.empty && value.empty;
		}

		@property isTrue ()
		{
			return value.empty;
		}

		@property isFalse ()
		{
			return isTrue;
		}
	}

	static Query parse (string text)
	{
		auto result = new Query;

		foreach (piece; text.split("&")) {
			auto   pieces = piece.split("=");
			string name;
			string value;

			if (pieces.length == 2) {
				name  = pieces[0];
				value = pieces[1];
			}
			else {
				name = pieces[0];
			}

			result.add(name.decodeComponent(), value.decodeComponent());
		}

		return result;
	}

	bool has (string name)
	{
		return !_internal.find!(a => a.name == name).empty;
	}

	ref Query add (string name, string value = null)
	{
		_internal ~= Parameter(name, value);

		return this;
	}

	Parameter remove (string name)
	{
		if (!has(name)) {
			return Parameter(null, null);
		}

		auto index  = _internal.countUntil!(a => a.name == name);
		auto result = _internal[index];

		_internal.remove(index);

		return result;
	}

	string opIndex (string name)
	{
		if (_internal.empty) {
			return null;
		}

		auto result = _internal.find!(a => a.name == name);

		return result.empty ? null : result.front.value;
	}

	string opIndexAssign (string name, string value)
	{
		if (has(name)) {
			_internal.find!(a => a.name == name).front.value = value;
		}
		else {
			add(name, value);
		}

		return value;
	}

	bool opIndexAssign (string name, bool value)
	{
		if (has(name)) {
			if (value) {
				_internal.find!(a => a.name == name).front.value = null;
			}
			else {
				remove(name);
			}
		}
		else {
			if (value) {
				_internal.find!(a => a.name == name).front.value = null;
			}
		}

		return value;
	}

	int opApply (int delegate (ref string, ref string) block)
	{
		int result = 0;

		foreach (piece; _internal) {
			result = block(piece.name, piece.value);

			if (result) {
				break;
			}
		}

		return result;
	}

	int opApplyReverse (int delegate (ref string, ref string) block)
	{
		int result = 0;

		foreach_reverse (piece; _internal) {
			result = block(piece.name, piece.value);

			if (result) {
				break;
			}
		}

		return result;
	}

	override string toString ()
	{
		string result;

		foreach (name, value; this) {
			result ~= "&";
			result ~= name.encodeComponent();

			if (value) {
				result ~= "=";
				result ~= value.encodeComponent();
			}
		}

		return result[1 .. $];
	}

private:
	Parameter[] _internal;
}

class URI
{
	enum URIMatcher  = r"^(([^:/?#]+):)(//([^/?#]*))?([^?#]*)(\?([^#]*))?(#(.*))?";
	enum HostMatcher = r"^((.*?)(@(.*?)):)?(.*?)(:(\d+))?$";

	static URI parse (string text)
	{
		auto m = text.match(URIMatcher);

		if (!m) {
			return null;
		}

		auto uri = new URI(text);

		with (uri) {
			scheme = m.captures[2];
			host   = m.captures[4];
			port   = 0;

			if (!m.captures[5].empty) {
				path = m.captures[5];
			}

			if (!m.captures[7].empty) {
				query = m.captures[7];
			}

			if (!m.captures[9].empty) {
				fragment = m.captures[9];
			}
		}

		if (m = uri.host.match(HostMatcher)) {
			with (uri) {
				if (!m.captures[2].empty) {
					username = m.captures[2];
				}

				if (!m.captures[4].empty) {
					password = m.captures[4];
				}

				if (!m.captures[5]) {
					host = m.captures[5];
				}

				if (!m.captures[7].empty) {
					port = m.captures[7].to!ushort;
				}
			}
		}

		return uri;
	}

	this (string original)
	{
		_original = original;
	}

	@property scheme ()
	{
		return _scheme;
	}

	@property scheme (string value)
	{
		_scheme = new Scheme(value);
	}

	@property host ()
	{
		return _host;
	}

	@property host (string value)
	{
		_host = value;
	}

	@property port ()
	{
		return _port;
	}

	@property port (ushort value)
	{
		if (value == 0) {
			_port = _scheme.port;
		}
		else {
			_port = value;
		}
	}

	@property username ()
	{
		return _username;
	}

	@property username (string value)
	{
		_username = value;
	}

	@property password ()
	{
		return _password;
	}

	@property password (string value)
	{
		_password = value;
	}

	@property path ()
	{
		return _path;
	}

	@property path (string value)
	{
		_path = value;
	}

	@property query ()
	{
		return _query;
	}

	@property query (string query)
	{
		_query = Query.parse(query);
	}

	@property query (Query query)
	{
		_query = query;
	}

	@property fragment ()
	{
		return _fragment;
	}

	@property fragment (string value)
	{
		_fragment = value;
	}

	string[string] opSlice () {
		string[string] result;

		result["scheme"] = scheme.toString();

		if (username) {
			result["username"] = username;
		}

		if (password) {
			result["password"] = password;
		}

		result["host"] = host;
		result["port"] = port.to!string;

		if (path) {
			result["path"] = path;
		}

		if (query) {
			result["query"] = query.toString();
		}

		if (fragment) {
			result["fragment"] = fragment;
		}

		return result;
	}

	override string toString ()
	{
		if (_original) {
			return _original;
		}

		string result;

		result ~= scheme.toString();
		result ~= "://";

		if (username) {
			result ~= username;

			if (password) {
				result ~= "@";
				result ~= password;
			}

			result ~= ":";
		}

		result ~= host;

		if (port) {
			result ~= ":";
			result ~= port;
		}

		if (path) {
			result ~= path;
		}

		if (query) {
			result ~= "?";
			result ~= query.toString();
		}

		if (fragment) {
			result ~= "#";
			result ~= fragment;
		}

		return result;
	}

private:
	string _original;

	Scheme _scheme;

	string _host;
	ushort _port;
	
	string _username;
	string _password;

	string _path;
	Query  _query;
	string _fragment;
}
