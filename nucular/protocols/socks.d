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

import nucular.reactor : Reactor, instance;
import nucular.connection;

class Proxy : Connection
{
	Proxy initialize (Connection drop_to, in char[] username, in char[] password, in char[] ver)
	{
		_drop_to  = drop_to;
		_username = username.dup;
		_password = password.dup;
		_version  = ver.dup;

		return this;
	}

	override void connected ()
	{
		// TODO: initialize SOCKS handhsake
	}

	override void receiveData (ubyte[] data)
	{
		// TODO: handle SOCKS stuff
	}

	@property username ()
	{
		return _username;
	}

	@property password () {
		return _password;
	}

	@property socksVersion ()
	{
		return _version;
	}

	@property dropTo ()
	{
		return _drop_to;
	}

private:
	char[]     _username;
	char[]     _password;
	char[]     _version;
	Connection _drop_to;
}

Connection connectThrough(T : Connection) (Reactor reactor, Address target, Address through, in char[] username = null, in char[] password = null, in char[] ver = null)
{
	Connection drop_to = (cast (Connection) T.classinfo.create()).created(reactor);

	// FIXME: remove the useless cast when the bug is fixed
	Proxy proxy = cast (Proxy) cast (Object) reactor.connect!Proxy(target);
	      proxy.initialize(drop_to, username, password, ver);

	return drop_to;
}

Connection connectThrough(T : Connection) (Address target, Address through, in char[] username = null, in char[] password = null, in char[] ver = null)
{
	return connectThrough!(T)(instance, target, through, username, password, ver);
}
