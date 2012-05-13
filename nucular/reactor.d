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

version (epoll) {
	public import nucular.available.epoll;
}
else version (kqueue) {
	public import nucular.available.kqueue;
}
else version (iocompletion) {
	public import nucular.available.iocompletion;
}
else {
	public import nucular.available.select;
}

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

public ThreadPool threadpool;

private Timer[]                _timers;
private PeriodicTimer[]        _periodic_timers;
private Descriptor[]           _descriptors;
private Server[Descriptor]     _servers;
private Connection[Descriptor] _connections;

private Duration _quantum = 100.dur!"msecs";

private Breaker              _breaker;
private bool                 _running = false;
private void function ()[] _scheduled;
private Mutex                _mutex;

void run (void function () block) {
	if (_running) {
		schedule(block);

		return;
	}

	_breaker = new Breaker;
	_mutex   = new Mutex;
	_running = true;

	schedule(block);

	while (_running) {
		synchronized (_mutex) {
			foreach (scheduled; _scheduled) {
				scheduled();
			}

			_scheduled.clear();
		}

		if (_descriptors.empty) {
			if (!_hasTimers) {
				_breaker.wait();
			}
			else {
				_breaker.wait(_minimumSleep());

				_executeTimers();
			}
		}
		else {
			Descriptor[] descriptors = _hasTimers ? readable(_descriptors, _minimumSleep()) : readable(_descriptors);

			_executeTimers();
		}

		// TODO: get here the available descriptors
	
		if (!_running) {
			break;
		}

		// TODO: handle the descriptors here
	}
}

void schedule (void function () block) {
	enforce(_running, "the reactor isn't running");

	synchronized (_mutex) {
		_scheduled ~= block;
	}

	_breaker.act();
}

void nextTick (void function () block) {
	schedule(block);
}

void stopEventLoop () {
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
	auto timer = new Timer(time, block);

	synchronized (_mutex) {
		_timers ~= timer;
	}

	_breaker.act();

	return timer;
}

PeriodicTimer addPeriodicTimer (Duration time, void function () block) {
	auto timer = new PeriodicTimer(time, block);

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

@property quantum (Duration duration) {
	_quantum = duration;

	_breaker.act();
}

private void _executeTimers () {
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

@property private bool _hasTimers () {
	return !_timers.empty || !_periodic_timers.empty;
}

private Duration _minimumSleep () {
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
