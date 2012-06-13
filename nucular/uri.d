/*            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
 *                    Version 2, December 2004
 *
 *    Copyleft meh. [http://meh.paranoid.pk | meh@paranoici.org]
 *
 *            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
 *   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
 *
 *  0. You just DO WHAT THE FUCK YOU WANT TO.
 ****************************************************************************/

module nucular.uri;

import std.socket;
import std.regex;
import std.conv;
import std.array;
import std.algorithm;
import std.typecons;
import std.uri;
import std.string : toLower;

import nucular.reactor : InternetAddress, Internet6Address;

version (Posix) {
	import nucular.server : UnixAddress, NamedPipeAddress;
	import core.sys.posix.unistd;
}

class Scheme
{
	this (string name, string protocol = null)
	{
		_name = name.toLower();

		_service = new Service;
		_service.getServiceByName(_name, protocol);
	}

	@property name ()
	{
		return _name;
	}

	@property protocol ()
	{
		if (_service.protocolName) {
			return _service.protocolName;
		}

		if (name == "tcp" || name == "tcp6") {
			return "tcp";
		}

		if (name == "udp" || name == "udp6") {
			return "udp";
		}

		if (name == "fifo") {
			return "fifo";
		}

		if (name == "unix") {
			return "unix";
		}

		return "tcp";
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
	string  _name;
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

		_internal = _internal.remove(index);

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
	enum HostMatcher = r"^((.*?)(@(.*?)):)?(.+?)(:(\d+))?$";

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

				if (!m.captures[5].empty) {
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
		return _port.to!ushort;
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

	Address to(T : Address) ()
	{
		switch (scheme ? scheme.name : "tcp") {
			case "tcp":
				if (collectException(Internet6Address.parse(host))) {
					if (host == "*") {
						return new InternetAddress(port);
					}
					else {
						return new InternetAddress(host, port);
					}
				}
				else {
					return new Internet6Address(host, port);
				}

			case "tcp6":
				if (host == "*") {
					return new Internet6Address(port);
				}
				else {
					return new Internet6Address(host, port);
				}

			case "udp":
				if (collectException(Internet6Address.parse(host))) {
					if (host == "*") {
						return new InternetAddress(port);
					}
					else {
						return new InternetAddress(host, port);
					}
				}
				else {
					return new Internet6Address(host, port);
				}

			case "udp6":
				if (host == "*") {
					return new Internet6Address(port);
				}
				else {
					return new Internet6Address(host, port);
				}

			version (Posix) {
				case "fifo":
					return new NamedPipeAddress(path, port.to!string.to!mode_t(8));

				case "unix":
					return new UnixAddress(path);
			}

			default:
				throw new Exception("don't know how to convert this URI to an Address");
		}
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
