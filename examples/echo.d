import std.stdio;
import nucular.reactor;

class EchoServer : Connection
{
	void receiveData (ubyte[] data)
	{
		sendData(data);
	}
}

void main ()
{
	nucular.reactor.run({
		(new InternetAddress(10000)).startServer!EchoServer;
	});
}
