import nucular.reactor;

void main () {
	mixin template EchoServer {
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
