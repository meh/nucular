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

import std.stdio;
import std.conv;
import nucular.reactor;
import line = nucular.protocols.line;

class Sender : line.Protocol
{
	override void connected ()
	{
		if (_message) {
			sendLine(_message);
		}

		closeConnectionAfterWriting();
	}

	@property message (string data)
	{
		_message = data;
	}

private:
	string _message;
}

int main (string[] argv)
{
	if (argv.length != 4) {
		writeln("Usage: ", argv[0], " <host> <port> <message>");

		return 0;
	}

	nucular.reactor.run({
		(new InternetAddress(argv[1], argv[2].to!ushort)).connect!Sender((conn) {
			conn.message = argv[3];
		});
	});

	return 0;
}
