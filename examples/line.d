import std.stdio;
import nucular.reactor;
import line = nucular.protocols.line;

class LineServer : line.Protocol
{
	void receiveLine (string line)
	{
		sendLine(line);
	}
}

void main ()
{
	nucular.reactor.run({
		(new InternetAddress(10000)).startServer!LineServer;
	});
}
