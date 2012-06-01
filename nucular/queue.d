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
	@property empty ()
	{
		return !_head;
	}

	@property front ()
	{
		return _head.data;
	}

	void pushBack (T data)
	{
		auto node = Node(data, null, _tail);

		_tail.next = &node;
		_tail      = &node;
	}

	void popFront ()
	{
		auto node = _head;

		_head          = _head.next;
		_head.previous = null;
	}

private:
	struct Node
	{
		T data;

		Node* next;
		Node* previous;

		this (T a, Node* b, Node* c)
		{
			data     = a;
			next     = b;
			previous = c;
		}
	}

private:
	Node* _head;
	Node* _tail;
}
