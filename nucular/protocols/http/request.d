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

module nucular.protocols.http.request;

import std.string;

import nucular.connection;
import nucular.protocols.http.headers;

abstract class Request
{
	this (string resource)
	{
		_resource = resource;
		_headers  = new Headers;
	}

	void send (Connection connection)
	{
		
	}

	Request callback (void delegate (Request) block)
	{
		_callback = block;

		return this;
	}

	Request errback (void delegate (Request) block)
	{
		_errback = block;

		return this;
	}

	Request chunk (void delegate (Request, ubyte[] data) block)
	{
		_chunk = block;

		return this;
	}

	@property name () pure const
	{
		string name = this.classinfo.name;
		long   last = name.lastIndexOf('.');

		return name[last == -1 ? 0 : last + 1 .. $].toUpper();
	}

	@property resource ()
	{
		return _resource;
	}

	@property headers ()
	{
		return _headers;
	}

private:
	string  _resource;
	Headers _headers;

	void delegate (Request)          _callback;
	void delegate (Request)          _errback;
	void delegate (Request, ubyte[]) _chunk;
}

class Options : Request
{
	this (string resource = "*")
	{
		super(resource);
	}
}

class Get : Request
{
	this (string resource)
	{
		super(resource);
	}
}

class Head : Request
{
	this (string resource)
	{
		super(resource);
	}
}

class Post : Request
{
	this (string resource)
	{
		super(resource);
	}
}

class Put : Request
{
	this (string resource)
	{
		super(resource);
	}
}

class Delete : Request
{
	this (string resource)
	{
		super(resource);
	}
}

class Trace : Request
{
	this (string resource)
	{
		super(resource);
	}
}

class Connect : Request
{
	this (string resource)
	{
		super(resource);
	}
}
