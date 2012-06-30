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

module nucular.reactor;

public import std.socket         : Address, InternetAddress, Internet6Address, parseAddress, getAddress;
public import core.time          : dur, Duration;
public import nucular.uri        : URI;
public import nucular.connection : Connection, Security;
public import nucular.descriptor : Descriptor;
public import nucular.server     : Server;
public import nucular.signal     : trap;
public import nucular.security   : SecureInternetAddress, SecureInternet6Address;

version (Posix) {
	public import nucular.server : UnixAddress, NamedPipeAddress, mode_t;

	import core.sys.posix.unistd;
	import core.sys.posix.fcntl;
}

import core.sync.mutex;
import std.array;
import std.algorithm;
import std.exception;
import std.datetime;
import std.socket;
import std.parallelism;
import std.string;
import std.conv;

import nucular.threadpool;
import nucular.timer;
import nucular.periodictimer;
import nucular.deferrable;
import nucular.descriptor;
import nucular.server;
import nucular.selector.best;
import nucular.signal;
import nucular.queue;

class Reactor
{
	this ()
	{
		_mutex    = new Mutex;
		_selector = new Selector;

		_backlog = 100;
		_quantum = 100.dur!"msecs";
		_running = false;

		_default_creation_callback = (a) { };
	}

	~this ()
	{
		stop();
	}

	void run (void delegate () block)
	{
		schedule(block);

		if (_running) {
			return;
		}

		_running = true;

		while (isRunning) {
			while (hasScheduled) {
				_scheduled.front()();

				synchronized (_mutex) {
					_scheduled.popFront();
				}
			}

			if (!isRunning || hasScheduled) {
				continue;
			}

			if (isClosePending) {
				foreach (descriptor, connection; _closing) {
					if (!connection.isWritePending && connection.isEOF) {
						closeConnection(connection);
					}
				}
			}

			Selected selected;
			if (isConnectPending || isWritePending) {
				selected = hasTimers ? _selector.available(minimumSleep): _selector.available();
			}
			else {
				selected = hasTimers ? _selector.available!"read"(minimumSleep) : _selector.available!"read"();
			}

			if (!isRunning) {
				continue;
			}

			executeTimers();

			foreach (descriptor; selected.read) {
				if (descriptor in _servers) {
					auto current = _servers[descriptor];

					if (auto server = cast (TcpServer) current) {
						Connection accepted;

						while ((accepted = server.accept()) !is null) {
							auto connection = accepted;
							     descriptor = connection.to!Descriptor;

							schedule({
								_selector.add(descriptor);
								_connections[descriptor] = connection;
							});
						}

						continue;
					}

					if (auto server = cast (UdpServer) current) {
						Connection       connection = server.connection;
						Connection.Data* data;

						while ((data = connection.receiveFrom(512)) !is null) {
							auto tmp = connection.defaultTarget;

							connection.defaultTarget = data.address;
							connection.receiveData(data.content);
							connection.defaultTarget = tmp;
						}

						continue;
					}

					version (Posix) {
						if (auto server = cast (UnixServer) current) {
							Connection accepted;

							while ((accepted = server.accept()) !is null) {
								auto connection = accepted;
								     descriptor = connection.to!Descriptor;

								schedule({
									_selector.add(descriptor);
									_connections[descriptor] = connection;
								});
							}

							continue;
						}

						if (auto server = cast (FifoServer) current) {
							auto connection = server.connection;
							auto data       = server.read();

							if (!data.empty) {
								connection.receiveData(data);
							}
							
							continue;
						}
					}

					assert(0);
				}
				else if (descriptor in _connections) {
					auto connection = _connections[descriptor];
					auto data       = connection.read();

					if (!data.empty) {
						connection.receiveData(data);
					}
				}
				else if (descriptor in _connecting) {
					closeConnection(_connecting[descriptor]);
				}
			}

			if (isWritePending && !selected.write.empty) {
				isWritePending = false;
			}

			foreach (descriptor; selected.write) {
				if (descriptor in _connecting) {
					auto connection = _connecting[descriptor];

					_connecting.remove(descriptor);

					if (connection.error) {
						connection.close();
						connection.unbind();
					}
					else {
						connection.addresses();
						connection.connected();

						_connections[descriptor] = connection;
					}
				}
				else if (descriptor in _connections) {
					if (!_connections[descriptor].write() && !isWritePending) {
						isWritePending = true;
					}
				}
				else if (descriptor in _closing) {
					auto connection = _closing[descriptor];

					if (!connection.write()) {
						isWritePending = true;
					}
					else {
						connection.shutdown();
					}
				}
			}

			if (!isWritePending) {
				foreach (connection; _connections) {
					if (connection.isWritePending) {
						isWritePending = true;
						
						break;
					}
				}
			}

			foreach (descriptor; selected.error) {
				if (descriptor in _connections) {
					closeConnection(_connections[descriptor]);
				}
				else if (descriptor in _servers) {
					stopServer(_servers[descriptor]);
				}
				else if (descriptor in _connecting) {
					closeConnection(_connecting[descriptor]);
				}
			}

			if (!isRunning) {
				continue;
			}

			while (hasNextTick) {
				_next_tick.front()();

				synchronized (_mutex) {
					_next_tick.popFront();
				}
			}
		}
	}

