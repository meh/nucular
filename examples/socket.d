import std.stdio;
import std.socket : TcpSocket;
import nucular.reactor;

class Watcher : nucular.reactor.Connection {
	void notifyReadable () {
		writeln("read me please, it hurts :(");
	}
}

void main () {
	nucular.reactor.run({
		(new TcpSocket(new InternetAddress("google.com", 80))).watch!Watcher();
	});
}
