/* Copyleft meh. [http://meh.paranoid.pk | meh@paranoici.org]
 *
 * This file is part of nucular.
 *
 * nucular is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as published
 * by the Free Software Foundation, either version 3 of the License,
 * or (at your option) any later version.
 *
 * nucular is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with nucular. If not, see <http://www.gnu.org/licenses/>.
 ****************************************************************************/

module nucular.signal;

import core.stdc.signal;

version (Posix) {
	import core.sys.posix.signal;
}

import std.array;
import std.string;

void trap (void delegate (string) block)
{
	trap("ABRT", block);
	trap("FPE",  block);
	trap("ILL",  block);
	trap("INT",  block);
	trap("SEGV", block);
	trap("TERM", block);

	version (Posix) {
		trap("ALRM", block);
		trap("BUS",  block);
		trap("CHLD", block);
		trap("CONT", block);
		trap("HUP",  block);
		trap("PIPE", block);
		trap("QUIT", block);
		trap("STOP", block);
		trap("TSTP", block);
		trap("TTIN", block);
		trap("TTOU", block);
		trap("USR1", block);
		trap("USR2", block);
		trap("URG",  block);
	}
}

void trap (string name, void delegate (string) block)
{
	if (!name.toSignal()) {
		return;
	}

	if (name.toSignal() !in _callbacks) {
		signal(name.toSignal(), &signalHandler);
	}

	_callbacks[name.toSignal] ~= block;
}

void trap (string name, void delegate () block)
{
	trap(name, cast (void delegate (string)) block);
}

private:
	void delegate (string)[][int] _callbacks;

	extern (C) void signalHandler (int signal)
	{
		foreach (callback; _callbacks[signal]) {
			callback(signal.toName());
		}
	}

	pure int toSignal (string name)
	{
		name = name.toUpper();

		if (name.startsWith("SIG")) {
			name = name[3 .. $];
		}

		switch (name) {
			case "ABRT": return SIGABRT;
			case "FPE":  return SIGFPE;
			case "ILL":  return SIGILL;
			case "INT":  return SIGINT;
			case "SEGV": return SIGSEGV;
			case "TERM": return SIGTERM;

			version (Posix) {
				case "ALRM": return SIGALRM;
				case "BUS":  return SIGBUS;
				case "CHLD": return SIGCHLD;
				case "CONT": return SIGCONT;
				case "HUP":  return SIGHUP;
				case "PIPE": return SIGPIPE;
				case "QUIT": return SIGQUIT;
				case "STOP": return SIGSTOP;
				case "TSTP": return SIGTSTP;
				case "TTIN": return SIGTTIN;
				case "TTOU": return SIGTTOU;
				case "USR1": return SIGUSR1;
				case "USR2": return SIGUSR2;
				case "URG":  return SIGURG;
			}

			default: return 0;
		}
	}

	pure string toName (int sig)
	{
		switch (sig) {
			case SIGABRT: return "ABRT";
			case SIGFPE:  return "FPE";
			case SIGILL:  return "ILL";
			case SIGINT:  return "INT";
			case SIGSEGV: return "SEGV";
			case SIGTERM: return "TERM";

			version (Posix) {
				case SIGALRM: return "ALRM";
				case SIGBUS:  return "BUS";
				case SIGCHLD: return "CHLD";
				case SIGCONT: return "CONT";
				case SIGHUP:  return "HUP";
				case SIGPIPE: return "PIPE";
				case SIGQUIT: return "QUIT";
				case SIGSTOP: return "STOP";
				case SIGTSTP: return "TSTP";
				case SIGTTIN: return "TTIN";
				case SIGTTOU: return "TTOU";
				case SIGUSR1: return "USR1";
				case SIGUSR2: return "USR2";
				case SIGURG:  return "URG";
			}

			default: return "UNKNOWN";
		}
	}
