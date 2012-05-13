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

public import core.time;
public import nucular.connection;

import core.sync.mutex;
import std.array;
import std.algorithm;
import std.exception;
import std.datetime;

import nucular.threadpool;
import nucular.timer;
import nucular.periodictimer;
import nucular.descriptor;
import nucular.breaker;
import nucular.server;

version (epoll) {
	import nucular.available.epoll;
}
else version (kqueue) {
	import nucular.available.kqueue;
}
else version (iocompletion) {
	import nucular.available.iocompletion;
}
else {
	import nucular.available.select;
}

class Reactor {
	this () {
		_breaker    = new Breaker;
		_mutex      = new Mutex;
		_threadpool = new ThreadPool;

		_quantum = 100.dur!"msecs";
		_running = false;
	}

	~this () {
		stop();
	}

	void run (void function () block) {
		schedule(block);

		if (_running) {
			return;
		}

		_running = true;

		while (_running) {
			synchronized (_mutex) {
				foreach (scheduled; _scheduled) {
					scheduled();
				}

				_scheduled.clear();
			}

			if (_descriptors.empty) {
				if (!hasTimers) {
					_breaker.wait();
				}
				else {
					_breaker.wait(minimumSleep());

					if (_running) {
						executeTimers();
					}
				}

				continue;
			}

			Descriptor[] descriptors = hasTimers ? readable(_descriptors, minimumSleep()) : readable(_descriptors);

			if (!_running) {
				break;
			}

			foreach (descriptor; descriptors) {
				if (_breaker.opEquals(descriptor)) {
					_breaker.flush();
				}
				else if (descriptor in _servers) {
					Server server = _servers[descriptor];
				}
				else if (descriptor in _connections) {
					Connection connection = _connections[descriptor];
				}
			}

			executeTimers();

			// TODO: we know from what we can read, so let's read
		}
	}

	void schedule (void function () block) {
		synchronized (_mutex) {
			_scheduled ~= block;
		}

		_breaker.act();
	}

	void nextTick (void function () block) {
		schedule(block);
	}

	void stop () {
		if (!_running) {
			return;
		}

		_running = false;

		_breaker.act();
	}

	void defer(T) (T function () operation) {
		threadpool.process(operation);
	}

	void defer(T) (T function () operation, void function (T) callback) {
		threadpool.process({
			callback(operation());
		});
	}

	Timer addTimer (Duration time, void function () block) {
		auto timer = new Timer(this, time, block);

		synchronized (_mutex) {
			_timers ~= timer;
		}

		_breaker.act();

		return timer;
	}

	PeriodicTimer addPeriodicTimer (Duration time, void function () block) {
		auto timer = new PeriodicTimer(this, time, block);

		synchronized (_mutex) {
			_periodic_timers ~= timer;
		}

		_breaker.act();

		return timer;
	}

	void cancelTimer (Timer timer) {
		synchronized (_mutex) {
			_timers = _timers.filter!((a) { return a != timer; }).array;
		}

		_breaker.act();
	}

	void cancelTimer (PeriodicTimer timer) {
		synchronized (_mutex) {
			_periodic_timers = _periodic_timers.filter!((a) { return a != timer; }).array;
		}

		_breaker.act();
	}

	@property quantum () {
		return _quantum;
	}

	@property quantum (Duration duration) {
		_quantum = duration;

		_breaker.act();
	}

	void executeTimers () {
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

	@property bool hasTimers () {
		return !_timers.empty || !_periodic_timers.empty;
	}

	Duration minimumSleep () {
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

private:
	Timer[]         _timers;
	PeriodicTimer[] _periodic_timers;
	Descriptor[]    _descriptors;

	Server[Descriptor]     _servers;
	Connection[Descriptor] _connections;

	ThreadPool _threadpool;
	Breaker    _breaker;
	Mutex      _mutex;

	Duration _quantum;
	bool     _running;

	void function ()[] _scheduled;
}

private Reactor _reactor;

void run (void function () block) {
	if (!_reactor) {
		_reactor = new Reactor();
	}

	_reactor.run(block);
}

void schedule (void function () block) {
	_reactor.schedule(block);
}

void nextTick (void function () block) {
	_reactor.nextTick(block);
}

void stop () {
	_reactor.stop();
}

void defer(T) (T function () operation) {
	_reactor.defer(operation);
}

void defer(T) (T function () operation, void function (T) callback) {
	_reactor.defer(operation, callback);
}

Timer addTimer (Duration time, void function () block) {
	return _reactor.addTimer(time, block);
}

PeriodicTimer addPeriodicTimer (Duration time, void function () block) {
	return _reactor.addPeriodicTimer(time, block);
}

void cancelTimer (Timer timer) {
	_reactor.cancelTimer(timer);
}

void cancelTimer (PeriodicTimer timer) {
	_reactor.cancelTimer(timer);
}

@property quantum () {
	return _reactor.quantum;
}

@property quantum (Duration duration) {
	_reactor.quantum = duration;
}