	void schedule (void delegate () block)
	{
		synchronized (_mutex) {
			_scheduled.pushBack(block);
		}

		wakeUp();
	}

	void nextTick (void delegate () block)
	{
		synchronized (_mutex) {
			_next_tick.pushBack(block);
		}

		wakeUp();
	}

	void stop ()
	{
		if (!isRunning) {
			return;
		}

		foreach (server; _servers) {
			server.stop();
		}

		_running = false;

		wakeUp();
	}

	void defer(T) (T delegate () operation)
	{
		threadpool.process(operation);
	}

	void defer(T) (T delegate () operation, void delegate (T) callback)
	{
		threadpool.process({
			callback(operation());
		});
	}

	void defer(T : AbstractTask) (T task)
	{
		threadpool.process(task);
	}

	Deferrable!T deferrable(T) ()
	{
		return new Deferrable!T(this);
	}

	Deferrable!T deferrable(T) (T data)
	{
		return new Deferrable!T(this, data);
	}

	Deferrable!T deferrable(T) (T data, void delegate () callback)
	{
		return deferrable(data).callback(callback);
	}

	Deferrable!T deferrable(T) (void delegate () callback)
	{
		return deferrable!T.callback(callback);
	}

	Deferrable!T deferrable(T) (T data, void delegate () callback, void delegate () errback)
	{
		return deferrable(data).callback(callback).errback(errback);
	}

	Deferrable!T deferrable(T) (void delegate () callback, void delegate () errback)
	{
		return deferrable!T.callback(callback).errback(errback);
	}

	Server startServer(T : Connection) (Address address, string protocol, void delegate (T) block)
	{
		return _startServer(T.classinfo, address, protocol, cast (void delegate (Connection)) block);
	}

	Server startServer(T : Connection) (Address address, string protocol)
	{
		return startServer!T(address, protocol, cast (void delegate (T)) defaultCreationCallback);
	}

	Server startServer(T : Connection) (Address address, void delegate (T) block)
	{
		return startServer!T(address, address.toProtocol(), block);
	}

	Server startServer(T : Connection) (Address address)
	{
		return startServer!T(address, address.toProtocol(), cast (void delegate (T)) defaultCreationCallback);
	}

	Server startServer(T : Connection) (Address address)
	{
		return startServer!T(address, address.toProtocol(), cast (void delegate (T)) defaultCreationCallback);
	}

	Server startServer(T : Connection) (URI uri, void delegate (T) block)
	{
		return startServer!T(uri.to!Address, uri.scheme.protocol, block);
	}

