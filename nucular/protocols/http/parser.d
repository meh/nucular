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

module nucular.protocols.http.parser;

import nucular.protocols.http.grammar;
import nucular.protocols.http.prelude;
import nucular.protocols.http.headers;

class Parser
{
	enum State {
		Prelude,
		Headers,
		Content,
		Finished,
		Error
	}

	this ()
	{
		_state = State.Prelude;
	}

	this (string initial)
	{
		this();

		parse(initial);
	}

	ref Parser onPrelude (void delegate (ref Prelude) block)
	{
		_on_prelude = block;

		return this;
	}

	ref Parser onHeader (void delegate (ref Header) block)
	{
		_on_header = block;

		return this;
	}

	ref Parser onHeaders (void delegate (ref Headers) block)
	{
		_on_headers = block;

		return this;
	}

	ref Parser onChunk (void delegate (ubyte[]) block)
	{
		_on_chunk = block;

		return this;
	}

	ref Parser onContent (void delegate (ubyte[]) block)
	{
		_on_content = block;

		return this;
	}

	State parse (string data)
	{
		if (state == State.Prelude) {
			auto tree = Grammar.StartLine.parse(data);
		}

		return _state;
	}

	@property minimum ()
	{
		return _minimum;
	}

	@property state ()
	{
		return _state;
	}

private:
	Prelude _prelude;
	Headers _headers;
	ubyte[] _content;

	State _state;
	ulong _minimum;

	void delegate (ref Prelude) _on_prelude;
	void delegate (ref Header)  _on_header;
	void delegate (ref Headers) _on_headers;
	void delegate (ubyte[])     _on_chunk;
	void delegate (ubyte[])     _on_content;
	void delegate (ref Parser)  _on_end;
}
