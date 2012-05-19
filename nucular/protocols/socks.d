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

import nucular.reactor : Reactor, instance;
import std.socket;

class Proxy : Connection
{
	void connectionCompleted () {

	}

	void receiveData (ubyte[] data) {

	}

	@property dropTo () {
		return _drop_to;
	}

	@property dropTo (Connection value) {
		_drop_to = value;
	}

private:
	Connection _drop_to;
}

private template AdditionalData
{
	@property username ()
	{
		return _username;
	}

	@property password ()
	{
		return _password;
	}

private:
	const char[] _username;
	const char[] _password;
}

class ProxyAddress : InternetAddress
{
	this (in char[] addr, ushort port, in char[] username = null, in char[] password = null)
	{
		super(addr, port);

		_username = username;
		_password = password;
	}

	this (uint addr, ushort port, in char[] username = null, in char[] password = null)
	{
		super(addr, port);

		_username = username;
		_password = password;
	}

	mixin(AdditionalData);
}

class Proxy6Address : Internet6Address {
	this (in char[] node, in char[] service, in char[] username = null, in char[] password = null)
	{
		super(node, service);

		_username = username;
		_password = password;
	}

	this (in char[] node, ushort port, in char[] username = null, in char[] password = null)
	{
		super(node, port);

		_username = username;
		_password = password;
	}

	this (ubyte[16] addr, ushort port, in char[] username = null, in char[] password = null)
	{
		super(addr, port);

		_username = username;
		_password = password;
	}

	mixin(AdditionalData);
}

Connection connectThrough(T : Address, T2 : Connection) (Reactor reactor, Address target)
	if (is (through : ProxyAddress) || is (through : Proxy6Address))
{
	Connection drop_to = (cast (Connection) T.classinfo.create()).created(reactor);
	Connection proxy   = reactor.connect!Proxy(target);

	proxy.dropTo = drop_to;

	return drop_to;
}

Connection connectThrough(T : Address, T2 : Connection) (Address target)
	if (is (through : ProxyAddress) || is (through : Proxy6Address))
{
	return instance.connectThrough!(T, T2)(target);
}
