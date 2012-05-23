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

module nucular.server;

import std.exception;
import std.socket;

import nucular.reactor : Reactor;
import nucular.descriptor;
import nucular.connection;

abstract class Server
{
	this (Reactor reactor, Address address)
	{
		_reactor = reactor;

		_address = address;
	}

	this (Reactor reactor, Descriptor descriptor)
	{
		_reactor = reactor;

		_connection = (new Connection).watched(reactor, descriptor);
		_address    = new UnknownAddress;
	}

	abstract Descriptor start ();

	void stop ()
	{
		if (!_running) {
			return;
		}

		_running = false;

		reactor.stopServer(this);
	}

	@property block (void delegate (Connection) block)
	{
		_block = block;
	}

	@property handler (TypeInfo_Class handler)
	{
		_handler = handler;
	}

	@property running ()
	{
		return _running;
	}

	@property reactor ()
	{
		return _reactor;
	}

protected:
	Reactor _reactor;

	Address    _address;
	Connection _connection;

	TypeInfo_Class             _handler;
	void delegate (Connection) _block;

	bool _running;
}

class TCPServer : Server
{
	this (Reactor reactor, Address address)
	{
		super(reactor, address);
	}

	this (Reactor reactor, Descriptor descriptor)
	{
		super(reactor, descriptor);
	}

	override Descriptor start ()
	{
		if (_connection) {
			return cast (Descriptor) _connection;
		}

		_socket = new TcpSocket;

		_connection = (new Connection).watched(reactor, new Descriptor(_socket));
		_connection.asynchronous = true;
		_connection.reuseAddr    = true;

		_socket.bind(_address);
		_socket.listen(reactor.backlog);

		_running = true;

		return cast (Descriptor) _connection;
	}

	Connection accept ()
	{
		auto connection = cast (Connection) _handler.create();
		auto socket     = _socket.accept();
		auto descriptor = new Descriptor(socket);

		connection.accepted(this, descriptor);
		if (_block) {
			_block(connection);
		}
		connection.initialized();

		return connection;
	}

	override string toString ()
	{
		return "Server(" ~ (cast (Descriptor) _connection).toString() ~ ")";
	}

private:
	TcpSocket _socket;
}
