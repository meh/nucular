import std.stdio;
import std.getopt;
import std.regex : ctRegex, match;
import std.conv;
import std.array;
import core.thread;

import nucular.reactor;
import line = nucular.protocols.line;

class RawSender : Connection
{
	override void receiveData (ubyte[] data)
	{
		writeln(data);
	}
}

class LineSender : line.Protocol
{
	override void receiveLine (string line)
	{
		writeln(line);
	}
}

int main (string[] args)
{
	string target = "tcp://localhost:10000";
	bool   line   = false;

	getopt(args, config.noPassThrough,
		"line|l", &line);

	if (args.length >= 2) {
		target = args.back;
	}

	nucular.reactor.run({
		try {
			auto connection = line ? target.connect!LineSender : target.connect!RawSender;

			(new Thread({
				char[] data;

				try {
					while (stdin.readln(data)) {
						if (line) {
							auto sender = cast (LineSender) connection;

							sender.sendLine(cast (string) data[0 .. data.length - 1]);
						}
						else {
							auto sender = cast (RawSender) connection;

							sender.sendData(cast (ubyte[]) data[0 .. data.length - 1]);
						}
					}
				}
				catch (Exception e) {
					writeln("! ", e.msg);
				}

				nucular.reactor.stop();
			})).start();
		}
		catch (Exception e) {
			writeln("! ", e.msg);
			nucular.reactor.stop();
		}
	});

	return 0;
}
