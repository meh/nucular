import std.stdio;
import std.socket : TcpSocket;
import nucular.reactor;

void main () {
	foreach (sig; ["INT", "TERM"]) {
		nucular.reactor.trap(sig, {
			nucular.reactor.stop();
		});
	}

	class Watcher : Connection {
		void notifyReadable () {
			writeln("read me please, it hurts :(");
		}
	}

	nucular.reactor.run({
		auto socket = new TcpSocket(new InternetAddress("google.com", 80));

		socket.watch!Watcher();
	});
}
