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

module nucular.selector.kqueue;

version (kqueue):

import core.time;
import core.stdc.errno;
import core.sys.freebsd.sys.event;
import core.sys.posix.time;
import core.sys.posix.unistd;

import std.algorithm;
import std.array;
import std.range;
import std.conv;
import std.exception;

import nucular.descriptor;
import base = nucular.selector.base;

class Selector : base.Selector
{
	this ()
	{
		super();

		errnoEnforce((_kq = kqueue()) >= 0);

		kevent_t ev;

		EV_SET(&ev, breaker.to!int, EVFILT_READ, EV_ADD | EV_ENABLE, 0, 0, cast (void*) size_t.max);
		errnoEnforce(.kevent(_kq, &ev, 1, null, 0, null) >= 0);

		resize(4096);
	}

	~this ()
	{
		.close(_kq);
	}

	override bool add (Descriptor descriptor)
	{
		if (!super.add(descriptor)) {
			return false;
		}

		_last = null;

		return true;
	}

	override bool remove (Descriptor descriptor)
	{
		if (!super.remove(descriptor)) {
			return false;
		}

		kevent_t ev;

		try {
			EV_SET(&ev, descriptor.to!int, EVFILT_READ, EV_DELETE, 0, 0, null);
			errnoEnforce(.kevent(_kq, &ev, 1, null, 0, null) >= 0);
		}
		catch (ErrnoException e) {
			if (e.errno != ENOENT) {
				throw e;
			}
		}

		try {
			EV_SET(&ev, descriptor.to!int, EVFILT_WRITE, EV_DELETE, 0, 0, null);
			errnoEnforce(.kevent(_kq, &ev, 1, null, 0, null) >= 0);
		}
		catch (ErrnoException e) {
			if (e.errno != ENOENT) {
				throw e;
			}
		}

		_last = null;

		return true;
	}

	void resize (int size)
	{
		_events.length = size;
	}

	base.Selected available() ()
	{
		kevent!"both"();

		return base.Selected(to!"read", to!"write", to!"error");
	}

	base.Selected available() (Duration timeout)
	{
		kevent!"both"(timeout);

		return base.Selected(to!"read", to!"write", to!"error");
	}

	base.Selected available(string mode) ()
		if (mode == "read")
	{
		kevent!"read"();

		return base.Selected(to!"read", [], to!"error");
	}

	base.Selected available(string mode) (Duration timeout)
		if (mode == "read")
	{
		kevent!"read"(timeout);

		return base.Selected(to!"read", [], to!"error");
	}

	base.Selected available(string mode) ()
		if (mode == "write")
	{
		kevent!"write"();

		return base.Selected([], to!"write", to!"error");
	}

	base.Selected available(string mode) (Duration timeout)
		if (mode == "write")
	{
		kevent!"write"(timeout);

		return base.Selected([], to!"write", to!"error");
	}

	void set(string mode) ()
		if (mode == "both" || mode == "read" || mode == "write")
	{
		if (_last == mode) {
			return;
		}

		kevent_t ev;

		foreach (index, descriptor; descriptors) {
			EV_SET(&ev, descriptor.to!int, 0, 0, 0, 0, cast (void*) index);

			static if (mode == "read") {
				if (_last == "both") {
					ev.filter = EVFILT_WRITE;
					ev.flags  = EV_ADD | EV_DISABLE;

					errnoEnforce(.kevent(_kq, &ev, 1, null, 0, null) >= 0);
				}
			}
			else static if (mode == "write") {
				if (_last == "both") {
					ev.filter = EVFILT_READ;
					ev.flags  = EV_ADD | EV_DISABLE;

					errnoEnforce(.kevent(_kq, &ev, 1, null, 0, null) >= 0);
				}
			}

			static if (mode == "read" || mode == "both") {
				ev.filter = EVFILT_READ;
				ev.flags  = EV_ADD | EV_ENABLE;

				errnoEnforce(.kevent(_kq, &ev, 1, null, 0, null) >= 0);
			}

			static if (mode == "write" || mode == "both") {
				ev.filter = EVFILT_WRITE;
				ev.flags  = EV_ADD | EV_ENABLE;

				errnoEnforce(.kevent(_kq, &ev, 1, null, 0, null) >= 0);
			}
		}

		_last = mode;
	}

	Descriptor[] to(string mode) ()
		if (mode == "read" || mode == "write" || mode == "error")
	{
		if (_length <= 0) {
			return null;
		}

		Descriptor[] result;

		foreach (ref current; _events[0 .. _length]) {
			if (cast (size_t) current.udata == size_t.max) {
				continue;
			}

			static if (mode == "read") {
				if (current.filter == EVFILT_READ) {
					result ~= descriptors[cast (size_t) current.udata];
				}
			}
			else static if (mode == "write") {
				if (current.filter == EVFILT_WRITE) {
					result ~= descriptors[cast (size_t) current.udata];
				}
			}
			else static if (mode == "error") {
				if (current.flags & EV_ERROR) {
					result ~= descriptors[cast (size_t) current.udata];
				}
			}
		}

		static if (mode == "error") {
			return result.uniq.array;
		}
		else {
			return result;
		}
	}

	void kevent(string mode) ()
	{
		set!mode;

		try {
			errnoEnforce((_length = .kevent(_kq, null, 0, _events.ptr, _events.length, null)) >= 0);
		}
		catch (ErrnoException e) {
			if (e.errno != EINTR) {
				throw e;
			}
		}

		breaker.flush();
	}

	void kevent(string mode) (Duration timeout)
	{
		set!mode;

		auto t = timeout.toTimespec();

		try {
			errnoEnforce((_length = .kevent(_kq, null, 0, _events.ptr, _events.length, &t)) >= 0);
		}
		catch (ErrnoException e) {
			if (e.errno != EINTR) {
				throw e;
			}
		}

		breaker.flush();
	}

private:
	int    _kq;
	string _last;

	kevent_t[] _events;
	int        _length;
}

private:
	timespec toTimespec (Duration duration)
	{
		return timespec(cast (time_t) duration.total!"seconds", cast (long) duration.fracSec.usecs);
	}
