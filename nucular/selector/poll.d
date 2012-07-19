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
import std.conv;
import std.exception;

import nucular.descriptor;
import base = nucular.selector.base;

class Selector : base.Selector
{
	this ()
	{
		super();

		pollfd p = { fd: breaker.to!int, events: POLLIN };

		_set ~= p;
	}

	override bool add (Descriptor descriptor)
	{
		if (!super.add(descriptor)) {
			return false;
		}

		pollfd p = { fd: descriptor.to!int };

		_set  ~= p;
		_last  = null;

		return true;
	}

	override bool remove (Descriptor descriptor)
	{
		if (!super.remove(descriptor)) {
			return false;
		}

		_set = _set.remove(_set.countUntil!(a => a.fd == descriptor.to!int));

		return true;
	}

	base.Selected available() ()
	{
		poll();

		return base.Selected(to!"read", to!"write", to!"error");
	}

	base.Selected available() (Duration timeout)
	{
		poll(timeout.total!("msecs").to!int);

		return base.Selected(to!"read", to!"write", to!"error");
	}

	base.Selected available(string mode) ()
		if (mode == "read")
	{
		poll!"read";

		return base.Selected(to!"read", [], to!"error");
	}

	base.Selected available(string mode) (Duration timeout)
		if (mode == "read")
	{
		poll!"read"(timeout.total!("msecs").to!int);

		return base.Selected(to!"read", [], to!"error");
	}

	base.Selected available(string mode) ()
		if (mode == "write")
	{
		poll!"write";

		return base.Selected([], to!"write", to!"error");
	}

	base.Selected available(string mode) (Duration timeout)
		if (mode == "write")
	{
		poll!"write"(timeout.total!("msecs").to!int);

		return base.Selected([], to!"write", to!"error");
	}

	void set(string mode) ()
		if (mode == "both" || mode == "read" || mode == "write")
	{
		if (_last == mode) {
			return;
		}

		foreach (ref p; _set[1 .. $]) {
			static if (mode == "both") {
				p.events = POLLIN | POLLOUT;
			}
			else static if (mode == "read") {
				p.events = POLLIN;
			}
			else static if (mode == "write") {
				p.events = POLLOUT;
			}
		}

		_last = mode;
	}

	Descriptor[] to(string mode) ()
		if (mode == "read" || mode == "write" || mode == "error")
	{
		Descriptor[] result;

		foreach (index, ref p; _set[1 .. $]) {
			static if (mode == "read") {
				if (p.revents & POLLIN) {
					result ~= descriptors[index];
				}
			}
			else static if (mode == "write") {
				if (p.revents & POLLOUT) {
					result ~= descriptors[index];
				}
			}
			else static if (mode == "error") {
				if (p.revents & (POLLERR | POLLHUP)) {
					result ~= descriptors[index];
				}
			}
		}

		return result;
	}

	void poll(string mode = "both") (int timeout = -1)
	{
		set!mode;

		try {
			errnoEnforce(.poll(_set.ptr, _set.length, timeout) >= 0);
		}
		catch (ErrnoException e) {
			if (e.errno != EINTR && e.errno != EAGAIN) {
				throw e;
			}
		}

		breaker.flush();
	}

private:
	pollfd[] _set;
	string   _last;
}
