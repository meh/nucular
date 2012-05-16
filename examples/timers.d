import std.stdio;
import nucular.reactor;

void main () {
	run({
		addTimer(11.dur!"seconds", {
			stop();
		});

		addPeriodicTimer(2.dur!"seconds", {
			static i = 1;

			writeln(i++);
		});
	});

	writeln("bye");
}
