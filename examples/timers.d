import std.stdio;
import nucular.reactor;

void main () {
	nucular.reactor.run({
		nucular.reactor.addTimer(4.dur!"seconds", {
			writeln("lol");
		});

		nucular.reactor.addPeriodicTimer(2.dur!"seconds", {
			writeln("yo");
		});
	});
}
