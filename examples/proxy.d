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

void main (string[] args)
{
	string proxy = "socks://localhost:9050";

	if (args.length >= 2) {
		proxy = args[1];
	}

	nucular.reactor.run({
		(new UnresolvedAddress("automation.whatismyip.com", 80)).
			connectThrough!Reader(proxy).
				errback((Exception e){
					if (e) {
						writeln("! connection failed because: ", e.msg);
					}
					else {
						writeln("! connection to the proxy failed");
					}

					nucular.reactor.stop();
				});
	});
}
