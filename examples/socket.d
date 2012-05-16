import std.stdio;
import std.socket : TcpSocket;
import nucular.reactor;

template Watcher {
	void notifyReadable () {
		writeln("read me please, it hurts :(");
	}
}

void main () {
	foreach (sig; ["INT", "TERM"]) {
		nucular.reactor.trap(sig, {
			nucular.reactor.stop();
		});
	}

	nucular.reactor.run({
		auto socket = new TcpSocket(new InternetAddress("google.com", 80));

		socket.watch!Watcher;
	});
}
