import std.stdio;
import nucular.reactor;

void main () {
	class EchoServer : nucular.reactor.Connection {
		void receiveData (ubyte[] data) {
			sendData(data);
		}
	}

	foreach (sig; ["INT", "TERM"]) {
		nucular.reactor.trap(sig, {
			nucular.reactor.stopEventLoop();
		});
	}

	nucular.reactor.run({
		nucular.reactor.startServer("any", 10000, EchoServer);
	});
}
