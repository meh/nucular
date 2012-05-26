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

import std.exception;
import std.socket;
import std.conv;
import std.array;
import std.string;

version (Posix) {
	import core.sys.posix.arpa.inet;
}

import nucular.reactor : Reactor, instance;
import nucular.deferrable;
import nucular.connection;

class ProxiedAddress : UnknownAddress
{
	this (string host, ushort port)
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
		return _host;
	}

private:
	string _host;
	ushort _port;
}

abstract class SOCKS : Connection
{
	SOCKS initialize (Address target, Connection drop_to, string username = null, string password = null)
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

		if (!_data.empty) {
			other.receiveData(_data);
		}
	}

	override void receiveData (ubyte[] data)
	{
		_data ~= data;

		try {
			parseResponse(_data);
		}
		catch (Exception e) {
			if (_deferrable.hasErrback) {
				_deferrable.failWith(e);
			}
			else {
				throw e;
			}
		}
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

	ubyte[] _data;
}

class SOCKSError : Error
{
	this (string message)
	{
		super(message);
	}

	this (SOCKS4.Reply code)
	{
		string message;

		final switch (code) {
			case SOCKS4.Reply.Granted:                throw new Error("there were no errors, why did you call this?");
			case SOCKS4.Reply.Rejected:               message = "rejected or failed request"; break;
			case SOCKS4.Reply.IdentdNotRunning:       message = "identd isn't running"; break;
			case SOCKS4.Reply.IdentdNotAuthenticated: message = "identd failed the authentication"; break;
		}

		super(message);
	}

	this (SOCKS5.Reply code)
	{
		string message;

		final switch (code) {
			case SOCKS5.Reply.Succeeded:               throw new Error("there were no errors, why did you call this?");
			case SOCKS5.Reply.GeneralError:            message = "general SOCKS server failure"; break;
			case SOCKS5.Reply.ConnectionNotAllowed:    message = "connection not allowed by ruleset"; break;
			case SOCKS5.Reply.NetworkUnreachable:      message = "network unreachable"; break;
			case SOCKS5.Reply.HostUnreachable:         message = "host unreachable"; break;
			case SOCKS5.Reply.ConnectionRefused:       message = "connection refused"; break;
			case SOCKS5.Reply.TTLExpired:              message = "TTL expired"; break;
			case SOCKS5.Reply.CommandNotSupported:     message = "command not supported"; break;
			case SOCKS5.Reply.AddressTypeNotSupported: message = "address type not supported"; break;
		}

		super(message);
	}
}

class SOCKS4 : SOCKS
{
	enum Type {
		StreamConnection = 0x01,
		PortBinding
	}

	enum Reply {
		Granted = 0x5a,
		Rejected,
		IdentdNotRunning,
		IdentdNotAuthenticated
	}

	void sendPacket (ubyte[] data)
	{
		sendData([cast (ubyte) 4] ~ data);
	}

	void sendRequest (Type type, Address address)
	{
		if (auto target = cast (InternetAddress) address) {
			sendPacket(cast (ubyte[]) [cast (ubyte) type] ~ toData(target.port()) ~ toData(target.addr()) ~ cast (ubyte[]) username ~ [cast (ubyte) 0]);
		}
		else {
			throw new SOCKSError("address not supported");
		}
	}

	override void connected ()
	{
		sendRequest(Type.StreamConnection, target);
	}

protected:
	override void parseResponse (ref ubyte[] data)
	{
		if (data.length < 8) {
			return;
		}

		// drop null byte
		data.popFront();

		auto status = cast (Reply) data.front; data.popFront();

		if (status != Reply.Granted) {
			throw new SOCKSError(status);
		}

		foreach (_; 0 .. 6) {
			data.popFront();
		}

		deferrable.succeed();
		exchange(dropTo);
	}
}

class SOCKS4a : SOCKS4
{
	override void sendRequest (Type type, Address address)
	{
		if (auto target = cast (ProxiedAddress) address) {
			sendPacket(cast (ubyte[]) [cast (ubyte) type] ~ toData(target.port()) ~ cast (ubyte[]) [0, 0, 0, 42] ~ cast (ubyte[]) username ~ [cast (ubyte) 0] ~ cast (ubyte[]) target.toHostNameString() ~ [cast (ubyte) 0]);
		}
		else {
			super.sendRequest(type, address);
		}
	}
}

class SOCKS5 : SOCKS
{
	enum State {
		MethodNegotiation,
		Connecting,
		Authenticating,
		Finished
	}

