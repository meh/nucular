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

import std.socket;
import std.conv;

version (Posix) {
	import core.sys.posix.arpa.inet;
}

class UnresolvedAddress : UnknownAddress
{
	this (string host)
	{
		_host = host;
	}

	this (string host, ushort port)
	{
		_host = host;
		_port = port;
	}

	@property port ()
	{
		return _port;
	}

	@property host ()
	{
		return _host;
	}

	override string toPortString ()
	{
		return _port.to!string;
	}

	override string toAddrString ()
	{
		return _host;
	}

	override string toHostNameString ()
	{
		return _host;
	}

private:
	string _host;
	ushort _port;
}
