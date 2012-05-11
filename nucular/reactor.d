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
import nucular.descriptor;
import nucular.signature;
import nucular.timer;
import nucular.periodictimer;

private Timer[]         timers;
private PeriodicTimer[] periodic_timers;
private Descriptor[]    descriptors;

shared Threadpool threadpool;

void run (void delegate () block) {
	block();
}

void defer (void delegate () operation) {
	threadpool.process(operation);
}

void defer (void* delegate () operation, void delegate (void*) callback) {
	threadpool.process({
		callback(operation());
	});
}

Timer addTimer (float time, void delegate () block) {
	auto timer = new Timer(time, block);

	wake_up();

	return timer;
}

PeriodicTimer addPeriodicTimer (float time, void delegate () block) {
	auto timer = new PeriodicTimer(time, block);

	periodic_timers.push timer;
	wake_up();

	return timer;
}
