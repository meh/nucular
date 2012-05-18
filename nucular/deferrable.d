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

module nucular.deferrable;

import nucular.reactor : Reactor, Duration;
import nucular.timer;

class Deferrable {
	this (Reactor reactor) {
		_reactor = reactor;
	}

	~this () {
		cancelTimeout();
	}

	Deferrable callback(T) (T delegate () block) {
		_callbacks ~= cast (void delegate (void*)) block;

		return this;
	}

	Deferrable callback(T) (T delegate (T data) block) {
		_callbacks ~= cast (void delegate (void*)) block;

		return this;
	}

	Deferrable errback(T) (T delegate () block) {
		_errbacks ~= cast (void delegate (void*)) block;

		return this;
	}

	Deferrable errback(T) (T delegate (T data) block) {
		_errbacks ~= cast (void delegate (void*)) block;

		return this;
	}

	void succeed () {
		foreach (callback; _callbacks) {
			callback(null);
		}
	}

	void succeedWith(T) (T data) {
		foreach (callback; _callbacks) {
			callback(data);
		}
	}

	void fail () {
		foreach (errback; _errbacks) {
			errback(null);
		}
	}

	void failWith(T) (T data) {
		foreach (errback; _errbacks) {
			errback(data);
		}
	}

	void cancelTimeout () {
		if (!_timer) {
			return;
		}

		_timer.cancel();
		_timer = null;
	}
	
	Timer timeout (Duration time) {
		_timer = reactor.addTimer(time, {
			fail();
		});

		return _timer;
	}

	@property reactor () {
		return _reactor;
	}

private:
	Reactor _reactor;

	void delegate (void*)[] _callbacks;
	void delegate (void*)[] _errbacks;

	Timer _timer;
}
