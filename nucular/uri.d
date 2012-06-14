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
import nucular.security : SecureInternetAddress, SecureInternet6Address;

version (Posix) {
	import nucular.server : UnixAddress, NamedPipeAddress, mode_t;
}

/**
 * This class abstracts an URI scheme, giving access to the underlying protocol
 * and standard port.
 */
class Scheme
{
	/**
	 * Params:
	 *   name = the name of the scheme
	 *   protocol = (optional) the transport layer name (tcp, udp, etcetera)
	 */
	this (string name, string protocol = null)
	{
		_name = name.toLower();

		_service = new Service;
		_service.getServiceByName(_name, protocol);
	}

	/**
	 * Get the scheme name.
	 */
	@property name ()
	{
		return _name;
	}

	/**
	 * Get the protocol name.
	 */
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

	/**
	 * Get the default port of the service.
	 */
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
	/**
	 * Representation of a Query parameter, a name=value pair.
	 */
	static class Parameter
	{
		this (string name)
		{
			_name = name;
		}

		this (string name, string value)
		{
			this(name);

			_value = value;
		}

		@property name ()
		{
			return _name;
		}

		@property name (string value)
		{
			_name = name;
		}

		@property value ()
		{
			return _value;
		}

		@property value (string value)
		{
			_value = value;
		}

		/**
		 * Find if the Parameter is true (the value is empty).
		 */
		@property isTrue ()
		{
			return value.empty || (value != "false" && value != "no");
		}

		bool opCast(T : bool) ()
		{
			return isTrue;
		}

	private:
		string _name;
		string _value;
	}

	static Query parse (string text)
	{
		return new Query(text);
	}

	this (string text)
	{
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

			add(name.decodeComponent(), value.decodeComponent());
		}
	}

	/**
	 *
	 */
	bool has (string name)
	{
		return !_internal.find!(a => a.name == name).empty;
	}

	Query add (string name, string value = null)
	{
		_internal ~= new Parameter(name, value);

		return this;
	}

	Parameter remove (string name)
	{
		if (!has(name)) {
			return null;
		}

		auto index  = _internal.countUntil!(a => a.name == name);
		auto result = _internal[index];

		_internal = _internal.remove(index);

		return result;
	}

	Parameter opIndex (string name)
	{
		if (_internal.empty) {
			return null;
		}

		auto result = _internal.find!(a => a.name == name);

		return result.empty ? null : result.front;
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

	int opApply (int delegate (string, string) block)
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

	int opApplyReverse (int delegate (string, string) block)
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
		return new URI(text);
	}

	this (string text)
	{
		auto m = text.match(URIMatcher);

		if (!m) {
			throw new Exception("not a well formed URI");
		}

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

		if (m = host.match(HostMatcher)) {
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

		_original = text;
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
				auto target = host == "*" ? "0.0.0.0" : host;

				if (query && query["ssl"] && query["ssl"].isTrue) {
					auto key    = query["key"];
					auto cert   = query["cert"];
					auto verify = query["verify"] ? query["verify"].isTrue : false;

					if (collectException(Internet6Address.parse(host))) {
						if (key && cert) {
							return new SecureInternetAddress(target, port, key.value, cert.value, verify);
						}
						else if (key) {
							return new SecureInternetAddress(target, port, key.value, verify);
						}
						else {
							return new SecureInternetAddress(target, port, verify);
						}
					}
					else {
						if (key && cert) {
							return new SecureInternet6Address(target, port, key.value, cert.value, verify);
						}
						else if (key) {
							return new SecureInternet6Address(target, port, key.value, verify);
						}
						else {
							return new SecureInternet6Address(target, port, verify);
						}
					}
				}

				if (collectException(Internet6Address.parse(host))) {
					return new InternetAddress(target, port);
				}
				else {
					return new Internet6Address(target, port);
				}

			case "tcp6":
				auto target = host == "*" ? "0.0.0.0" : host;

				if (query && query["ssl"] && query["ssl"].isTrue) {
					auto key    = query["key"];
					auto cert   = query["cert"];
					auto verify = query["verify"] ? query["verify"].isTrue : false;

					if (key && cert) {
						return new SecureInternet6Address(target, key.value, cert.value, verify);
					}
					else if (key) {
						return new SecureInternet6Address(target, key.value, verify);
					}
					else {
						return new SecureInternet6Address(target, verify);
					}
				}

				return new Internet6Address(target);

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