	enum Method {
		NoAuthenticationRequired,
		GSSAPI,
		UsernameAndPassword,
		ChallengeHandshakeAuthenticationProtocol,
		ChallengeResponseAuthenticationMethod = 0x05,
		SecureSocketsLayer,
		NDSAuthentication,
		MultiAuthenticationFramework,
		
		NoAcceptable = 0xFF
	}

	enum Type {
		Connect = 1,
		Bind,
		UDPAssociate
	}
	
	enum NetworkType {
		IPv4     = 0x01,
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
		ubyte[] toData(T) (T data)
		{
			ubyte[] result;

			for (int i = 0; i < T.sizeof; i++) {
				result  ~= cast (ubyte) (data & 0xff);
				data   >>= 8;
			}

			return result;
		}

		if (auto target = cast (ProxiedAddress) address) {
			sendPacket(cast (ubyte[]) [cast (ubyte) type, 0, cast (ubyte) NetworkType.HostName, target.toHostNameString().length] ~ cast (ubyte[]) target.toHostNameString() ~ toData(target.port()));
		}
		else if (auto target = cast (InternetAddress) address) {
			sendPacket(cast (ubyte[]) [cast (ubyte) type, 0, cast (ubyte) NetworkType.IPv4] ~ toData(target.addr()) ~ toData(target.port()));
		}
		else if (auto target = cast (Internet6Address) address) {
			sendPacket(cast (ubyte[]) [cast (ubyte) type, 0, cast (ubyte) NetworkType.IPv6] ~ cast (ubyte[]) target.addr() ~ toData(target.port()));
		}
		else {
			throw new SOCKSError(Reply.AddressTypeNotSupported);
		}
	}

protected:
	override void parseResponse (ref ubyte[] data)
	{
		final switch (_state) {
			case State.MethodNegotiation:
				if (data.length < 2) {
					return;
				}

				auto ver    = cast (int) data.front; data.popFront();
				auto method = cast (Method) data.front; data.popFront();

				if (ver != 5) {
					throw new SOCKSError("SOCKS version 5 not supported");
				}

				switch (method) {
					case Method.NoAuthenticationRequired: sendConnectRequest(); break;
					case Method.UsernameAndPassword:      sendAuthentication(); break;

					default: throw new Exception("proxy did not accept method");
				}
			break;

			case State.Authenticating:
				if (data.length < 2) {
					return;
				}

				auto ver    = cast (int) data.front; data.popFront();
				auto status = cast (Reply) data.front; data.popFront();

				if (ver != 5) {
					throw new SOCKSError("SOCKS version 5 not supported");
				}

				if (status != Reply.Succeeded) {
					throw new SOCKSError("access denied by proxy");
				}

				sendConnectRequest();
			break;

			case State.Connecting:
				if (data.length < 2) {
					return;
				}

				auto ver    = cast (int) data[0];
				auto status = cast (Reply) data[1];

				if (ver != 5) {
					throw new Exception("SOCKS version 5 not supported");
				}

				if (status != Reply.Succeeded) {
					throw new SOCKSError(status);
				}

				if (data.length < 3) {
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
					return;
				}

				_state = State.Finished;

				foreach (_; 0 .. size) {
					data.popFront();
				}

				exchange(dropTo);
			break;

			case State.Finished: break;
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
		
		sendRequest(Type.Connect, target);
	}

private:
	State _state;
}

Deferrable!Connection connectThrough(T : Connection) (Reactor reactor, Address target, Address through, string username = null, string password = null, in string ver = "5")
{
	Connection drop_to = (cast (Connection) T.classinfo.create()).created(reactor);
	SOCKS      proxy;

	if (ver == "4") {
		proxy = cast (SOCKS) cast (Object) reactor.connect!SOCKS4(through);
	}
	else if (ver == "4a") {
		proxy = cast (SOCKS) cast (Object) reactor.connect!SOCKS4a(through);
	}
	else if (ver == "5") {
		// FIXME: remove the useless cast when the bug is fixed
		proxy = cast (SOCKS) cast (Object) reactor.connect!SOCKS5(through);
	}
	else {
		throw new Error("version unsupported");
	}

	proxy.initialize(target, drop_to, username, password);

	return proxy.deferrable;
}

Deferrable!Connection connectThrough(T : Connection) (Address target, Address through, string username = null, string password = null, in string ver = "5")
{
	return connectThrough!(T)(instance, target, through, username, password, ver);
}

private:
	ubyte[] toData(T) (T data)
	{
		ubyte[] result;

		for (int i = 0; i < T.sizeof; i++) {
			result  ~= cast (ubyte) (data & 0xff);
			data   >>= 8;
		}

		return result;
	}
