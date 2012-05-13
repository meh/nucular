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

module nucular.periodictimer;

import std.datetime;
import nucular.reactor;

class PeriodicTimer {
	this (Duration every, void function () block) {
		_every      = every;
		_block      = block;
		_started_at = Clock.currTime();
	}

	~this () {
		cancel();
	}

	void execute () {
		_block();

		_last_execution_at = Clock.currTime();
	}

	void cancel () {
		cancelTimer(this);
	}

	@property Duration every () {
		return _every;
	}

	@property SysTime lastExecutionAt () {
		return _last_execution_at;
	}

	@property SysTime startedAt () {
		return _started_at;
	}

private:
	Duration         _every;
	SysTime          _started_at;
	SysTime          _last_execution_at;
	void function () _block;
}
