import std.stdio;
import std.regex;

import nucular.reactor;
import nucular.protocols.socks.server;

class SocksConnection : Socks4a
{
	override void initialized ()
	{
		writeln(remoteAddress, " connected");
	}

	override bool authenticate (string username)
	{
		writeln("auth: ", username);

		return true;
	}

	override void request (Type type, Address address)
	{
		writeln(type, " ", address, " ");
	}

	override void failedRequest (Exception e)
	{
		writeln(e.msg);
	}

	override void unbind ()
	{
		writeln(remoteAddress, " disconnected");
	}
}

void main (string[] args)
{
	string listen = "tcp://*:10000";

	if (args.length >= 2) {
		listen = args[1];
	}

	nucular.reactor.run({
		listen.startServer!SocksConnection;
	});
}
