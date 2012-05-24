import std.stdio;
import nucular.reactor;
import std.socket : Address;
import line = nucular.protocols.line;

class LineServer : line.Protocol
{
	override void receiveLine (string line)
	{
		sendLine(line);
	}
}

void main ()
{
	nucular.reactor.run({
		(new UnixAddress("/tmp/omg.unix")).startServer!LineServer;
	});
}
