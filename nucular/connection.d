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

module nucular.connection;

import nucular.descriptor;

class Connection {
	this (Descriptor descriptor) {
		_descriptor = descriptor;
	}

	void send_data (string data) {

	}

	void close_connection (bool after_writing = false) {
		if (after_writing) {

		}
	}

	void close_connection_after_writing () {
		close_connection(true);
	}

private:
	Descriptor _descriptor;
}
