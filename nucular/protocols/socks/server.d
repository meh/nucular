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

module nucular.protocols.socks.server;

public import nucular.reactor : Address, InternetAddress, Internet6Address;
public import nucular.protocols.dns.resolver : UnresolvedAddress;

import std.conv;
import std.array;
import std.exception;

import nucular.connection;
import buffered = nucular.protocols.buffered;
import base = nucular.protocols.socks.base;

abstract class Socks : buffered.Protocol
{
	final override void receiveBufferedData (ref ubyte[] data)
	{
		try {
			parseRequest(data);
		}
		catch (Exception e) {
			failedRequest(e);
		}
	}

	final override void receiveUnbufferedData (ubyte[] data)
	{
		receiveProxyData(data);
	}

	void receiveProxyData (ubyte[] data)
	{
		// this is just a place holder
	}

	void failedRequest (Exception e)
	{
		// this is just a place holder
	}

protected:
	abstract void parseRequest (ref ubyte[] data);
}

class Socks4 : Socks, base.Socks4
{
	void sendResponse (Reply reply)
	{
		sendData(cast (ubyte[]) [0, reply, 0, 0, 0, 0, 0, 0]);
	}

	void request (Type type, Address address, string username)
	{
		// this is just a place holder
	}

protected:
	override void parseRequest (ref ubyte[] data)
	{
		if (data.length < 9) {
			minimum = 9;

			return;
		}

		enforceEx!(base.SocksError)(data[0] == 4, "wrong SOCKS version");

		Type   type = cast (Type) data[1];
		ushort port = data[2 .. 4].fromBytes!ushort;
		uint   addr = data[4 .. 8].fromBytes!uint;
		int    end  = -1;

		foreach (index, piece; data[8 .. $]) {
			if (piece == 0) {
				end = index.to!int + 1;

				break;
			}
		}

		if (end == -1) {
			return;
		}

		string username = cast (string) data[8 .. 8 + end];

		request(type, new InternetAddress(addr, port), username);

		data       = data[8 + end .. $];
		unbuffered = true;
	}
}

class Socks4a : Socks, base.Socks4
{
	void sendResponse (Reply reply)
	{
		sendData(cast (ubyte[]) [0, reply, 0, 0, 0, 0, 0, 0]);
	}

	void request (Type type, Address address, string username)
	{
		// this is just a place holder
	}

protected:
	override void parseRequest (ref ubyte[] data)
	{
		if (data.length < 9) {
			minimum = 9;

			return;
		}

		enforceEx!(base.SocksError)(data[0] == 4, "wrong SOCKS version");

		Type   type         = cast (Type) data[1];
		ushort port         = data[2 .. 4].fromBytes!ushort;
		uint   addr         = data[4 .. 8].fromBytes!uint;
		bool   needs_host   = false;
		int    username_end = -1;

		if (addr >> 8 == 0 && addr != 0) {
			needs_host = true;
		}

		foreach (index, piece; data[8 .. $]) {
			if (piece == 0) {
				username_end = index.to!int + 1;

				break;
			}
		}

		if (username_end == -1) {
			return;
		}

		string username = cast (string) data[8 .. 8 + username_end];

		if (needs_host) {
			int host_end = -1;

			foreach (index, piece; data[8 + username_end .. $]) {
				if (piece == 0) {
					host_end = index.to!int + 1;

					break;
				}
			}

			if (host_end == -1) {
				return;
			}

			string host = cast (string) data[8 + username_end .. 8 + username_end + host_end];

			request(type, new UnresolvedAddress(host, port), username);

			data = data[8 + username_end + host_end .. $];
		}
		else {
			request(type, new InternetAddress(addr, port), username);

			data = data[8 + username_end .. $];
		}

		unbuffered = true;
	}
}

class Socks5 : Socks, base.Socks5
{
	void request (Type type, Address address, string username)
	{
		// this is just a place holder
	}

protected:
	override void parseRequest (ref ubyte[] data)
	{

	}
}

private:
	T fromBytes(T) (ubyte[] data)
	{
		T result = 0;

		for (int i = 0; i < T.sizeof; i++) {
			result |= data[i];

			if (i != T.sizeof - 1) {
				result <<= 8;
			}
		}

		return result;
	}
