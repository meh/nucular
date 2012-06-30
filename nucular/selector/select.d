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

module nucular.selector.select;

version (select):

import core.time;
import core.stdc.errno;

version (Posix) {
	import core.sys.posix.sys.select;
	import core.sys.posix.sys.time;
}

import std.algorithm;
import std.conv;
import std.array;
import std.exception;

import nucular.descriptor;
import base = nucular.selector.base;

class Selector : base.Selector
{
	this ()
	{
		super();

		FD_ZERO(&_set);
	}

	override bool add (Descriptor descriptor)
	{
		if (!super.add(descriptor)) {
			return false;
		}

		FD_SET(descriptor.to!int, &_set);

		_max = 0;

		return true;
	}

	override bool remove (Descriptor descriptor)
	{
		if (!super.remove(descriptor)) {
			return false;
		}

		FD_CLR(descriptor.to!int, &_set);

		_max = 0;

		return true;
	}

	base.Selected available() ()
	{
		fd_set read  = _set;
		fd_set write = _set;
		fd_set error = _set;

		FD_SET(breaker.to!int, &read);
		select(&read, &write, &error);
		breaker.flush();

		return base.Selected(
			read.toDescriptors(descriptors),
			write.toDescriptors(descriptors),
			error.toDescriptors(descriptors)
		);
	}

	base.Selected available() (Duration timeout)
	{
		fd_set read  = _set;
		fd_set write = _set;
		fd_set error = _set;

		FD_SET(breaker.to!int, &read);
		select(&read, &write, &error, timeout.toTimeval);
		breaker.flush();

		return base.Selected(
			read.toDescriptors(descriptors),
			write.toDescriptors(descriptors),
			error.toDescriptors(descriptors)
		);
	}

	base.Selected available(string mode) ()
		if (mode == "read")
	{
		fd_set read  = _set;
		fd_set error = _set;

		FD_SET(breaker.to!int, &read);
		select(&read, null, &error);
		breaker.flush();

		return base.Selected(
			read.toDescriptors(descriptors),
			[],
			error.toDescriptors(descriptors)
		);
	}

	base.Selected available(string mode) (Duration timeout)
		if (mode == "read")
	{
		fd_set read  = _set;
		fd_set error = _set;

		FD_SET(breaker.to!int, &read);
		select(&read, null, &error, timeout.toTimeval);
		breaker.flush();

		return base.Selected(
			read.toDescriptors(descriptors),
			[],
			error.toDescriptors(descriptors)
		);
	}

	base.Selected available(string mode) ()
		if (mode == "write")
	{
		fd_set read;
		fd_set write = _set;
		fd_set error = _set;

		FD_SET(breaker.to!int, &read);
		select(&read, &write, &error);
		breaker.flush();

		return base.Selected(
			[],
			write.toDescriptors(descriptors),
			error.toDescriptors(descriptors)
		);
	}

	base.Selected available(string mode) (Duration timeout)
		if (mode == "write")
	{
		fd_set read;
		fd_set write = _set;
		fd_set error = _set;

		FD_SET(breaker.to!int, &read);
		select(&read, &write, &error, timeout.toTimeval);
		breaker.flush();

		return base.Selected(
			[],
			write.toDescriptors(descriptors),
			error.toDescriptors(descriptors)
		);
	}

	void select (fd_set* read, fd_set* write, fd_set* error)
	{
		try {
			errnoEnforce(.select(max, read, write, error, null) >= 0);
		}
		catch (ErrnoException e) {
			if (e.errno != EINTR) {
				throw e;
			}
		}
	}

	void select (fd_set* read, fd_set* write, fd_set* error, timeval timeout)
	{
		try {
			errnoEnforce(.select(max, read, write, error, &timeout) >= 0);
		}
		catch (ErrnoException e) {
			if (e.errno != EINTR) {
				throw e;
			}
		}
	}

	@property max ()
	{
		if (descriptors.empty) {
			return 1;
		}

		if (_max <= 0) {
			_max = descriptors.map!("a.to!int").reduce!(.max) + 1;
		}

		return _max;
	}

private:
	fd_set _set;
	int    _max;
}

private:
	timeval toTimeval (Duration duration)
	{
		return timeval(cast (time_t) duration.total!"seconds", cast (suseconds_t) duration.fracSec.usecs);
	}

	Descriptor[] toDescriptors (fd_set set, Descriptor[] descriptors)
	{
		Descriptor[] result;

		foreach (descriptor; descriptors) {
			if (FD_ISSET(descriptor.to!int, &set)) {
				result ~= descriptor;
			}
		}

		return result;
	}
