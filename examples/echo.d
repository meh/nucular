import std.stdio;
import nucular.reactor;

void main () {
	foreach (sig; ["INT", "TERM"]) {
		nucular.reactor.trap(sig, {
			nucular.reactor.stop();
		});
	}

	class EchoServer : Connection {
		void receiveData (ubyte[] data) {
			sendData(data);
		}
	}

	nucular.reactor.run({
		(new InternetAddress(10000)).startServer!EchoServer;
	});
}
