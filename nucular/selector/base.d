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

module nucular.selector.base;

import core.time;
import std.algorithm;

import nucular.descriptor;

struct Result {
	Descriptor[] readable;
	Descriptor[] writable;
}

abstract class Selector
{
	class Breaker
	{
		this ()
		{
			version (Posix) {
				import core.sys.posix.unistd;

				int[2] pair;

				pipe(pair);

				_read  = new Descriptor(pair[0]);
				_write = new Descriptor(pair[1]);
			}
			else {
				static assert(0);
			}

			_write.asynchronous = true;
			_read.asynchronous  = true;
		}

		~this ()
		{
			_read.close();
			_write.close();
		}

		void act ()
		{
			_write.write("x");
		}

		void flush ()
		{
			while (_read.read(1024)) {
				continue;
			}
		}

		Descriptor to(T : Descriptor) ()
		{
			return _read;
		}

		override string toString ()
		{
			return "Breaker(r=" ~ _read.toString() ~ " w=" ~ _write.toString() ~ ")";
		}

	private:
		Descriptor _read;
		Descriptor _write;
	}

	this ()
	{
		_breaker = new Breaker;

		add(_breaker.to!Descriptor);
	}

	void add (Descriptor descriptor)
	{
		_descriptors ~= descriptor;
	}

	void remove (Descriptor descriptor)
	{
		_descriptors.remove(_descriptors.countUntil!(a => a == descriptor));
	}

	Result available ();
	Result available (Duration timeout);

	Descriptor[] readable ();
	Descriptor[] readable (Duration timeout);

	Descriptor[] writable ();
	Descriptor[] writable (Duration timeout);

	final void wait ()
	{
		auto descriptors = readable();

		foreach (descriptor; descriptors) {
			if (descriptor == _breaker.to!Descriptor) {
				_breaker.flush();
				break;
			}
		}
	}

	final void wait (Duration timeout)
	{
		auto descriptors = readable(timeout);

		foreach (descriptor; descriptors) {
			if (descriptor == _breaker.to!Descriptor) {
				_breaker.flush();
				break;
			}
		}
	}

	final void flush ()
	{
		_breaker.flush();
	}

	final void wakeUp ()
	{
		_breaker.act();
	}

	final @property empty ()
	{
		return length == 1;
	}

	final @property length ()
	{
		return _descriptors.length - 1;
	}

protected:
	final @property descriptors ()
	{
		return _descriptors;
	}

private:
	Breaker      _breaker;
	Descriptor[] _descriptors;
}
