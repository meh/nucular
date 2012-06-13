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
	string listen = "tcp://*:10000";
	bool   ssl    = false;
	bool   line   = false;

	getopt(args, config.noPassThrough,
		"ssl|s",  &ssl,
		"line|l", &line);

	if (args.length >= 2) {
		listen = args.back;
	}

	nucular.reactor.run({
		try {
			auto server = line ?
				listen.startServer!LineEcho((c) { if (ssl) c.secure(); }) :
				listen.startServer!RawEcho((c) { if (ssl) c.secure(); });
		}
		catch (Exception e) {
			writeln("! ", e.msg);
			nucular.reactor.stop();
		}

		nucular.reactor.stopOn("INT", "TERM");
	});

	return 0;
}
