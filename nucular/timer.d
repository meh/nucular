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

module nucular.timer;

import std.datetime;
import nucular.reactor;

class Timer {
	this (Duration after, void function () block) {
		_after = after;
		_block = block;

		_executed   = false;
		_started_at = Clock.currTime();
	}

	void execute () {
		if (_executed) {
			return;
		}

		_executed = true;

		_block();
	}

	void cancel () {
		cancelTimer(this);
	}

	Duration left (SysTime now) {
		return after - (now - startedAt);
	}

	Duration left () {
		return left(Clock.currTime());
	}

	@property Duration after () {
		return _after;
	}

	@property SysTime startedAt () {
		return _started_at;
	}

protected:
	bool             _executed;
	Duration         _after;
	SysTime          _started_at;
	void function () _block;
}
