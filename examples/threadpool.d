import std.stdio;
import std.array;
import core.thread;
import nucular.threadpool;

void main () {
	auto pool1 = new ThreadPool;
	auto pool2 = new ThreadPool;

	pool1.process({ writeln(";)"); });
	pool2.processWith(23, (int a) { writeln(":( ".replicate(a)); });

	// shutdown has to be done, otherwise the process won't end properly
	pool1.shutdown();
	pool2.shutdown();
}