	Server startServer(T : Connection) (URI uri)
	{
		return startServer!T(uri, cast (void delegate (T)) defaultCreationCallback);
	}

	Server startServer(T : Connection) (string uri, void delegate (T) block)
	{
		return startServer!T(URI.parse(uri), block);
	}

	Server startServer(T : Connection) (string uri)
	{
		return startServer!T(URI.parse(uri));
	}

	void stopServer (Server server)
	{
		server.stop();

		schedule({
			_selector.remove(server.to!Descriptor);
			_connections.remove(server.connection.to!Descriptor);
		});
	}

	T connect(T : Connection) (Address address, string protocol, void delegate (T) block)
	{
		return cast (T) _connect(T.classinfo, address, protocol, cast (void delegate (Connection)) block);
	}

	T connect(T : Connection) (Address address, string protocol)
	{
		return connect!T(address, protocol, cast (void delegate (T)) defaultCreationCallback);
	}

	T connect(T : Connection) (Address address, void delegate (T) block)
	{
		return connect!T(address, address.toProtocol(), block);
	}

	T connect(T : Connection) (Address address)
	{
		return connect!T(address, address.toProtocol());
	}

	T connect(T : Connection) (URI uri, void delegate (T) block)
	{
		return connect!T(uri.to!Address, uri.scheme.protocol, block);
	}

	T connect(T : Connection) (URI uri)
	{
		return connect!T(uri, cast (void delegate (T)) defaultCreationCallback);
	}

	T connect(T : Connection) (string uri, void delegate (T) block)
	{
		return connect!T(URI.parse(uri), block);
	}

	T connect(T : Connection) (string uri)
	{
		return connect!T(URI.parse(uri));
	}

	T watch(T : Connection) (Descriptor descriptor, void delegate (T) block)
	{
		return cast (T) _watch(T.classinfo, descriptor, cast (void delegate (Connection)) block);
	}

	T watch(T : Connection) (Descriptor descriptor)
	{
		return watch!T(descriptor, cast (void delegate (T)) defaultCreationCallback);
	}

	T watch(T : Connection) (Socket socket, void delegate (T) block)
	{
		return watch!T(new Descriptor(socket), block);
	}

	T watch(T : Connection) (Socket socket)
	{
		return watch!T(new Descriptor(socket), cast (void delegate (T)) defaultCreationCallback);
	}

	T watch(T : Connection) (int fd, void delegate (T) block)
	{
		return watch!T(new Descriptor(fd), block);
	}

	T watch(T : Connection) (int fd)
	{
		return watch!T(new Descriptor(fd), defaultCreationCallback);
	}

	void exchangeConnections (Connection from, Connection to)
	{
		schedule({
			Descriptor fromDescriptor = from.to!Descriptor;
			Descriptor toDescriptor   = to.to!Descriptor;

			to.exchange(fromDescriptor);
			from.exchange(toDescriptor);

			to.exchanged(from);
			from.exchanged(to);

			if (fromDescriptor) {
				assert(to);

				_connections[fromDescriptor] = to;
			}

			if (toDescriptor) {
				assert(from);

				_connections[toDescriptor] = from;
			}
		});
	}

	void closeConnection (Connection connection, bool after_writing = false)
	{
		schedule({
			_connecting.remove(connection.to!Descriptor);
			_connections.remove(connection.to!Descriptor);

			if (after_writing) {
				_closing[connection.to!Descriptor] = connection;
			}
			else {
				_selector.remove(connection.to!Descriptor);
				_closing.remove(connection.to!Descriptor);

				connection.close();
				connection.unbind();
			}
		});
	}

	Timer addTimer (Duration time, void delegate () block)
	{
		auto timer = new Timer(this, time, block);

		synchronized (_mutex) {
			_timers ~= timer;
		}

		wakeUp();

		return timer;
	}

