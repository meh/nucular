import std.stdio;
import nucular.reactor;

void main () {
	foreach (sig; ["INT", "TERM"]) {
		trap(sig, {
			stop();
		});
	}

	class EchoServer : Connection {
		void receiveData (ubyte[] data) {
			sendData(data);
		}
	}

	run({
		(new InternetAddress(10000)).startServer!EchoServer;
	});
}
