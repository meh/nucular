import std.stdio;
import std.getopt;
import std.regex : ctRegex, match;
import std.conv;
import std.array;
import core.thread;

import nucular.reactor;
import line = nucular.protocols.line;

class RawSender : Connection
{
	override void receiveData (ubyte[] data)
	{
		writeln(data);
	}
}

class LineSender : line.Protocol
{
	override void receiveLine (string line)
	{
		writeln(line);
	}
}

int main (string[] args)
{
	Address address;
	string  protocol = "tcp";
	string  target   = "localhost:10000";
	bool    ipv4     = true;
	bool    ipv6     = false;
	bool    ssl      = false;
	bool    line     = false;

	getopt(args, config.noPassThrough,
		"protocol|p", &protocol,
		"4",          &ipv4,
		"6",          &ipv6,
		"ssl|s",      &ssl,
		"line|l",     &line);

	if (args.length >= 2) {
		target = args.back;
	}

	switch (protocol) {
		case "tcp":
		case "udp":
			if (auto m = target.match(ctRegex!`^(.*?):(\d+)$`)) {
				string host = m.captures[1];
				ushort port = m.captures[2].to!ushort(10);

				address = ipv6 ?
					ssl ? new SecureInternet6Address(host, port) : new Internet6Address(host, port) :
					ssl ? new SecureInternetAddress(host, port) : new InternetAddress(host, port);
			}
			break;

		version (Posix) {
			case "unix":
				address = new UnixAddress(target);
				break;

			case "fifo":
				address = new NamedPipeAddress(target);
				break;
		}
		
		default:
			writeln("! unsupported protocol");
			return 1;
	}

	nucular.reactor.run({
		auto connection = line ? address.connect!LineSender(protocol) : address.connect!RawSender(protocol);

		(new Thread({
			char[] data;

			try {
				while (stdin.readln(data)) {
					if (line) {
						auto sender = cast (LineSender) connection;

						sender.sendLine(cast (string) data[0 .. data.length - 1]);
					}
					else {
						auto sender = cast (RawSender) connection;

						sender.sendData(cast (ubyte[]) data[0 .. data.length - 1]);
					}
				}
			}
			catch (Exception e) {
				writeln("! ", e.msg);
			}

			nucular.reactor.stop();
		})).start();
	});

	return 0;
}
