import std.stdio;
import nucular.reactor;

void main () {
	nucular.reactor.run({
		nucular.reactor.addTimer(4.dur!"seconds", {
			writeln("lol");
		});

		nucular.reactor.addPeriodicTimer(2.dur!"seconds", {
			static i = 0;

			writeln("yo");

			nucular.reactor.stop();

			if (i++ >= 5) {
				nucular.reactor.stop();
			}
		});
	});
}
