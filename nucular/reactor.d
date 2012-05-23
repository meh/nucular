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

public import std.socket : InternetAddress, Internet6Address, parseAddress, getAddress;
public import core.time : dur, Duration;
public import nucular.connection : Connection;
public import nucular.descriptor : Descriptor;

import std.stdio : writeln;

import core.sync.mutex;
import std.array;
import std.algorithm;
import std.exception;
import std.datetime;
import std.socket;
import std.parallelism;

import nucular.threadpool;
import nucular.timer;
import nucular.periodictimer;
import nucular.deferrable;
import nucular.descriptor;
import nucular.breaker;
import nucular.server;
import nucular.available.best;

class Reactor
{
	this ()
	{
		_breaker    = new Breaker;
		_mutex      = new Mutex;
		_threadpool = new ThreadPool;

		_backlog = 100;
		_quantum = 100.dur!"msecs";
		_running = false;

		_default_creation_callback = (a) { };

		_descriptors ~= cast (Descriptor) _breaker;
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

			if (noDescriptors && !isConnectPending && !isClosePending) {
				if (!hasTimers) {
					_breaker.wait();
				}
				else {
					_breaker.wait(minimumSleep());

					if (isRunning) {
						executeTimers();
					}
				}

				continue;
			}

			Descriptor[] descriptors;

			if (isConnectPending) {
				if (hasTimers || !noDescriptors) {
					descriptors = writable(_connecting.keys, (0).dur!"seconds");
				}
				else {
					descriptors = writable(_connecting.keys ~ cast (Descriptor) _breaker);
				}

				foreach (descriptor; descriptors) {
					if (cast (Descriptor) _breaker == descriptor) {
						_breaker.flush();
					}
					else {
						Connection connection = _connecting[descriptor];

						_connecting.remove(descriptor);

						if (connection.error) {
							connection.close();
							connection.unbind();
						}
						else {
							connection.connected();

							_descriptors             ~= descriptor;
							_connections[descriptor]  = connection;
						}
					}
				}
			}

			if (isClosePending) {
				foreach (descriptor, connection; _closing) {
					if (!connection.isWritePending && connection.isEOF) {
						closeConnection(connection);
					}
				}
			}

			if (hasTimers) {
				descriptors = readable(_descriptors, minimumSleep());
			}
			else if (isWritePending || isConnectPending || isClosePending) {
				descriptors = readable(_descriptors, (0).dur!"seconds");
			}
			else {
				descriptors = readable(_descriptors);
			}

			if (!isRunning) {
				continue;
			}

			executeTimers();

			if (!isRunning || hasScheduled) {
				continue;
			}

			foreach (descriptor; descriptors) {
				if (cast (Descriptor) _breaker == descriptor) {
					_breaker.flush();
				}
				else if (descriptor in _servers) {
					Server server         = _servers[descriptor];
					Connection connection = server.accept();
					           descriptor = cast (Descriptor) connection;

					schedule({
						_descriptors             ~= descriptor;
						_connections[descriptor]  = connection;
					});
				}
				else if (descriptor in _connections) {
					Connection connection = _connections[descriptor];
					ubyte[]    data       = connection.read();

					if (data) {
						connection.receiveData(data);
					}
				}
			}

			if (!isRunning) {
				continue;
			}

			foreach (descriptor, connection; _connections) {
				if (connection.isWritePending) {
					descriptors ~= descriptor;
				}
			}

			foreach (descriptor, connection; _closing) {
				if (connection.isWritePending) {
					descriptors ~= descriptor;
				}
			}

			if (!isRunning || hasScheduled || descriptors.empty) {
				continue;
			}

			descriptors = writable(descriptors, (0).dur!"seconds");

			isWritePending = false;
			foreach (descriptor; descriptors) {
				if (descriptor in _connections) {
					if (!_connections[descriptor].write() && !isWritePending) {
						isWritePending = true;
					}
				}
				else if (descriptor in _closing) {
					Connection connection = _closing[descriptor];

					if (!_closing[descriptor].write()) {
						isWritePending = true;
					}
					else {
						connection.shutdown();
					}
				}
			}
		}
	}

	void schedule (void delegate () block)
	{
		synchronized (_mutex) {
			_scheduled ~= block;
		}

		wakeUp();
	}

	void nextTick (void delegate () block)
	{
		schedule(block);
	}

	void stop ()
	{
		if (!isRunning) {
			return;
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

	Deferrable deferrable ()
	{
		return new Deferrable(this);
	}

	Deferrable deferrable (void delegate () callback)
	{
		return deferrable().callback(callback);
	}

	Deferrable deferrable (void delegate () callback, void delegate () errback)
	{
		return deferrable().callback(callback).errback(errback);
	}

	Server startServer(T : Connection) (Address address, void delegate (T) block)
	{
		return _startServer(T.classinfo, address, cast (void delegate (Connection)) block);
	}

	Server startServer(T : Connection) (Address address)
	{
		return startServer!(T)(address, cast (void delegate (T)) defaultCreationCallback);
	}

	void stopServer (Server server)
	{
		server.stop();

		schedule({
			_descriptors = _descriptors.filter!((a) { return a != cast (Descriptor) server; }).array;
		});
	}

	Connection connect(T : Connection) (Address address, void delegate (T) block)
	{
		return _connect(T.classinfo, address, cast (void delegate (Connection)) block);
	}

	Connection connect(T : Connection) (Address address)
	{
		return connect!(T)(address, cast (void delegate (T)) defaultCreationCallback);
	}

	Connection watch(T : Connection) (Descriptor descriptor, void delegate (T) block)
	{
		return _watch(T.classinfo, descriptor, cast (void delegate (Connection)) block);
	}

	Connection watch(T : Connection) (Descriptor descriptor)
	{
		return watch!(T)(descriptor, cast (void delegate (T)) defaultCreationCallback);
	}

	Connection watch(T : Connection) (Socket socket, void delegate (T) block)
	{
		return watch!(T)(new Descriptor(socket), block);
	}

	Connection watch(T : Connection) (Socket socket)
	{
		return watch!(T)(new Descriptor(socket), cast (void delegate (T)) defaultCreationCallback);
	}

	Connection watch(T : Connection) (int fd, void delegate (T) block)
	{
		return watch!(T)(new Descriptor(fd), block);
	}

	Connection watch(T : Connection) (int fd)
	{
		return watch!(T)(new Descriptor(fd), defaultCreationCallback);
	}

	void exchangeConnections (Connection from, Connection to)
	{
		schedule({
			Descriptor fromDescriptor = cast (Descriptor) from;
			Descriptor toDescriptor   = cast (Descriptor) to;

			to.exchange(fromDescriptor);
			from.exchange(toDescriptor);

			to.exchanged(from);
			from.exchanged(to);

			if (fromDescriptor) {
				_connections[fromDescriptor] = to;
			}

			if (toDescriptor) {
				_connections[toDescriptor] = from;
			}
		});
	}

	void closeConnection (Connection connection, bool after_writing = false)
	{
		schedule({
			_connections.remove(cast (Descriptor) connection);
			_descriptors = _descriptors.filter!((a) { return a != cast (Descriptor) connection; }).array;

			if (after_writing) {
				_closing[cast (Descriptor) connection] = connection;
			}
			else {
				_closing.remove(cast (Descriptor) connection);

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
			_timers = _timers.filter!((a) { return a != timer; }).array;
		}

		wakeUp();
	}

	void cancelTimer (PeriodicTimer timer)
	{
		synchronized (_mutex) {
			_periodic_timers = _periodic_timers.filter!((a) { return a != timer; }).array;
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
			_timers = _timers.filter!((a) { return !timers_to_call.any!((b) { return a == b; }); }).array;
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
		_breaker.act();
	}

	@property isRunning ()
	{
		return _running;
	}

	@property hasScheduled ()
	{
		return !_scheduled.empty;
	}

	@property noDescriptors ()
	{
		return _descriptors.length == 1;
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

	@property defaultCreationCallback (void delegate (Connection) block)
	{
		_default_creation_callback = block;
	}

	@property defaultCreationCallback ()
	{
		return _default_creation_callback;
	}

private:
	Server _startServer (TypeInfo_Class klass, Address address, void delegate (Connection) block)
	{
		auto server         = new Server(this, address);
		     server.handler = klass;
		     server.block   = block;

		schedule({
			auto descriptor = server.start();

			_descriptors         ~= descriptor;
			_servers[descriptor]  = server;
		});

		return server;
	}

	Connection _connect (TypeInfo_Class klass, Address address, void delegate (Connection) callback)
	{
		auto connection = cast (Connection) klass.create();

		static if (is (address : Internet6Address)) {
			auto socket = new TcpSocket(AddressFamily.INET6);
		}
		else {
			auto socket = new TcpSocket();
		}

		auto descriptor = new Descriptor(socket);

		connection.connecting(this, descriptor);
		callback(connection);
		connection.initialized();

		socket.connect(address);

		schedule({
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
			_descriptors             ~= descriptor;
			_connections[descriptor]  = connection;
		});

		return connection;
	}

private:
	void delegate ()[] _scheduled;

	Timer[]         _timers;
	PeriodicTimer[] _periodic_timers;
	Descriptor[]    _descriptors;

	Connection[Descriptor] _connecting;
	Server[Descriptor]     _servers;
	Connection[Descriptor] _connections;
	Connection[Descriptor] _closing;

	ThreadPool _threadpool;
	Breaker    _breaker;
	Mutex      _mutex;

	int      _backlog;
	Duration _quantum;
	bool     _running;
	bool     _is_write_pending;

	void delegate (Connection) _default_creation_callback;
}

void trap (string name, void delegate () block)
{
	// TODO: implement signal handling
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

Deferrable deferrable ()
{
	return instance.deferrable();
}

Deferrable deferrable (void delegate () callback)
{
	return instance.deferrable(callback);
}

Deferrable deferrable (void delegate () callback, void delegate () errback)
{
	return instance.deferrable(callback, errback);
}

Server startServer(T : Connection) (Address address)
{
	return instance.startServer!(T)(address);
}

Server startServer(T : Connection) (Address address, void delegate (T) block)
{
	return instance.startServer!(T)(address, block);
}

Connection connect(T : Connection) (Address address)
{
	return instance.connect!(T)(address);
}

Connection connect(T : Connection) (Address address, void delegate (T) block)
{
	return instance.connect!(T)(address, block);
}

Connection watch(T : Connection) (Descriptor descriptor)
{
	return instance.watch!(T)(descriptor);
}

Connection watch(T : Connection) (Descriptor descriptor, void delegate (T) block)
{
	return instance.watch!(T)(descriptor, block);
}

Connection watch(T : Connection) (Socket socket)
{
	return instance.watch!(T)(socket);
}

Connection watch(T : Connection) (Socket socket, void delegate (T) block)
{
	return instance.watch!(T)(socket, block);
}

Connection watch(T : Connection) (int fd)
{
	return instance.watch!(T)(fd);
}

Connection watch(T : Connection) (int fd, void delegate (T) block)
{
	return instance.watch!(T)(fd, block);
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

private Reactor _reactor;
