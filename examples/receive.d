import std.stdio;
import std.getopt;
import std.regex;
import std.conv;
import std.array;

import nucular.reactor;
import line = nucular.protocols.line;

class RawEcho : Connection
{
	override void initialized ()
	{
		writeln(remoteAddress, " connected");
	}

	override void receiveData (ubyte[] data)
	{
		writeln(remoteAddress, " sent: ", data);

		sendData(data);
	}

	override void unbind ()
	{
		if (error) {
			writeln(remoteAddress, " disconnected because: ", error.message);
		}
		else {
			writeln(remoteAddress, " disconnected");
		}
	}
}

class LineEcho : line.Protocol
{
	override void initialized ()
	{
		writeln(remoteAddress, " connected");
	}

	override void receiveLine (string line)
	{
		writeln(remoteAddress, " sent: ", line);

		sendLine(line);
	}

	override void unbind ()
	{
		if (error) {
			writeln(remoteAddress, " disconnected because: ", error.message);
		}
		else {
			writeln(remoteAddress, " disconnected");
		}
	}
}

int main (string[] args)
{
	Address address;
	string  protocol = "tcp";
	string  listen   = "localhost:10000";
	bool    ipv4     = true;
	bool    ipv6     = false;
	bool    line     = false;

	getopt(args, config.noPassThrough,
		"protocol|p", &protocol,
		"4",          &ipv4,
		"6",          &ipv6,
		"line|l",     &line);

	if (args.length >= 2) {
		listen = args.back;
	}

	switch (protocol) {
		case "tcp":
		case "udp":
			if (auto m = listen.match(r"^(.*?):(\d+)$")) {
				string host = m.captures[1];
				ushort port = m.captures[2].toImpl!ushort(10);

				address = ipv6 ? new Internet6Address(host, port) : new InternetAddress(host, port);
			}
			break;

		version (Posix) {
			case "unix":
				address = new UnixAddress(listen);
				break;

			case "fifo":
				if (auto m = listen.match(r"^(.+?)(?::(\d+))?$")) {
					string path       = m.captures[1];
					int    permission = m.captures[2].empty ? octal!666 : m.captures[2].toImpl!int(8);

					address = new NamedPipeAddress(path, permission);
				}
				break;
		}
		
		default:
			writeln("! unsupported protocol");
			return 1;
	}

	nucular.reactor.run({
		Server server = line ? address.startServer!LineEcho(protocol) : address.startServer!RawEcho(protocol);

		nucular.reactor.stopOn("INT", "TERM");
	});

	return 0;
}
