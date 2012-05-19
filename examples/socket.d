import std.stdio;
import std.socket : TcpSocket;
import nucular.reactor;

class Watcher : Connection
{
	void notifyReadable ()
	{
		writeln("read me please, it hurts :(");
	}
}

void main ()
{
	nucular.reactor.run({
		auto socket = new TcpSocket(new InternetAddress("google.com", 80));

		socket.watch!Watcher;
	});
}
