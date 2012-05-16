import std.stdio;
import std.socket : TcpSocket;
import nucular.reactor;

void main () {
	foreach (sig; ["INT", "TERM"]) {
		trap(sig, {
			stop();
		});
	}

	class Watcher : Connection {
		void notifyReadable () {
			writeln("read me please, it hurts :(");
		}
	}

	run({
		auto socket = new TcpSocket(new InternetAddress("google.com", 80));

		socket.watch!Watcher();
	});
}
