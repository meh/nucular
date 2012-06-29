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

import std.conv;
import std.string;
import std.algorithm;

import nucular.protocols.http.grammar;
import nucular.protocols.http.prelude;
import nucular.protocols.http.headers;

class Parser
{
	enum State
	{
		Prelude,
		Headers,
		Content,
		Finished,
		Error
	}

	static Parser forHeaders (string initial = null)
	{
		auto r = new Parser;

		r.onlyHeaders = true;
		r.parse(initial);

		return r;
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

	ref onPrelude (void delegate (ref Prelude) block)
	{
		_on_prelude = block;

		return this;
	}

	ref onHeader (void delegate (ref Header) block)
	{
		_on_header = block;

		return this;
	}

	ref onHeaders (void delegate (ref Headers) block)
	{
		_on_headers = block;

		return this;
	}

	ref onChunk (void delegate (ubyte[]) block)
	{
		_on_chunk = block;

		return this;
	}

	ref onContent (void delegate (ubyte[]) block)
	{
		_on_content = block;

		return this;
	}

	State parse (ref string data)
	{
		if (state == State.Prelude) {
			auto tree = Grammar.StatusLine.parse(data);

			if (tree.success) {
				if (tree.children[0].ruleName == "Version") {
					_prelude = new Prelude(tree.capture[0].to!string, tree.capture[1].to!short, tree.capture[2].to!string);
				}
				else {
					_prelude = new Prelude(tree.capture[1].to!string, tree.capture[0].to!string, tree.capture[1].to!string);
				}

				if (_on_prelude) {
					_on_prelude(_prelude);
				}

				data   = data[tree.end.index .. $];
				_state = State.Headers;
			}
		}

		if (state == State.Headers) {
			if (!_headers) {
				_headers = new Headers;
			}

			auto upto    = data.countUntil("\r\n\r\n");
			auto headers = upto == -1 ? data : data[0 .. upto];

			foreach (line; headers.splitLines) {
				auto tree = Grammar.MessageHeader.parse(line);

				if (tree.success) {
					auto h = new Header(tree.capture[0].to!string, tree.capture[1].to!string);

					if (_on_header) {
						_on_header(h);
					}

					_headers.add(h);
				}
			}

			if (upto != -1) {
				if (_on_headers) {
					_on_headers(_headers);
				}

				data = data[upto + 4 .. $];

				if (onlyHeaders) {
					_state = State.Finished;
				}
				else {
					_state = State.Content;
				}
			}
		}

		if (state == State.Content) {
			if (!_headers["Content-Length"] && _headers["Transfer-Encoding", true] != "chunked") {
				return _state = State.Error;
			}

			if (auto h = _headers["Content-Length"]) {
				if (_on_chunk) {
					_on_chunk(cast (ubyte[]) data);
				}

				if (_length + data.length >= h.value.to!size_t) {
					if (_on_content || !_on_chunk) {
						_content ~= cast (ubyte[]) data[0 .. h.value.to!size_t - _length];
						_length  += data.length;
						data      = data[h.value.to!size_t - _length .. $];

						if (_on_content) {
							_on_content(cast (ubyte[]) _content);
						}
					}
					else {
						data = data[h.value.to!size_t - _length .. $];
					}

					if (_on_end) {
						_on_end(this);
					}

					_state = State.Finished;
				}
				else {
					if (_on_content) {
						_content ~= cast (ubyte[]) data;
					}

					_length += data.length;

					data = [];
				}
			}
			else {
				// TODO: implement chunked transfer
				assert(0);
			}
		}

		return _state;
	}

	@property prelude ()
	{
		return _prelude;
	}

	@property headers ()
	{
		return _headers;
	}

	@property content ()
	{
		return _content;
	}

	@property state ()
	{
		return _state;
	}

	@property onlyHeaders ()
	{
		return _only_headers;
	}

	@property onlyHeaders (bool value)
	{
		_only_headers = value;
	}

private:
	Prelude _prelude;
	Headers _headers;
	ubyte[] _content;

	State  _state;
	size_t _length;

	bool _only_headers;

	void delegate (ref Prelude) _on_prelude;
	void delegate (ref Header)  _on_header;
	void delegate (ref Headers) _on_headers;
	void delegate (ubyte[])     _on_chunk;
	void delegate (ubyte[])     _on_content;
	void delegate (ref Parser)  _on_end;
}
