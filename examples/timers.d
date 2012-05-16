import std.stdio;
import nucular.reactor;

void main () {
	nucular.reactor.run({
		nucular.reactor.addTimer(11.dur!"seconds", {
			nucular.reactor.stop();
		});

		nucular.reactor.addPeriodicTimer(2.dur!"seconds", {
			static i = 1;

			writeln(i++);
		});
	});

	writeln("bye");
}
