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

public import nucular.selector.base : Selected;

version (poll) {
	public import nucular.selector.poll;
}
else version (epoll) {
	public import nucular.selector.epoll;
}
else version (kqueue) {
	public import nucular.selector.kqueue;
}
else version (port) {
	public import nucular.selector.port;
}
else version (select) {
	public import nucular.selector.select;
}
else {
	version (FreeBSD) {
		version = kqeue;

		public import nucular.selector.kqueue;
	}
	else version (OpenBSD) {
		version = kqueue;

		public import nucular.selector.kqueue;
	}
	else version (NetBSD) {
		version = kqueue;

		public import nucular.selector.kqueue;
	}
	else version (OSX) {
		version = kqueue;

		public import nucular.selector.kqueue;
	}
	else version (Solaris) {
		version = port;

		public import nucular.selector.port;
	}
	else version (linux) {
		version = epoll;

		public import nucular.selector.epoll;
	}
	else version (Posix) {
		version = poll;

		public import nucular.selector.poll;
	}
	else {
		version = select;

		public import nucular.selector.select;
	}
}
