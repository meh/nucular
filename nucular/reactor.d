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

public import std.socket : InternetAddress, Internet6Address;
public import core.time : dur, Duration;
public import nucular.connection : Connection;
public import nucular.descriptor : Descriptor;

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

			if (_descriptors.length == 1) {
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

			if (hasTimers) {
				descriptors = readable(_descriptors, minimumSleep());
			}
			else if (isWritePending) {
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
				// FIXME: use == when they fix the bug
				if ((cast (Descriptor) _breaker).opEquals(descriptor)) {
					_breaker.flush();
				}
				else if (descriptor in _servers) {
					Server server         = _servers[descriptor];
					Connection connection = server.accept();
					           descriptor = cast (Descriptor) connection;

					connection.initialized();

					schedule({
						_descriptors             ~= descriptor;
						_connections[descriptor]  = connection;
					});
				}
				else if (descriptor in _connections) {
					Connection connection = _connections[descriptor];
					ubyte[]    data       = connection.read();

					if (!data.empty) {
						connection.receiveData(data);
					}
				}
			}

			if (!isRunning) {
				continue;
			}

			foreach (descriptor, connection; _connections) {
				if (connection.isWritePending) {
					isWritePending = true;

					descriptors ~= descriptor;
				}
			}

			if (!isRunning || hasScheduled || descriptors.empty) {
				continue;
			}

			descriptors = writable(descriptors, (0).dur!"seconds");

			if (!isRunning) {
				continue;
			}

			isWritePending = false;
			foreach (descriptor; descriptors) {
				if (descriptor in _connections) {
					if (!_connections[descriptor].write()) {
						isWritePending = true;
					}
				}
				else if (descriptor in _closing) {
					if (!_closing[descriptor].write()) {
						isWritePending = true;
					}
					else {
						closeConnection(_closing[descriptor]);
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

	Server startServer(alias T) (Address address)
		if (is (T : Connection))
	{
		return _startServer(T.classinfo, address);
	}

	Server startServer(alias T) (Address address, void delegate (Connection) block)
		if (is (T : Connection))
	{
		auto server       = _startServer(T.classinfo, address);
		     server.block = block;

		return server;
	}

	Server startServer(alias T) (Address address)
		if (!is (T : Connection))
	{
		class tmp : Connection
		{
			mixin T;
		}

		return _startServer(tmp.classinfo, address);
	}

	Server startServer(alias T) (Address address, void delegate (Connection) block)
		if (!is (T : Connection))
	{
		class tmp : Connection
		{
			mixin T;
		}

		auto server       = _startServer(tmp.classinfo, address);
		     server.block = block;

		return server;
	}

	void stopServer (Server server)
	{
		server.stop();

		schedule({
			// FIXME: use == when they fix the bug
			_descriptors = _descriptors.filter!((a) { return !a.opEquals(cast (Descriptor) server); }).array;
		});
	}

	Connection watch(alias T) (Descriptor descriptor)
		if (is (T : Connection))
	{
		return _watch(T.classinfo, descriptor);
	}

	Connection watch(alias T) (Socket socket)
		if (is (T : Connection))
	{
		return watch!(T)(new Descriptor(socket));
	}

	Connection watch(alias T) (int fd)
		if (is (T : Connection))
	{
		return watch!(T)(new Descriptor(fd));
	}

	Connection watch(alias T) (Descriptor descriptor)
		if (!is (T : Connection))
	{
		class tmp : Connection
		{
			mixin T;
		}

		return _watch(tmp.classinfo, descriptor);
	}

	Connection watch(alias T) (Socket socket)
		if (!is (T : Connection))
	{
		return watch!(T)(new Descriptor(socket));
	}

	Connection watch(alias T) (int fd)
		if (!is (T : Connection))
	{
		return watch!(T)(new Descriptor(fd));
	}

	void exchangeConnection (Connection from, Connection to)
	{
		schedule({
			to.exchange(cast (Descriptor) from);

			_connections[cast (Descriptor) from] = to;
		});
	}

	void closeConnection (Connection connection, bool after_writing = false)
	{
		schedule({
			_connections.remove(cast (Descriptor) connection);

			if (after_writing) {
				_closing[cast (Descriptor) connection] = connection;
			}
			else {
				_closing.remove(cast (Descriptor) connection);

				// FIXME: use == when they fix the bug
				_descriptors = _descriptors.filter!((a) { return !a.opEquals(cast (Descriptor) connection); }).array;

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

private:
	Server _startServer (TypeInfo_Class klass, Address address)
	{
		auto server         = new Server(this, address);
		     server.handler = klass;

		schedule({
			auto descriptor = server.start();

			_descriptors         ~= descriptor;
			_servers[descriptor]  = server;
		});

		return server;
	}

	Connection _watch (TypeInfo_Class klass, Descriptor descriptor)
	{
		auto connection = cast (Connection) klass.create();
		     connection.watched(this, descriptor);

		schedule({
			_descriptors             ~= descriptor;
			_connections[descriptor]  = connection;
		});

		return connection;
	}

private:
	Timer[]         _timers;
	PeriodicTimer[] _periodic_timers;
	Descriptor[]    _descriptors;

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

	void delegate ()[] _scheduled;
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

Server startServer(alias T) (Address address)
{
	return instance.startServer!(T)(address);
}

Server startServer(alias T) (Address address, void delegate (Connection) block)
{
	return instance.startServer!(T)(address, block);
}

Connection watch(alias T) (Descriptor descriptor)
{
	return instance.watch!(T)(descriptor);
}

Connection watch(alias T) (Socket socket)
{
	return instance.watch!(T)(socket);
}

Connection watch(alias T) (int fd)
{
	return instance.watch!(T)(fd);
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