	PeriodicTimer addPeriodicTimer (Duration time, void delegate () block)
	{
		auto timer = new PeriodicTimer(this, time, block);

		synchronized (_mutex) {
			_periodic_timers ~= timer;
		}

		wakeUp();

		return timer;
	}

	void cancelTimer (Timer timer)
	{
		synchronized (_mutex) {
			_timers = _timers.remove(_timers.countUntil(timer));
		}

		wakeUp();
	}

	void cancelTimer (PeriodicTimer timer)
	{
		synchronized (_mutex) {
			_periodic_timers = _periodic_timers.remove(_periodic_timers.countUntil(timer));
		}

		wakeUp();
	}

	void executeTimers ()
	{
		if (!hasTimers) {
			return;
		}

		Timer[]         timers_to_call;
		PeriodicTimer[] periodic_timers_to_call;

		synchronized (_mutex) {
			foreach (timer; _timers) {
				if (timer.left() <= (0).dur!"seconds") {
					timers_to_call ~= timer;
				}
			}

			foreach (timer; _periodic_timers) {
				if (timer.left() <= (0).dur!"seconds") {
					periodic_timers_to_call ~= timer;
				}
			}
		}

		foreach (timer; timers_to_call) {
			timer.execute();
		}

		foreach (timer; periodic_timers_to_call) {
			timer.execute();
		}

		synchronized (_mutex) {
			_timers = _timers.filter!(a => !timers_to_call.any!(b => a == b)).array;
		}
	}

	@property bool hasTimers ()
	{
		return !_timers.empty || !_periodic_timers.empty;
	}

	Duration minimumSleep ()
	{
		SysTime  now    = Clock.currTime();
		Duration result = _timers.empty ? _periodic_timers.front.left(now) : _timers.front.left(now);

		synchronized (_mutex) {
			if (!_timers.empty) {
				foreach (timer; _timers) {
					result = min(result, timer.left(now));
				}
			}

			if (!_periodic_timers.empty) {
				foreach (timer; _periodic_timers) {
					result = min(result, timer.left(now));
				}
			}
		}

		if (result < _quantum) {
			return _quantum;
		}

		return result;
	}

	void wakeUp ()
	{
		_selector.wakeUp();
	}

	void writeHappened ()
	{
		isWritePending = true;

		wakeUp();
	}

	@property isRunning ()
	{
		return _running;
	}

	@property hasScheduled ()
	{
		return !_scheduled.empty;
	}

	@property hasNextTick ()
	{
		return !_next_tick.empty;
	}

	@property noDescriptors ()
	{
		return _selector.empty;
	}

	@property isConnectPending ()
	{
		return _connecting.length > 0;
	}

	@property isClosePending ()
	{
		return _closing.length > 0;
	}

	@property isWritePending ()
	{
		return _is_write_pending;
	}

	@property isWritePending (bool value)
	{
		_is_write_pending = value;
	}

	@property threadpool ()
	{
		if (_threadpool) {
			return _threadpool;
		}

		return _threadpool = new ThreadPool;
	}

	@property backlog ()
	{
		return _backlog;
	}

	@property backlog (int value)
	{
		_backlog = value;
	}

	@property quantum ()
	{
		return _quantum;
	}

	@property quantum (Duration duration)
	{
		_quantum = duration;

		wakeUp();
	}

	@property selector ()
	{
		return _selector;
	}

	@property defaultCreationCallback (void delegate (Connection) block)
	{
		_default_creation_callback = block;
	}

	@property defaultCreationCallback ()
	{
		return _default_creation_callback;
	}

private:
	Server _startServer (TypeInfo_Class klass, Address address, string protocol, void delegate (Connection) block)
	{
		Server server;

		switch (protocol.toLower()) {
			case "tcp": server  = cast (Server) new TcpServer(this, address); break;
			case "udp": server  = cast (Server) new UdpServer(this, address); break;
			
			version (Posix) {
				case "unix": server = cast (Server) new UnixServer(this, address); break;
				case "fifo": server = cast (Server) new FifoServer(this, address); break;
			}

			default: throw new Exception("unsupported server protocol");
		}

		server.handler = klass;
		server.block   = block;

		schedule({
			auto descriptor = server.start();

			_selector.add(descriptor);
			_servers[descriptor] = server;
		});

		return server;
	}

