import std.stdio;
import nucular.threadpool;

void main () {
	auto pool1 = new ThreadPool;
	auto pool2 = new ThreadPool;

	pool1.process({ writeln(";)"); });
	pool2.process({ writeln(":("); });

	// shutdown has to be done, otherwise the process won't end properly
	pool1.shutdown();
	pool2.shutdown();
}
