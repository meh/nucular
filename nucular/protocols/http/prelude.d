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

module nucular.protocols.http.prelude;

import std.exception;

class Prelude
{
	enum Type {
		Request,
		Response
	}

	this (string method, string resource)
	{
		_type = Type.Response;

		_method   = method;
		_resource = resource;
	}

	this (short code, string message)
	{
		_type = Type.Request;

		_code    = code;
		_message = message;
	}

	@property code ()
	{
		enforce(type == Type.Request, "the Prelude has to be a response");

		return _code;
	}

	@property message ()
	{
		enforce(type == Type.Request, "the Prelude has to be a response");

		return _message;
	}

	@property method ()
	{
		enforce(type == Type.Request, "the Prelude has to be a request");

		return _method;
	}

	@property resource ()
	{
		enforce(type == Type.Request, "the Prelude has to be a request");

		return _resource;
	}

	@property type ()
	{
		return _type;
	}

private:
	Type _type;

	// response properties
	short  _code;
	string _message;

	// request properties
	string _method;
	string _resource;
}
