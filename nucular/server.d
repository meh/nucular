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

class Server {
	this (Reactor reactor, Address address) {
		_reactor = reactor;

		_address = address;
	}

	this (Reactor reactor, Descriptor descriptor) {
		_reactor = reactor;

		_descriptor = descriptor;
		_address    = new UnknownAddress;
	}

	void start () {
		if (_descriptor) {
			return;
		}

		_socket = new TcpSocket;
		_socket.bind(_address);
		_socket.listen(reactor.backlog);

		_descriptor = new Descriptor(_socket.handle, &_socket);
		_descriptor.asynchronous = true;

		_running = true;
	}

	void stop () {
		_running = false;
	}

	Connection accept () {
		auto connection = cast (Connection) _handler.create();
		auto socket     = _socket.accept();
		auto descriptor = new Descriptor(socket.handle, &socket);

		return connection.accepted(this, descriptor);
	}

	@property handler (TypeInfo_Class handler) {
		_handler = handler;
	}

	@property block (void function (Connection) block) {
		_block = block;
	}

	@property running () {
		return _running;
	}

	@property reactor () {
		return _reactor;
	}

private:
	Reactor _reactor;

	Address    _address;
	Descriptor _descriptor;
	Socket     _socket;

	TypeInfo_Class             _handler;
	void function (Connection) _block;

	bool _running;
}
