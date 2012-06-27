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

module nucular.protocols.socks.client;

public import nucular.protocols.dns.resolver : UnresolvedAddress;

import std.exception;
import std.conv;
import std.array;
import std.algorithm;
import std.string;

import nucular.reactor : Reactor, instance, Address, InternetAddress, Internet6Address, URI;
import nucular.deferrable;
import nucular.connection;
import buffered = nucular.protocols.buffered;
import base = nucular.protocols.socks.base;

abstract class Socks : buffered.Protocol
{
	ref initialize (Address target, Connection drop_to, string username = null, string password = null)
	{
		_target     = target;
		_drop_to    = drop_to;
		_deferrable = reactor.deferrable(drop_to);

		if (username) {
			_username = username;
		}

		if (password) {
			_password = password;
		}

		return this;
	}

	override void exchanged (Connection other)
	{
		other.connected();

		if (!buffer.empty) {
			other.receiveData(buffer);
		}
	}

	override void receiveBufferedData (ref ubyte[] data)
	{
		try {
			parseResponse(data);
		}
		catch (Exception e) {
			if (deferrable.hasErrback) {
				deferrable.failWith(e);
			}
			else {
				throw e;
			}
		}
	}

	override void unbind ()
	{
		deferrable.fail();
	}

	@property target ()
	{
		return _target;
	}

	@property username ()
	{
		return _username;
	}

	@property password () {
		return _password;
	}

	@property dropTo ()
	{
		return _drop_to;
	}

	@property deferrable ()
	{
		return _deferrable;
	}

protected:
	abstract void parseResponse (ref ubyte[] data);

private:
	Address               _target;
	Connection            _drop_to;
	Deferrable!Connection _deferrable;

	string _username;
	string _password;
}

class Socks4 : Socks, base.Socks4
{
	void sendPacket (ubyte[] data)
	{
		sendData([cast (ubyte) 4] ~ data);
	}

	void sendRequest (Type type, Address address)
	{
		if (auto target = cast (InternetAddress) address) {
			minimum = 8;

			sendPacket(cast (ubyte[]) [cast (ubyte) type] ~ target.port.toBytes() ~ target.addr.toBytes() ~ cast (ubyte[]) username ~ [cast (ubyte) 0]);
		}
		else {
			throw new base.SocksError("address not supported");
		}
	}

	override void connected ()
	{
		sendRequest(Type.StreamConnection, target);
	}

protected:
	override void parseResponse (ref ubyte[] data)
	{
		// drop null byte
		data.popFront();

		auto status = cast (Reply) data.front; data.popFront();

		if (status != Reply.Granted) {
			throw new base.SocksError(status);
		}

		data = data[6 .. $];

		deferrable.succeed();
		exchange(dropTo);
	}
}

class Socks4a : Socks4
{
	override void sendRequest (Type type, Address address)
	{
		if (auto target = cast (UnresolvedAddress) address) {
			minimum = 8;

			sendPacket(cast (ubyte[]) [cast (ubyte) type] ~ target.port.toBytes() ~ cast (ubyte[]) [0, 0, 0, 42] ~ cast (ubyte[]) username ~ [cast (ubyte) 0] ~ cast (ubyte[]) target.toHostNameString() ~ [cast (ubyte) 0]);
		}
		else {
			super.sendRequest(type, address);
		}
	}
}

class Socks5 : Socks, base.Socks5
{
	static const Method[] Methods = [Method.NoAuthenticationRequired, Method.UsernameAndPassword];

	override void connected ()
	{
		_state = State.MethodNegotiation;

		minimum = 2;

		sendPacket([cast (ubyte) Methods.length] ~ cast (ubyte[]) Methods);
	}

	void sendPacket (ubyte[] data)
	{
		sendData([cast (ubyte) 5] ~ data);
	}

	void sendRequest (Type type, Address address)
	{
		if (auto target = cast (UnresolvedAddress) address) {
			sendPacket(cast (ubyte[]) [cast (ubyte) type, 0, cast (ubyte) NetworkType.HostName, target.toHostNameString().length] ~ cast (ubyte[]) target.toHostNameString() ~ target.port.toBytes());
		}
		else if (auto target = cast (InternetAddress) address) {
			sendPacket(cast (ubyte[]) [cast (ubyte) type, 0, cast (ubyte) NetworkType.IPv4] ~ target.addr.toBytes() ~ target.port.toBytes());
		}
		else if (auto target = cast (Internet6Address) address) {
			sendPacket(cast (ubyte[]) [cast (ubyte) type, 0, cast (ubyte) NetworkType.IPv6] ~ cast (ubyte[]) target.addr() ~ target.port.toBytes());
		}
		else {
			throw new base.SocksError(Reply.AddressTypeNotSupported);
		}
	}

protected:
	enum State
	{
		MethodNegotiation,
		Connecting,
		Authenticating,
		Finished
	}

