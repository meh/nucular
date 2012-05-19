import std.socket : TcpSocket;
import nucular.reactor;

template Watcher ()
{
	import std.stdio;

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
