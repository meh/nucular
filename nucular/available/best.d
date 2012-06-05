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

version (poll) {
	public import nucular.available.poll;
}
version (epoll) {
	public import nucular.available.epoll;
}
else version (kqueue) {
	public import nucular.available.kqueue;
}
else version (iocompletion) {
	public import nucular.available.iocompletion;
}
else version (select) {
	public import nucular.available.select;
}
else {
	version (Windows) {
		version = iocompletion;

		public import nucular.available.iocompletion;
	}
	else version (FreeBSD) {
		version = kqeue;

		public import nucular.available.kqueue;
	}
	else version (OpenBSD) {
		version = kqueue;

		public import nucular.available.kqueue;
	}
	else version (linux) {
		version = epoll;

		public import nucular.available.epoll;
	}
	else version (Posix) {
		version = poll;

		public import nucular.available.poll;
	}
	else {
		version = select;

		public import nucular.available.select;
	}
}