	override void parseResponse (ref ubyte[] data)
	{
		final switch (_state) {
			case State.MethodNegotiation:
				auto ver    = cast (int) data.front; data.popFront();
				auto method = cast (Method) data.front; data.popFront();

				if (ver != 5) {
					throw new base.SocksError("Socks version 5 not supported");
				}

				switch (method) {
					case Method.NoAuthenticationRequired: sendConnectRequest(); break;
					case Method.UsernameAndPassword:      sendAuthentication(); break;

					default: throw new Exception("proxy did not accept method");
				}
			break;

			case State.Authenticating:
				auto ver    = cast (int) data.front; data.popFront();
				auto status = cast (Reply) data.front; data.popFront();

				if (ver != 5) {
					throw new base.SocksError("Socks version 5 not supported");
				}

				if (status != Reply.Succeeded) {
					throw new base.SocksError("access denied by proxy");
				}

				sendConnectRequest();
			break;

			case State.Connecting:
				auto ver    = cast (int) data[0];
				auto status = cast (Reply) data[1];

				if (ver != 5) {
					throw new Exception("Socks version 5 not supported");
				}

				if (status != Reply.Succeeded) {
					throw new base.SocksError(status);
				}

				if (data.length < 3) {
					minimum = 3;

					return;
				}

				auto type = cast (NetworkType) data[3];
				int  size = 4;

				if (type == NetworkType.IPv4) {
					size += 4;
				}
				else if (type == NetworkType.IPv6 && data.length) {
					size += 16;
				}
				else if (type == NetworkType.HostName) {
					if (data.length < 6) {
						minimum = 6;

						return;
					}
					else {
						size += data[4];
					}
				}
				else {
					assert(0);
				}

				size += 2;

				if (data.length < size) {
					minimum = size;

					return;
				}

				_state = State.Finished;

				data = data[size .. $];

				exchange(dropTo);
			break;

			case State.Finished: break;
		}
	}

	void sendAuthentication ()
	{
		_state = State.Authenticating;

		minimum = 2;

		sendPacket([cast (ubyte) username.length] ~ cast (ubyte[]) username ~ [cast (ubyte) password.length] ~ cast (ubyte[]) password);
	}

	void sendConnectRequest ()
	{
		_state = State.Connecting;
		
		sendRequest(Type.Connect, target);
	}

private:
	State _state;
}

private template ProxyAddressConstructor()
{
	private static string constructorsFor (string signature)
	{
		string parameters; // = signature.split(",").map!(`a[a.lastIndexOf(" ") .. $]`).join(", ");

		foreach (piece; signature.split(",")) {
			parameters ~= ", " ~ piece[piece.lastIndexOf(" ") .. $];
		}

		parameters = parameters[2 .. $];

		return
			`this (` ~ signature ~ `) {
				super(` ~ parameters ~`);

				set(null, null, 5);
			}` ~

			`this (` ~ signature ~ `, string username, string password) {
				super(` ~ parameters ~`);

				set(username, password, 5);
			}` ~

			`this (` ~ signature ~ `, string username) {
				super(` ~ parameters ~`);

				set(username, null, "4a");
			}` ~

			`this (` ~ signature ~ `, string username, string password, string ver) {
				super(` ~ parameters ~`);

				set(username, password, ver);
			}` ~

			`this (` ~ signature ~ `, string username, int ver) {
				super(` ~ parameters ~`);

				set(username, null, ver);
			}`;
	}

	void set (string username, string password, string ver)
	{
		_username = username;
		_password = password;
		_version  = ver;
	}

	void set (string username, string password, int ver)
	{
		_username = username;
		_password = password;
		_version  = ver.to!string;
	}

	@property username ()
	{
		return _username;
	}

	@property password ()
	{
		return _password;
	}

	@property socksVersion ()
	{
		return _version;
	}

private:
	string _username;
	string _password;
	string _version;
}

class ProxyAddress : InternetAddress
{
	mixin ProxyAddressConstructor;

	mixin(constructorsFor("in char[] addr, ushort port"));
	mixin(constructorsFor("uint addr, ushort port"));
	mixin(constructorsFor("ushort port"));
}

class Proxy6Address : Internet6Address
{
	mixin ProxyAddressConstructor;

	mixin(constructorsFor("in char[] node"));
	mixin(constructorsFor("in char[] node, in char[] service"));
	mixin(constructorsFor("in char[] node, ushort port"));
	mixin(constructorsFor("ubyte[16] addr, ushort port"));
	mixin(constructorsFor("ushort port"));
}

