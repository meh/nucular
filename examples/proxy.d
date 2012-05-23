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
import std.regex;

import nucular.reactor;
import nucular.protocols.socks;

class Reader : Connection
{
	override void connected ()
	{
		sendData(cast (ubyte[]) "GET /n09230945.asp HTTP/1.1\r\nConnection: close\r\nHost: automation.whatismyip.com\r\n\r\n");
	}

	override void receiveData (ubyte[] data)
	{
		if (auto m = (cast (string) data).match(r"(\d+\.\d+\.\d+\.\d+)")) {
			writeln(m.captures[1]);

			closeConnection();
		}
	}

	override void unbind ()
	{
		nucular.reactor.stop();
	}
}

void main ()
{
	nucular.reactor.run({
		(new ProxiedAddress("automation.whatismyip.com", 80)).connectThrough!Reader(new InternetAddress("localhost", 9050));
	});
}
