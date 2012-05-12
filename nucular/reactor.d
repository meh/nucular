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

import nucular.threadpool;
import nucular.timer;
import nucular.periodictimer;
import nucular.descriptor;
import nucular.breaker;
import nucular.available;
import nucular.server;

public import nucular.connection;
public import nucular.watcher;

public Threadpool threadpool;

private Timer[]                _timers;
private PeriodicTimer[]        _periodic_timers;
private Descriptor[]           _descriptors;
private Server[Descriptor]     _servers;
private Connection[Descriptor] _connections;

private Duration _quantum = dur!"msecs"(100);

private Breaker              _breaker;
private bool                 _running = false;
private (void function ())[] _scheduled;
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
			for (block; _scheduled) {
				block();
			}

			_scheduled.clear();
		}

		if (_descriptors.empty) {
			_breaker.wait();
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

void next_tick (void function () block) {
	schedule(block);
}

void stop_event_loop () {
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

	_timers ~= timer;

	_breaker.act();

	return timer;
}

PeriodicTimer addPeriodicTimer (Duration time, void function () block) {
	auto timer = new PeriodicTimer(time, block);

	periodic_timers ~= timer;

	_breaker.act();

	return timer;
}

void cancelTimer (Timer timer) {
	schedule({
		_timers = filter!((a) { return a != timer })(_timers);
	});
}

void cancelTimer (PeriodicTimer timer) {
	schedule({
		_periodical_timers = filter!((a) { return a != timer })(_periodic_timers);
	});
}

@property quantum (Duration duration) {
	_quantum = duration;
}

private float _nextSleep () {

}
