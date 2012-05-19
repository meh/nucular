import std.stdio;
import nucular.reactor;

void main ()
{
	nucular.reactor.run({
		writeln("oh noes ;_;");

		nucular.reactor.stop();
	});
}
