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
		FD_ZERO(&_set);
	}

	override void add (Descriptor descriptor)
	{
		super.add(descriptor);

		FD_SET(descriptor.to!int, &_set);

		_max = 0;
	}

	override void remove (Descriptor descriptor)
	{
		super.remove(descriptor);

		FD_CLR(descriptor.to!int, &_set);

		_max = 0;
	}

	override base.Result available ()
	{
		fd_set read  = _set;
		fd_set write = _set;

		select(&read, &write);

		return base.Result(read.to!(Descriptor[])(descriptors), write.to!(Descriptor[])(descriptors));
	}

	override base.Result available (Duration timeout)
	{
		fd_set read  = _set;
		fd_set write = _set;

		select(&read, &write, timeout.to!timeval);

		return base.Result(read.to!(Descriptor[])(descriptors), write.to!(Descriptor[])(descriptors));
	}

	override Descriptor[] readable ()
	{
		fd_set set = _set;

		select(&set, null);

		return set.to!(Descriptor[])(descriptors);
	}

	override Descriptor[] readable (Duration timeout)
	{
		fd_set set = _set;

		select(&set, null, timeout.to!timeval);

		return set.to!(Descriptor[])(descriptors);
	}

	override Descriptor[] writable ()
	{
		fd_set set = _set;

		select(null, &set);

		return set.to!(Descriptor[])(descriptors);
	}

	override Descriptor[] writable (Duration timeout)
	{
		fd_set set = _set;

		select(null, &set, timeout.to!timeval);

		return set.to!(Descriptor[])(descriptors);
	}

	void select (fd_set* read, fd_set* write)
	{
		try {
			errnoEnforce(.select(max, read, write, null, null) >= 0);
		}
		catch (ErrnoException e) {
			if (e.errno != EINTR) {
				throw e;
			}
		}
	}

	void select (fd_set* read, fd_set* write, timeval timeout)
	{
		try {
			errnoEnforce(.select(max, read, write, null, &timeout) >= 0);
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
	timeval to(T : timeval) (Duration duration)
	{
		return timeval(duration.total!"seconds", duration.fracSec.usecs);
	}

	Descriptor[] to(T : Descriptor[]) (fd_set set, Descriptor[] descriptors)
	{
		Descriptor[] result;

		foreach (descriptor; descriptors) {
			if (FD_ISSET(descriptor.to!int, &set)) {
				result ~= descriptor;
			}
		}

		return result;
	}
