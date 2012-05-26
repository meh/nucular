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
		(new ProxiedAddress("automation.whatismyip.com", 80)).
			connectThrough!Reader(new InternetAddress("localhost", 9051)).
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
