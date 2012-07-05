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

module nucular.queue;

struct Queue(T)
{
	void pushBack (T data)
	{
		auto node = new Node(data, null);

		if (_head is null) {
			_head = _tail = node;
		}
		else {
			_tail.next = node;
			_tail      = node;
		}

		_length++;
	}

	void popFront ()
	{
		assert(_head, "Attempting to pop front of an empty Queue of " ~ T.stringof);

		_head = _head.next;

		if (_head is null) {
			_tail = null;
		}

		_length--;
	}

	@property front ()
	{
		assert(_head, "Attempting to fetch front of an empty Queue of " ~ T.stringof);

		return _head.data;
	}

	@property empty ()
	{
		return !_head;
	}

	@property length ()
	{
		return _length;
	}

private:
	struct Node
	{
		T     data;
		Node* next;

		this (T a, Node* b)
		{
			data = a;
			next = b;
		}
	}

private:
	Node* _head;
	Node* _tail;

	size_t _length;
}
