import std.stdio;
import nucular.threadpool;

void main () {
	auto pool = new ThreadPool;

	pool.process({ writeln(";)"); });
	pool.shutdown();

	writeln("D:");
}
