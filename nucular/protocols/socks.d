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

module nucular.protocols.socks;

import std.socket;
import std.conv;
import std.array;
import std.algorithm;

version (Posix) {
	import core.sys.posix.arpa.inet;
}

import nucular.reactor : Reactor, instance;
import nucular.connection;

class ProxiedAddress : UnknownAddress
{
	this (char[] host, ushort port)
	{
		_host = host;
		_port = port;
	}

	ushort port ()
	{
		return ntohs(_port);
	}

	override string toPortString ()
	{
		return _port.to!string;
	}

	override string toHostNameString ()
	{
		return cast (string) _host;
	}

private:
	char[] _host;
	ushort _port;
}

abstract class SOCKS : Connection
{
	SOCKS initialize (Address target, Connection drop_to, in char[] username = null, in char[] password = null)
	{
		_target   = target;
		_drop_to  = drop_to;

		if (username) {
			_username = username.dup;
		}

		if (password) {
			_password = password.dup;
		}

		return this;
	}

	override void receiveData (ubyte[] data)
	{
		_data ~= data;

		parseResponse(_data);
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

protected:
	abstract void parseResponse (ubyte[] data);

private:
	Address    _target;
	Connection _drop_to;

	char[] _username;
	char[] _password;

	ubyte[] _data;
}

class SOCKS5 : SOCKS
{
	enum State {
		MethodNegotiation,
		Connecting,
		Authenticating
	}

	enum Method {
		NoAuthenticationRequired,
		GSSAPI,
		UsernameAndPassword,
		IANAAssigned,
		
		NoAcceptable = 0xFF
	}

	enum Type {
		Connect = 1,
		Bind,
		UDPAssociate
	}
	
	enum NetworkType {
		IPv4,
		HostName = 0x03,
		IPv6
	}

	enum Reply {
		Succeeded,
		GeneralError,
		ConnectionNotAllowed,
		NetworkUnreachable,
		HostUnreachable,
		ConnectionRefused,
		TTLExpired,
		CommandNotSupported,
		AddressTypeNotSupported
	}

	static const Method[] Methods = [Method.NoAuthenticationRequired, Method.UsernameAndPassword];

	override void connected ()
	{
		_state = State.MethodNegotiation;

		sendPacket([cast (ubyte) Methods.length] ~ cast (ubyte[]) Methods);
	}

	void sendPacket (ubyte[] data)
	{
		sendData([cast (ubyte) 5] ~ data);
	}

	void sendRequest (Type type, Address address)
	{
		ubyte[] portToData (ushort port)
		{
			return cast (ubyte[]) [port >> 8, port & 0x00ff];
		}

		ubyte[] ipv4ToData (uint port)
		{
			return cast (ubyte[]) [];
		}

		if (auto target = cast (ProxiedAddress) address) {
			sendPacket(cast (ubyte[]) [cast (ubyte) type, 0, cast (ubyte) NetworkType.HostName, target.toHostNameString().length] ~ cast (ubyte[]) target.toHostNameString() ~ portToData(target.port()));
		}
		else if (auto target = cast (InternetAddress) address) {
			sendPacket(cast (ubyte[]) [cast (ubyte) type, 0, cast (ubyte) NetworkType.IPv4] ~ ipv4ToData(target.addr()) ~ portToData(target.port()));
		}
		else if (auto target = cast (Internet6Address) address) {
			sendPacket(cast (ubyte[]) [cast (ubyte) type, 0, cast (ubyte) NetworkType.IPv6] ~ cast (ubyte[]) target.addr() ~ portToData(target.port()));
		}
		else {
			throw new Error("address unsupported");
		}
	}

protected:
	override void parseResponse (ubyte[] data)
	{
		final switch (_state) {
			case State.MethodNegotiation:
				if (data.length < 2) {
					return;
				}

				// ignore the version number
				data.popFront();

				auto method = cast (Method) data.front; data.popFront();

				switch (method) {
					case Method.NoAuthenticationRequired: sendConnectRequest(); break;
					case Method.UsernameAndPassword:      sendAuthentication(); break;

					default: throw new Error("proxy did not accept method");
				}
			break;

			case State.Authenticating:
				if (data.length < 2) {
					return;
				}

				auto ver    = cast (int) data.front; data.popFront();
				auto status = cast (Reply) data.front; data.popFront();

				if (ver != 5) {
					throw new Error("SOCKS version 5 not supported");
				}

				if (status != Reply.Succeeded) {
					throw new Error("access denied by proxy");
				}

				sendConnectRequest();
			break;

			case State.Connecting:

			break;
		}
	}

	void sendAuthentication ()
	{
		_state = State.Authenticating;

		sendPacket([cast (ubyte) username.length] ~ cast (ubyte[]) username ~ [cast (ubyte) password.length] ~ cast (ubyte[]) password);
	}

	void sendConnectRequest ()
	{
		_state = State.Connecting;
		
	}

private:
	State _state;
}

Connection connectThrough(T : Connection) (Reactor reactor, Address target, Address through, in char[] username = null, in char[] password = null, in string ver = "5")
{
	Connection drop_to = (cast (Connection) T.classinfo.create()).created(reactor);

	if (ver == "5") {
		// FIXME: remove the useless cast when the bug is fixed
		SOCKS proxy = cast (SOCKS) cast (Object) reactor.connect!SOCKS5(target);
					proxy.initialize(target, drop_to, username, password);
	}
	else {
		throw new Error("version unsupported");
	}

	return drop_to;
}

Connection connectThrough(T : Connection) (Address target, Address through, in char[] username = null, in char[] password = null, in string ver = "5")
{
	return connectThrough!(T)(instance, target, through, username, password, ver);
}
