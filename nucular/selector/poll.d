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

module nucular.selector.poll;

version (poll):

import core.time;
import core.stdc.errno;

import core.sys.posix.poll;

import std.algorithm;
import std.array;
import std.conv;
import std.exception;

import nucular.descriptor;
import base = nucular.selector.base;

class Selector : base.Selector
{
	override void add (Descriptor descriptor)
	{
		pollfd p = { fd: descriptor.to!int };

		_set ~= p;

		super.add(descriptor);
	}

	override void remove (Descriptor descriptor)
	{
		_set.remove(_set.countUntil!(a => a.fd == descriptor.to!int));

		super.remove(descriptor);
	}

	base.Selected available() ()
	{
		reset().write().read();

		poll(-1);

		return base.Selected(prepare(to!"read"), prepare(to!"write"), prepare(to!"error"));
	}

	base.Selected available() (Duration timeout)
	{
		reset().write().read();

		poll(timeout.total!("msecs").to!int);

		return base.Selected(prepare(to!"read"), prepare(to!"write"), prepare(to!"error"));
	}

	base.Selected available(string mode) ()
		if (mode == "read")
	{
		reset().read();

		poll(-1);

		return base.Selected(prepare(to!"read"), [], prepare(to!"error"));
	}

	base.Selected available(string mode) (Duration timeout)
		if (mode == "read")
	{
		reset().read();

		poll(timeout.total!("msecs").to!int);

		return base.Selected(prepare(to!"read"), [], prepare(to!"error"));
	}

	base.Selected available(string mode) ()
		if (mode == "write")
	{
		reset().write();

		poll(-1);

		return base.Selected([], prepare(to!"write"), prepare(to!"error"));
	}

	base.Selected available(string mode) (Duration timeout)
		if (mode == "write")
	{
		reset().write();

		poll(timeout.total!("msecs").to!int);

		return base.Selected([], prepare(to!"write"), prepare(to!"error"));
	}

	auto reset ()
	{
		foreach (ref p; _set) {
			p.events &= ~POLLIN & ~POLLOUT;
		}

		return this;
	}

	auto write ()
	{
		foreach (ref p; _set) {
			p.events |= POLLOUT;
		}

		return this;
	}

	auto read ()
	{
		foreach (ref p; _set) {
			p.events |= POLLIN;
		}

		return this;
	}

	Descriptor[] to(string mode) ()
		if (mode == "read")
	{
		Descriptor[] result;

		foreach (index, ref p; _set) {
			if (p.revents & POLLIN) {
				result ~= descriptors[index];
			}
		}

		return result;
	}

	Descriptor[] to(string mode) ()
		if (mode == "write")
	{
		Descriptor[] result;

		foreach (index, ref p; _set) {
			if (p.revents & POLLOUT) {
				result ~= descriptors[index];
			}
		}

		return result;
	}

	Descriptor[] to(string mode) ()
		if (mode == "error")
	{
		Descriptor[] result;

		foreach (index, ref p; _set) {
			if (p.revents & POLLERR || p.revents & POLLHUP) {
				result ~= descriptors[index];
			}
		}

		return result;
	}

	void poll (int timeout)
	{
		try {
			errnoEnforce(.poll(_set.ptr, _set.length, timeout) >= 0);
		}
		catch (ErrnoException e) {
			if (e.errno != EINTR && e.errno != EAGAIN) {
				throw e;
			}
		}
	}

private:
	pollfd[] _set;
}