	Connection _connect (TypeInfo_Class klass, Address address, string protocol, void delegate (Connection) callback)
	{
		Connection connection = cast (Connection) klass.create();
		Descriptor descriptor;

		connection.protocol = protocol;

		final switch (connection.protocol) {
			case "tcp":
				if (cast (Internet6Address) address) {
					descriptor = new Descriptor(new TcpSocket(AddressFamily.INET6));
				}
				else {
					descriptor = new Descriptor(new TcpSocket());
				}
			break;

			case "udp":
				if (cast (Internet6Address) address) {
					descriptor = new Descriptor(new UdpSocket(AddressFamily.INET6));
				}
				else {
					descriptor = new Descriptor(new UdpSocket());
				}
			break;

			version (Posix) {
				case "unix":
					descriptor = new Descriptor(new Socket(AddressFamily.UNIX, SocketType.STREAM));
				break;

				case "fifo":
					if (auto pipe = cast (NamedPipeAddress) address) {
						int result;

						errnoEnforce((result = .open(pipe.path.toStringz(), (pipe.isReadable ? O_RDONLY : O_WRONLY) | O_NONBLOCK)) >= 0);

						descriptor = new Descriptor(result);
					}
				break;
			}
		}

		enforce(descriptor, "unsupported client protocol");

		connection.connecting(this, descriptor);
		callback(connection);
		connection.initialized();

		if (descriptor.isSocket) {
			if (connection.protocol == "udp") {
				connection.defaultTarget = address;
			}
			else if (connection.protocol == "fifo") {
				auto pipe = cast (NamedPipeAddress) address;

				if (pipe.isReadable) {
					connection.isWritable = false;
				}
				else {
					connection.isReadable = false;
				}
			}

			descriptor.socket.connect(address);
		}

		if (auto security = cast (SecureInternetAddress) address) {
			connection.secure(security.context, security.verify);
		}
		else if (auto security = cast (SecureInternet6Address) address) {
			connection.secure(security.context, security.verify);
		}

		schedule({
			_selector.add(descriptor);
			_connecting[descriptor] = connection;
		});

		return connection;
	}

	Connection _watch (TypeInfo_Class klass, Descriptor descriptor, void delegate (Connection) callback)
	{
		auto connection = cast (Connection) klass.create();

		connection.watched(this, descriptor);
		callback(connection);
		connection.initialized();

		schedule({
			_selector.add(descriptor);
			_connections[descriptor] = connection;
		});

		return connection;
	}

private:
	Queue!(void delegate ()) _scheduled;
	Queue!(void delegate ()) _next_tick;

	Timer[]         _timers;
	PeriodicTimer[] _periodic_timers;
	Selector        _selector;

	Connection[Descriptor] _connecting;
	Server[Descriptor]     _servers;
	Connection[Descriptor] _connections;
	Connection[Descriptor] _closing;

	ThreadPool _threadpool;
	Mutex      _mutex;

	int      _backlog;
	Duration _quantum;
	bool     _running;
	bool     _is_write_pending;

	void delegate (Connection) _default_creation_callback;
}

void run (void delegate () block)
{
	instance.run(block);
}

void schedule (void delegate () block)
{
	instance.schedule(block);
}

void nextTick (void delegate () block)
{
	instance.nextTick(block);
}

void stop ()
{
	instance.stop();
}

void stopOn (string[] signals ...)
{
	foreach (signal; signals) {
		trap(signal, {
			stop();
		});
	}
}

void defer(T) (T delegate () operation) {
	_ensureReactor();

	instance.defer(operation);
}

