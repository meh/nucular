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

import core.time;
import core.sys.posix.sys.select;
import core.sys.posix.sys.time;

import nucular.descriptor;

Descriptor[] readable (Descriptor[] descriptors, Duration sleep = null) {
	fd_set set  = descriptors.toSet();
	int    nfds = descriptors.map!("cast (int) a").reduce!(max) + 1;

	if (sleep) {
		timeval tv = { to!(time_t)(sleep.total!"seconds"()), to!(suseconds_t, sleep.fracSec.usecs) };

		select(nfds, &set, null, null, &tv);
	}
	else {
		select(nfds, &set, null, null, null);
	}
}

Descriptor[] writable (Descriptor[] descriptors, Duration sleep = null) {
	fd_set set  = descriptors.toSet();
	int    nfds = descriptors.map!("cast (int) a").reduce!(max) + 1;

	if (sleep) {
		timeval tv = { to!(time_t)(sleep.total!"seconds"()), to!(suseconds_t, sleep.fracSec.usecs) };

		select(nfds, null, &set, null, &tv);
	}
	else {
		select(nfds, null, &set, null, null);
	}
}

private fd_set toSet (ref Descriptor[] descriptors) {
	fd_set set;

	foreach (descriptor; descriptors) {
		FD_SET(cast (int) descriptor, set);
	}

	return set;
}
