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

version (poll):

import core.time;
import core.stdc.errno;

import core.sys.posix.poll;

import std.algorithm;
import std.conv;
import std.exception;

import nucular.descriptor;

Descriptor[] readable (Descriptor[] descriptors)
{
	pollfd[] fds = descriptors.toSet!"read";

	try {
		errnoEnforce(poll(fds.ptr, fds.length, -1) > 0);
	}
	catch (ErrnoException e) {
		if (e.errno != EINTR && e.errno != EAGAIN) {
			throw e;
		}
	}

	return fds.toDescriptors!"read"(descriptors);
}

Descriptor[] readable (Descriptor[] descriptors, Duration sleep)
{
	pollfd[] fds = descriptors.toSet!"read";

	try {
		errnoEnforce(poll(fds.ptr, fds.length, sleep.total!"msecs".to!int) > 0);
	}
	catch (ErrnoException e) {
		if (e.errno != EINTR && e.errno != EAGAIN) {
			throw e;
		}
	}

	return fds.toDescriptors!"read"(descriptors);
}

Descriptor[] writable (Descriptor[] descriptors)
{
	pollfd[] fds = descriptors.toSet!"write";

	try {
		errnoEnforce(poll(fds.ptr, fds.length, -1) > 0);
	}
	catch (ErrnoException e) {
		if (e.errno != EINTR && e.errno != EAGAIN) {
			throw e;
		}
	}

	return fds.toDescriptors!"write"(descriptors);
}

Descriptor[] writable (Descriptor[] descriptors, Duration sleep)
{
	pollfd[] fds = descriptors.toSet!"write";

	try {
		errnoEnforce(poll(fds.ptr, fds.length, sleep.total!"msecs".to!int) > 0);
	}
	catch (ErrnoException e) {
		if (e.errno != EINTR && e.errno != EAGAIN) {
			throw e;
		}
	}

	return fds.toDescriptors!"write"(descriptors);
}

private:
	pollfd[] toSet(string mode) (Descriptor[] descriptors) pure
		if (mode == "read" || mode == "write")
	{
		pollfd[] set = new pollfd[descriptors.length];

		foreach (index, descriptor; descriptors) {
			set[index].fd = descriptor.to!int;

			static if (mode == "read") {
				set[index].events = POLLIN;
			}
			else static if (mode == "write") {
				set[index].events = POLLOUT;
			}
		}

		return set;
	}

	Descriptor[] toDescriptors(string mode) (pollfd[] set, Descriptor[] descriptors) pure
		if (mode == "read" || mode == "write")
	{
		Descriptor[] result;

		foreach (index, pfd; set) {
			static if (mode == "read") {
				if (pfd.revents & POLLIN) {
					result ~= descriptors[index];
				}
			}
			else static if (mode == "write") {
				if (pfd.revents & POLLOUT) {
					result ~= descriptors[index];
				}
			}
		}

		return result;
	}
