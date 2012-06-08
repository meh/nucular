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

module nucular.threadpool;

import std.exception;
import std.container;
import std.algorithm;
import std.array;

import core.thread;
import core.sync.mutex;
import core.sync.condition;
import std.parallelism;

import nucular.queue;

class ThreadPool
{
	struct Work
	{
		void delegate (void*) block;
		void*                 data;

		this (void delegate (void*) b)
		{
			block = b;
		}

		this (void delegate (void*) b, void* d)
		{
			block = b;
			data  = d;
		}
	}

	this (int min = 20)
	{
		this(min, min);
	}

	this (int min, int max)
	{
		_mutex     = new Mutex;
		_condition = new Condition(_mutex);

		resize(min, max);

		synchronized (_mutex) {
			for (int i = 0; i < min; i++) {
				_spawnWorker();
			}
		}
	}

	~this ()
	{
		shutdown();
	}

	void resize (int min, int max = 0)
	{
		if (max == 0) {
			max = min;
		}

		enforce(max >= min, "the max can't be smaller than the min");

		_min = min;
		_max = max;

		trim(true);
	}

	@property defaultBlock(T) (T block)
	{
		_default_block = cast (void delegate (T)) block;
	}

	@property autoTrim (bool what)
	{
		_auto_trim = what;
	}

	@property backlog ()
	{
		synchronized (_mutex) {
			return _todo.length;
		}
	}

	void trim (bool force = false)
	{
		synchronized (_mutex) {
			if ((force || _waiting > 0) && _spawned - _trim_requests > _min) {
				_trim_requests--;

				_condition.notify();
			}
		}
	}

	void shutdown ()
	{
		synchronized (_mutex) {
			if (_shutdown) {
				return;
			}

			_shutdown = true;

			_condition.notifyAll();
		}

		while (!_threads.empty) {
			_threads.front.join();
		}
	}

	void process ()
	{
		enforce(_default_block, "there's no default callback");

		process(cast (void delegate ()) _default_block);
	}

	void process (void delegate () block)
	{
		synchronized (_mutex) {
			_todo.pushBack(new Work(cast (void delegate (void*)) block));

			_spawnWorker();
			_condition.notify();
		}
	}

	void process (AbstractTask task)
	{
		process({
			task.job();
		});
	}

	void processWith(T) (T data)
	{
		enforce(_default_block, "there's no default callback");

		processWith(data, _default_block);
	}

	void processWith(T) (T data, void delegate (T) block)
	{
		synchronized (_mutex) {
			_todo.pushBack(new Work(cast (void delegate (void*)) block, cast (void*) data));

			_spawnWorker();
			_condition.notify();
		}
	}

	ThreadPool opShl(T) (T rhs)
	{
		processWith(rhs);

		return this;
	}

private:
	// must be called while locked
	void _spawnWorker ()
	{
		if (_waiting != 0 || _spawned >= _max) {
			return;
		}

		_spawned++;

		Thread thread = null;
		
		thread = new Thread({
			while (true) {
				Work* work;
				bool  keep_going = true;

				synchronized (_mutex) {
					while (_todo.empty) {
						if (_trim_requests > 0) {
							_trim_requests--;

							keep_going = false;

							break;
						}

						if (_shutdown) {
							keep_going = false;

							break;
						}

						_waiting++;
						_condition.wait();
						_waiting--;

						if (_shutdown) {
							keep_going = false;

							break;
						}
					}

					if (keep_going) {
						work = _todo.front;

						_todo.popFront();
					}
				}

				if (!keep_going) {
					break;
				}

				work.block(work.data);

				if (_auto_trim && _spawned > _min) {
					trim();
				}
			}

			synchronized (_mutex) {
				_spawned--;
				_threads.remove(_threads.countUntil!(a => a != thread));
			}
		});

		_threads ~= thread;

		thread.isDaemon(true);
		thread.start();
	}

private:
	int _min;
	int _max;

	int  _waiting;
	int  _spawned;
	int  _trim_requests;
	bool _auto_trim;
	bool _shutdown;

	Mutex     _mutex;
	Condition _condition;

	Thread[]              _threads;
	Queue!(Work*)         _todo;
	void delegate (void*) _default_block;
}
