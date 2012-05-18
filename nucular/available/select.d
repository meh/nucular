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

module nucular.available.select;

import core.time;
import core.sys.posix.sys.select;
import core.sys.posix.sys.time;
import std.algorithm;
import std.conv;
import std.exception;

import nucular.descriptor;

Descriptor[] readable (Descriptor[] descriptors) {
	fd_set set  = descriptors.toSet();
	int    nfds = descriptors.map!("cast (int) a").reduce!(max) + 1;

	errnoEnforce(select(nfds, &set, null, null, null) >= 0);

	return set.toDescriptors(descriptors);
}

Descriptor[] readable (Descriptor[] descriptors, Duration sleep) {
	fd_set  set  = descriptors.toSet();
	int     nfds = descriptors.map!("cast (int) a").reduce!(max) + 1;
	timeval tv   = { sleep.total!"seconds"().to!(time_t), sleep.fracSec.usecs.to!(suseconds_t) };

	errnoEnforce(select(nfds, &set, null, null, &tv) >= 0);

	return set.toDescriptors(descriptors);
}

Descriptor[] writable (Descriptor[] descriptors) {
	fd_set set  = descriptors.toSet();
	int    nfds = descriptors.map!("cast (int) a").reduce!(max) + 1;

	errnoEnforce(select(nfds, null, &set, null, null) >= 0);

	return set.toDescriptors(descriptors);
}

Descriptor[] writable (Descriptor[] descriptors, Duration sleep) {
	fd_set  set  = descriptors.toSet();
	int     nfds = descriptors.map!("cast (int) a").reduce!(max) + 1;
	timeval tv   = { sleep.total!"seconds"().to!(time_t), sleep.fracSec.usecs.to!(suseconds_t) };

	errnoEnforce(select(nfds, null, &set, null, &tv) >= 0);

	return set.toDescriptors(descriptors);
}

private fd_set toSet (Descriptor[] descriptors) {
	fd_set set;

	FD_ZERO(&set);

	foreach (descriptor; descriptors) {
		FD_SET(cast (int) descriptor, &set);
	}

	return set;
}

private Descriptor[] toDescriptors (fd_set set, Descriptor[] descriptors) {
	Descriptor[] result;

	foreach (descriptor; descriptors) {
		if (FD_ISSET(cast (int) descriptor, &set)) {
			result ~= descriptor;
		}
	}

	return result;
}
