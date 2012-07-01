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

module nucular.selector.epoll;

version (epoll):

import core.time;
import core.stdc.errno;
import core.sys.posix.unistd;

import std.algorithm;
import std.array;
import std.conv;
import std.exception;

import nucular.descriptor;
import base = nucular.selector.base;

class Selector : base.Selector
{
	this ()
	{
		super();

		errnoEnforce((_efd = epoll_create1(0)) >= 0);

		epoll_event p;
		p.events   = EPOLLIN;
		p.data.u32 = uint.max;

		errnoEnforce(epoll_ctl(_efd, EPOLL_CTL_ADD, breaker.to!int, &p) == 0);

		resize(4096);
	}

	~this ()
	{
		.close(_efd);
	}

	override bool add (Descriptor descriptor)
	{
		if (!super.add(descriptor)) {
			return false;
		}

		epoll_event event;

		try {
			errnoEnforce(epoll_ctl(_efd, EPOLL_CTL_ADD, descriptor.to!int, &event) == 0);
		}
		catch (ErrnoException e) {
			if (e.errno != EEXIST) {
				throw e;
			}
		}

		_last = null;

		return true;
	}

	override bool remove (Descriptor descriptor)
	{
		if (!super.remove(descriptor)) {
			return false;
		}

		try {
			errnoEnforce(epoll_ctl(_efd, EPOLL_CTL_DEL, descriptor.to!int, null) == 0);
		}
		catch (ErrnoException e) {
			if (e.errno != ENOENT) {
				throw e;
			}
		}

		_last = null;

		return true;
	}

	void resize (size_t size)
	{
		_events.length = size;
	}

	base.Selected available() ()
	{
		epoll();

		return base.Selected(to!"read", to!"write", to!"error");
	}

	base.Selected available() (Duration timeout)
	{
		epoll(timeout.total!("msecs").to!int);

		return base.Selected(to!"read", to!"write", to!"error");
	}

	base.Selected available(string mode) ()
		if (mode == "read")
	{
		epoll!"read";

		return base.Selected(to!"read", [], to!"error");
	}

	base.Selected available(string mode) (Duration timeout)
		if (mode == "read")
	{
		epoll!"read"(timeout.total!("msecs").to!int);

		return base.Selected(to!"read", [], to!"error");
	}

	base.Selected available(string mode) ()
		if (mode == "write")
	{
		epoll!"write";

		return base.Selected([], to!"write", to!"error");
	}

	base.Selected available(string mode) (Duration timeout)
		if (mode == "write")
	{
		epoll!"write"(timeout.total!("msecs").to!int);

		return base.Selected([], to!"write", to!"error");
	}

	void set(string mode) ()
		if (mode == "both" || mode == "read" || mode == "write")
	{
		if (_last == mode) {
			return;
		}

		epoll_event event;

		static if (mode == "both") {
			event.events = EPOLLIN | EPOLLOUT;
		}
		else static if (mode == "read") {
			event.events = EPOLLIN;
		}
		else static if (mode == "write") {
			event.events = EPOLLOUT;
		}

		foreach (index, descriptor; descriptors) {
			event.data.u64 = index;

			errnoEnforce(epoll_ctl(_efd, EPOLL_CTL_MOD, descriptor.to!int, &event) == 0);
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

		// XXX: somehow it's fucking up the u64, so we use u32, it won't
		//      be able to handle 4 billion fds anyway.
		foreach (ref current; _events[0 .. _length]) {
			if (current.data.u32 == uint.max) {
				continue;
			}

			static if (mode == "read") {
				if (current.events & EPOLLIN) {
					result ~= descriptors[current.data.u32];
				}
			}
			else static if (mode == "write") {
				if (current.events & EPOLLOUT) {
					result ~= descriptors[current.data.u32];
				}
			}
			else static if (mode == "error") {
				if (current.events & (EPOLLERR | EPOLLHUP)) {
					result ~= descriptors[current.data.u32];
				}
			}
		}

		return result;
	}

	void epoll(string mode = "both") (int timeout = -1)
	{
		set!mode;

		try {
			errnoEnforce((_length = epoll_wait(_efd, _events.ptr, cast (int) _events.length, timeout)) >= 0);
		}
		catch (ErrnoException e) {
			if (e.errno != EINTR && e.errno != EAGAIN) {
				throw e;
			}
		}

		breaker.flush();
	}

private:
	int           _efd;
	epoll_event[] _events;
	int           _length;
	string        _last;
}

private extern (C):
	union epoll_data
	{
		void* ptr;
		int   fd;
		uint  u32;
		ulong u64;
	}

	align (1) struct epoll_event
	{
		uint       events;
		epoll_data data;
	}

	enum
	{
		EPOLL_CLOEXEC  = octal!2000000,
		EPOLL_NONBLOCK = octal!4000
	}

	enum
	{
		EPOLLIN      = 0x001,
		EPOLLPRI     = 0x002,
		EPOLLOUT     = 0x004,
		EPOLLRDNORM  = 0x040,
		EPOLLRDBAND  = 0x080,
		EPOLLWRNORM  = 0x100,
		EPOLLWRBAND  = 0x200,
		EPOLLMSG     = 0x400,
		EPOLLERR     = 0x008,
		EPOLLHUP     = 0x010,
		EPOLLRDHUP   = 0x2000,
		EPOLLONESHOT = 1u << 30,
		EPOLLET      = 1u << 31
	}

	enum
	{
		EPOLL_CTL_ADD = 1,
		EPOLL_CTL_DEL,
		EPOLL_CTL_MOD
	}

	int epoll_create (int size);
	int epoll_create1 (int flags);
	int epoll_ctl (int epfd, int op, int fd, epoll_event* event);
	int epoll_wait (int epfd, epoll_event* events, int maxevents, int timeout);