void defer(T) (T delegate () operation, void delegate (T) callback)
{
	instance.defer(operation, callback);
}

void defer(T : AbstractTask) (T task)
{
	instance.defer(task);
}

Deferrable!T deferrable(T) ()
{
	return instance.deferrable!T;
}

Deferrable!T deferrable(T) (T data)
{
	return instance.deferrable!T(data);
}

Deferrable!T deferrable(T) (void delegate () callback)
{
	return instance.deferrable!T(callback);
}

Deferrable!T deferrable(T) (void delegate () callback, void delegate () errback)
{
	return instance.deferrable!T(callback, errback);
}

Server startServer(T : Connection) (Address address, string protocol)
{
	return instance.startServer!T(address, protocol);
}

Server startServer(T : Connection) (Address address, string protocol, void delegate (T) block)
{
	return instance.startServer!T(address, protocol, block);
}

Server startServer(T : Connection) (Address address)
{
	return instance.startServer!T(address);
}

Server startServer(T : Connection) (Address address, void delegate (T) block)
{
	return instance.startServer!T(address, block);
}

Server startServer(T : Connection) (URI uri)
{
	return instance.startServer!T(uri);
}

Server startServer(T : Connection) (URI uri, void delegate (T) block)
{
	return instance.startServer!T(uri, block);
}

Server startServer(T : Connection) (string uri)
{
	return instance.startServer!T(uri);
}

Server startServer(T : Connection) (string uri, void delegate (T) block)
{
	return instance.startServer!T(uri, block);
}

T connect(T : Connection) (Address address, string protocol)
{
	return instance.connect!T(address, protocol);
}

T connect(T : Connection) (Address address, string protocol, void delegate (T) block)
{
	return instance.connect!T(address, protocol, block);
}

T connect(T : Connection) (Address address)
{
	return instance.connect!T(address);
}

T connect(T : Connection) (Address address, void delegate (T) block)
{
	return instance.connect!T(address, block);
}

T connect(T : Connection) (URI uri, void delegate (T) block)
{
	return instance.connect!T(uri, block);
}

T connect(T : Connection) (URI uri)
{
	return instance.connect!T(uri);
}

T connect(T : Connection) (string uri, void delegate (T) block)
{
	return instance.connect!T(uri, block);
}

T connect(T : Connection) (string uri)
{
	return instance.connect!T(uri);
}

T watch(T : Connection) (Descriptor descriptor)
{
	return instance.watch!T(descriptor);
}

T watch(T : Connection) (Descriptor descriptor, void delegate (T) block)
{
	return instance.watch!T(descriptor, block);
}

T watch(T : Connection) (Socket socket)
{
	return instance.watch!T(socket);
}

T watch(T : Connection) (Socket socket, void delegate (T) block)
{
	return instance.watch!T(socket, block);
}

T watch(T : Connection) (int fd)
{
	return instance.watch!T(fd);
}

T watch(T : Connection) (int fd, void delegate (T) block)
{
	return instance.watch!T(fd, block);
}

Timer addTimer (Duration time, void delegate () block)
{
	return instance.addTimer(time, block);
}

PeriodicTimer addPeriodicTimer (Duration time, void delegate () block)
{
	return instance.addPeriodicTimer(time, block);
}

void cancelTimer (Timer timer)
{
	instance.cancelTimer(timer);
}

void cancelTimer (PeriodicTimer timer)
{
	instance.cancelTimer(timer);
}

@property quantum ()
{
	return instance.quantum;
}

@property quantum (Duration duration)
{
	instance.quantum = duration;
}

@property instance ()
{
	if (!_reactor) {
		_reactor = new Reactor();
	}

	return _reactor;
}

private:
	Reactor _reactor;

	string toProtocol (Address address)
	{
		if (cast (UnixAddress) address) {
			return "unix";
		}
		else if (cast (NamedPipeAddress) address) {
			return "fifo";
		}
		else {
			return "tcp";
		}
	}
