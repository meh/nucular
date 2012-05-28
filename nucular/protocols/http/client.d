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

module nucular.protocols.http.client;

import std.array;

import nucular.reactor : Reactor, instance, Address, Connection;
import nucular.deferrable;
import nucular.protocols.socks;
import nucular.protocols.http.request;

class Client
{
	this ()
	{
		this(instance);
	}

	this (Reactor reactor)
	{
		_reactor = reactor;
	}

	Connection connect (Address target)
	{
		return _connection = reactor.connect!HTTPConnection(target, (HTTPConnection conn) {
			conn.http = this;
		});
	}

	Connection connectThrough (Address target, Address through, string username = null, string password = null, string ver = "5")
	{
		return _connection = reactor.connectThrough!HTTPConnection(target, through, (HTTPConnection conn) {
			conn.http = this;
		}, username, password, ver).data;
	}

	/++
	 + Tells the Client to use the passed connection.
	 +
	 + The Connection is supposed to be already connected and you will have to deal
	 + with the response yourself, there are helpers to deal with them anyway.
	 +/
	@property use (Connection connection)
	{
		_connection = connection;

		autoFlush = true;
	}

	/++
	 + Send the requests.
	 +/
	void flush ()
	{
		while (!_requests.empty) {
			auto request = _requests.front; _requests.popFront();

			request.send(_connection);
		}
	}

	@property autoFlush ()
	{
		return _auto_flush;
	}

	@property autoFlush (bool value)
	{
		_auto_flush = value;

		if (value) {
			flush();
		}
	}

	@property connection ()
	{
		return _connection;
	}

	@property reactor ()
	{
		return _reactor;
	}

private:
	Reactor    _reactor;
	Connection _connection;

	Request[] _requests;

	bool _auto_flush;

private:
	class HTTPConnection : Connection
	{
		override void connected ()
		{
			http.autoFlush = true;
		}

		@property http ()
		{
			return _http;
		}

		@property http (Client value)
		{
			_http = value;
		}

	private:
		Client _http;
	}
}
