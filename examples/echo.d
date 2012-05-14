import std.stdio;
import nucular.reactor;

class EchoServer : nucular.reactor.Connection {
	void receiveData (ubyte[] data) {
		sendData(data);
	}
}

void main () {
	foreach (sig; ["INT", "TERM"]) {
		nucular.reactor.trap(sig, {
			nucular.reactor.stop();
		});
	}

	nucular.reactor.run({
		(new InternetAddress(10000)).startServer!EchoServer;
	});
}