Deferrable!Connection connectThrough(T : Connection) (Reactor reactor, Address target, Address through, void delegate (T) callback)
{
	Connection drop_to = (cast (Connection) T.classinfo.create()).created(reactor);
	Socks      proxy;
	string     username;
	string     password;
	string     ver;

	if (auto address = cast (ProxyAddress) through) {
		username = address.username;
		password = address.password;
		ver      = address.socksVersion;
	}
	else if (auto address = cast (Proxy6Address) through) {
		username = address.username;
		password = address.password;
		ver      = address.socksVersion;
	}
	else {
		throw new Error("proxy address unsupported");
	}

	if (ver == "4") {
		proxy = cast (Socks) reactor.connect!Socks4(through);
	}
	else if (ver == "4a") {
		proxy = cast (Socks) reactor.connect!Socks4a(through);
	}
	else if (ver == "5") {
		proxy = cast (Socks) reactor.connect!Socks5(through);
	}
	else {
		throw new Error("version unsupported");
	}

	proxy.initialize(target, drop_to, username, password);

	callback(cast (T) drop_to);
	drop_to.initialized();

	return proxy.deferrable;
}

Deferrable!Connection connectThrough(T : Connection) (Reactor reactor, Address target, Address through)
{
	return reactor.connectThrough!T(target, through, cast (void delegate (T)) reactor.defaultCreationCallback);
}

Deferrable!Connection connectThrough(T : Connection) (Address target, Address through, void delegate (T) callback)
{
	return instance.connectThrough!T(target, through, callback);
}

Deferrable!Connection connectThrough(T : Connection) (Address target, Address through)
{
	return instance.connectThrough!T(target, through);
}

private string declareConnectThrough (string target, string through)
{
	string returnString (string place, string type)
	{
		if (place == "target") {
			switch (type) {
				default: assert(0);

				case "Address": return place;
				case "URI":     return place ~ `.to!Address()`;
				case "string":  return `URI.parse(` ~ place ~ `).to!Address`;
			}
		}
		else if (place == "through") {
			switch (type) {
				default: assert(0);

				case "Address": return place;
				case "URI":     return place ~ `.toProxyAddress()`;
				case "string":  return `URI.parse(` ~ place ~ `).toProxyAddress()`;
			}
		}
		else {
			assert(0);
		}
	}

	return
		`Deferrable!Connection connectThrough(T : Connection) (Reactor reactor, ` ~ target ~ ` target, ` ~ through ~ ` through, void delegate (T) block) {
			return reactor.connectThrough!T(` ~ returnString("target", target) ~ `, ` ~ returnString("through", through) ~ `);
		}` ~

		`Deferrable!Connection connectThrough(T : Connection) (Reactor reactor, ` ~ target ~ ` target, ` ~ through ~ ` through) {
			return reactor.connectThrough!T(` ~ returnString("target", target) ~ `, ` ~ returnString("through", through) ~ `, cast (void delegate (T)) reactor.defaultCreationCallback);
		}` ~

		`Deferrable!Connection connectThrough(T : Connection) (` ~ target ~ ` target, ` ~ through ~ ` through, void delegate (T) block) {
			return instance.connectThrough!T(` ~ returnString("target", target) ~ `, ` ~ returnString("through", through) ~ `);
		}` ~

		`Deferrable!Connection connectThrough(T : Connection) (` ~ target ~ ` target, ` ~ through ~ ` through) {
			return instance.connectThrough!T(` ~ returnString("target", target) ~ `, ` ~ returnString("through", through) ~ `);
		}`;
}

mixin(declareConnectThrough("URI", "URI"));
mixin(declareConnectThrough("string", "string"));
mixin(declareConnectThrough("Address", "URI"));
mixin(declareConnectThrough("URI", "Address"));
mixin(declareConnectThrough("Address", "string"));
mixin(declareConnectThrough("string", "Address"));
mixin(declareConnectThrough("URI", "string"));
mixin(declareConnectThrough("string", "URI"));

private:
	ubyte[] toBytes(T) (T data)
	{
		auto result = new ubyte[T.sizeof];

		for (int i = T.sizeof - 1; i >= 0; i--) {
			result[i]   = data & 0xff;
			data      >>= 8;
		}

		return result;
	}

	Address toProxyAddress (URI uri)
	{
		string ver;

		enforce(uri.scheme.name.startsWith("socks"), "unknown protocol");
		enforce(["4", "4a", "5", ""].canFind(ver = uri.scheme.name[5 .. $]));

		return new ProxyAddress(uri.host, uri.port, uri.username, uri.password, ver.empty ? "5" : ver);
	}
