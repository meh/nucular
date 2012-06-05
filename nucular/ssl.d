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

module nucular.ssl;

import std.exception;
import std.file;
import std.string;
import std.conv;
import std.array;

import deimos.openssl.ssl;
import deimos.openssl.evp;
import deimos.openssl.err;

import nucular.connection : Connection;
import nucular.queue;

string DefaultMaterials = `
	-----BEGIN PRIVATE KEY-----
	MIICeAIBADANBgkqhkiG9w0BAQEFAASCAmIwggJeAgEAAoGBALl9RJdO31FCzk8l
	0ASC40o/9QnBVV0Amz8bIPyVDsEGymAtAp/hc4JJIypNF4fMLMf5ns1/VWoyGSbt
	xwHp4Z6XWbQGwafJ7l6FauzjFU0hPXPNmjsW/wrxtvULFk4KJYfeNG2juob8eT4b
	pYVqOrdAjpL7+PjoLrsZ0c/t795vAgMBAAECgYAYxgtQLh+TadnGJmW3BIg41Xvz
	tpehGUCi2Au60GmtDCwhVkGgeusDfqMstikrYPCmMMet6JDO4ywKz/0hW0xfuLil
	Rveji6IQayS57rrQWjzdE201emVrmInt8d2swRLvJR6AVxHuExLaQbx96SXh2J/v
	RmsN1/+UkSyek3H7SQJBAOpJoPWiB2BcyfR+Pu+Afmva9mYkpkxC4H7w3bjwBE5x
	OAO/4hCxBRmzd0NI94IOTTzfwzE8A4Jw+k1mUBt/NkMCQQDKrevUHdPZoDPPglWz
	GUtjMarRAPnLNLj//iTH0mOfz8w9YRyYFsgFMtRejf4FiyzJDH49nHUWu3wLtIli
	SlJlAkEAu//7PkAXpTawBBYuEGfOimO5JvuvyjA8DwDfGqDXA88MQM3/7J7v1dDS
	Gdb6bY1mYzu3WNGsi0Z3RBaen4H0GwJBALwDqOAFp2+bcFSQCGXzEf77pQTrTc3W
	o8M9g+sl3Srz/ff2bSsc/wHrjBwGxl1oJOyAPV90Ex46X7EQEd3vKg0CQQCNthd7
	6l7vyDagi3xqpuPpWssMUjPjlh0ePAll41fKGzXkwgAdprdSCAcEuw/a8hVorf/I
	uWhi/Rf5RUVFKfW5
	-----END PRIVATE KEY-----

	-----BEGIN CERTIFICATE-----
	MIIDJjCCAo+gAwIBAgIJAPHiZRV3GNIxMA0GCSqGSIb3DQEBBQUAMIGrMQswCQYD
	VQQGEwJVUzEQMA4GA1UECAwHVW5rbm93bjEUMBIGA1UEBwwLU3ByaW5nZmllbGQx
	KDAmBgNVBAoMH1NwcmluZ2ZpZWxkIE51Y2xlYXIgUG93ZXIgUGxhbnQxDzANBgNV
	BAsMBlNhZmV0eTEWMBQGA1UEAwwNSG9tZXIgU2ltcHNvbjEhMB8GCSqGSIb3DQEJ
	ARYSaG9tZXJAc2ltcHNvbnMub3JnMB4XDTEyMDUzMTEzMDIzM1oXDTMwMDMxODEz
	MDIzM1owgasxCzAJBgNVBAYTAlVTMRAwDgYDVQQIDAdVbmtub3duMRQwEgYDVQQH
	DAtTcHJpbmdmaWVsZDEoMCYGA1UECgwfU3ByaW5nZmllbGQgTnVjbGVhciBQb3dl
	ciBQbGFudDEPMA0GA1UECwwGU2FmZXR5MRYwFAYDVQQDDA1Ib21lciBTaW1wc29u
	MSEwHwYJKoZIhvcNAQkBFhJob21lckBzaW1wc29ucy5vcmcwgZ8wDQYJKoZIhvcN
	AQEBBQADgY0AMIGJAoGBALl9RJdO31FCzk8l0ASC40o/9QnBVV0Amz8bIPyVDsEG
	ymAtAp/hc4JJIypNF4fMLMf5ns1/VWoyGSbtxwHp4Z6XWbQGwafJ7l6FauzjFU0h
	PXPNmjsW/wrxtvULFk4KJYfeNG2juob8eT4bpYVqOrdAjpL7+PjoLrsZ0c/t795v
	AgMBAAGjUDBOMB0GA1UdDgQWBBSFqwkah3xo/uPm/KJREV/cbu7+QTAfBgNVHSME
	GDAWgBSFqwkah3xo/uPm/KJREV/cbu7+QTAMBgNVHRMEBTADAQH/MA0GCSqGSIb3
	DQEBBQUAA4GBAHPLTHCOVsyg4fP3vn/GWwsxmymSaIrt/4qDrJpsLxsKqTxOSXfR
	7sQ7lbio6O+sMksHDjdCsXdS/cSa+TzyFXZMsTsXPy1iqgHvLrB02zDijGaWTO0N
	ADXMtCmF3qcnkf9LK070ztJGliYDKlEvHtKTtofm1ls8XCxu6fz1v0Nu
	-----END CERTIFICATE-----
`.outdent();

PrivateKey  DefaultPrivateKey;
Certificate DefaultCertificate;

static this ()
{
	SSL_library_init();
	OpenSSL_add_ssl_algorithms();
	OpenSSL_add_all_algorithms();
	SSL_load_error_strings();
	ERR_load_crypto_strings();

	DefaultPrivateKey  = new PrivateKey(DefaultMaterials);
	DefaultCertificate = new Certificate(DefaultMaterials);
}

class Errors : Error
{
	this (string msg = null, string file = __FILE__, size_t line = __LINE__)
	{
		BIO*     bio = BIO_new(BIO_s_mem());
		BUF_MEM* buffer;

		ERR_print_errors(bio);
		BIO_write(bio, "\0".ptr, 1);

		BIO_get_mem_ptr(bio, &buffer);

		super(buffer.data.to!string, file, line);

		BIO_free(bio);
	}
}

enum Version
{
	All,
	SSLv2,
	SSLv3,
	TLSv1,
}

class PrivateKey
{
	this (EVP_PKEY* value)
	{
		assert(value);

		_internal = value;
	}

	this (string source, string password = null)
	{
		BIO*      bio;
		EVP_PKEY* key;

		if (exists(source)) {
			bio = BIO_new_file(source.toStringz(), "r".toStringz());
		}
		else {
			bio = BIO_new_mem_buf(cast (void*) source.ptr, source.length.to!int);
		}

		if (password) {
			key = PEM_read_bio_PrivateKey(bio, &key, &_password_callback, cast (void*) password.toStringz());
		}
		else {
			key = PEM_read_bio_PrivateKey(bio, &key, null, null);
		}

		BIO_free(bio);

		enforceEx!Errors(key);

		this(key);
	}

	~this ()
	{
		EVP_PKEY_free(_internal);
	}

	@property native ()
	{
		return _internal;
	}

private:
	EVP_PKEY* _internal;
}

class Certificate
{
	this (X509* value)
	{
		assert(value);

		_internal = value;
	}

	this (string source, string password = null)
	{
		BIO*  bio;
		X509* cert;

		if (exists(source)) {
			bio = BIO_new_file(source.toStringz(), "r");
		}
		else {
			bio = BIO_new_mem_buf(cast (void*) source.ptr, source.length.to!int);
		}

		if (password) {
			cert = PEM_read_bio_X509(bio, &cert, &_password_callback, cast (void*) password.toStringz());
		}
		else {
			cert = PEM_read_bio_X509(bio, &cert, null, null);
		}

		BIO_free(bio);

		enforceEx!Errors(cert);

		this(cert);
	}

	~this ()
	{
		X509_free(_internal);
	}

	@property native ()
	{
		return _internal;
	}

	override string toString ()
	{
		BIO*     bio = BIO_new(BIO_s_mem());
		BUF_MEM* buffer;

		PEM_write_bio_X509(bio, native);
		BIO_write(bio,"\0".ptr, 1);

		BIO_get_mem_ptr(bio, &buffer);

		scope (exit) {
			BIO_free(bio);
		}

		return buffer.data.to!string;
	}

private:
	X509* _internal;
}

class Context
{
	this (bool server, Version ver = Version.All)
	{
		this(server, DefaultPrivateKey, DefaultCertificate, ver);
	}

	this (bool server, PrivateKey privkey, Certificate certchain, Version ver = Version.All)
	{
		_server      = server;
		_private_key = privkey;
		_certificate = certchain;

		final switch (ver) {
			case Version.All:   _internal = SSL_CTX_new(isServer ? SSLv23_server_method() : SSLv23_client_method()); break;
			case Version.SSLv2: _internal = SSL_CTX_new(isServer ? SSLv2_server_method()  : SSLv2_client_method()); break;
			case Version.SSLv3: _internal = SSL_CTX_new(isServer ? SSLv3_server_method()  : SSLv3_client_method()); break;
			case Version.TLSv1: _internal = SSL_CTX_new(isServer ? TLSv1_server_method()  : TLSv1_client_method()); break;
		}

		enforce(_internal, "no SSL context");

		SSL_CTX_set_options(native, SSL_OP_ALL);

		if (SSL_CTX_use_PrivateKey(native, privkey.native) <= 0) {
			throw new Errors;
		}

		if (SSL_CTX_use_certificate(native, certchain.native) <= 0) {
			throw new Errors;
		}

		if (isServer) {
			SSL_CTX_sess_set_cache_size(native, 128);
			SSL_CTX_set_session_id_context(native, cast (ubyte*) "nucular".ptr, 7);
		}
		
		ciphers = "ALL:!ADH:!LOW:!EXP:!DES-CBC3-SHA:@STRENGTH";
	}

	~this ()
	{
		SSL_CTX_free(native);
	}

	@property ciphers (string value)
	{
		SSL_CTX_set_cipher_list(native, value.toStringz());
	}

	@property isServer ()
	{
		return _server;
	}

	@property privateKey ()
	{
		return _private_key;
	}

	@property certificate ()
	{
		return _certificate;
	}

	@property native ()
	{
		return _internal;
	}

private:
	bool _server;

	SSL_CTX* _internal;

	PrivateKey  _private_key;
	Certificate _certificate;
}

class Box
{
	enum Result {
		Fatal = -3,
		Interrupted,
		Failed,
		Worked
	}

	this (bool server, bool verify, Connection connection, Version ver = Version.All)
	{
		this(server, DefaultPrivateKey, DefaultCertificate, verify, connection, ver);
	}

	this (bool server, PrivateKey privkey, Certificate certchain, bool verify, Connection connection, Version ver = Version.All)
	{
		_context = new Context(server, privkey, certchain, ver);

		_read  = BIO_new(BIO_s_mem());
		_write = BIO_new(BIO_s_mem());

		_internal = SSL_new(_context.native);

		SSL_set_bio(native, _read, _write);
		SSL_set_ex_data(native, 0, cast (void*) connection);

		if (verify) {
			SSL_set_verify(native, SSL_VERIFY_PEER | SSL_VERIFY_CLIENT_ONCE, &_verify_callback);
		}

		if (!isServer) {
			SSL_connect(native);
		}
	}

	~this ()
	{
		if (native) {
			if (SSL_get_shutdown(native) & SSL_RECEIVED_SHUTDOWN) {
				SSL_shutdown(native);
			}
			else {
				SSL_clear(native);
			}

			SSL_free(native);
		}
	}

	bool putCiphertext (ubyte[] data)
	{
		return BIO_write(_read, data.ptr, data.length.to!int) == data.length;
	}

	int getPlaintext (ref ubyte[] data)
	{
		if (!SSL_is_init_finished(native)) {
			int error = isServer ? SSL_accept(native) : SSL_connect(native);

			if (error < 0) {
				if (SSL_get_error(native, error) != SSL_ERROR_WANT_READ) {
					return (SSL_get_error(native, error) == SSL_ERROR_SSL) ?
						Result.Fatal : Result.Failed;
				}
				else {
					return 0;
				}
			}

			_handshake_completed = true;
		}

		if (!SSL_is_init_finished(native)) {
			return Result.Interrupted;
		}

		int n = SSL_read(native, data.ptr, data.length.to!int);

		if (n >= 0) {
			return n;
		}
		else {
			if (SSL_get_error(native, n) == SSL_ERROR_WANT_READ) {
				return 0;
			}
			else {
				return Result.Failed;
			}
		}
	}

	Result putPlaintext (ubyte[] data)
	{
		_outbound.pushBack(data);

		return putPlaintext();
	}

	Result putPlaintext ()
	{
		if (!SSL_is_init_finished(native)) {
			return Result.Failed;
		}

		bool fatal  = false;
		bool worked = false;

		while (!_outbound.empty) {
			ubyte[] current = _outbound.front;
			int     n       = SSL_write(native, cast (void*) current.ptr, current.length.to!int);

			if (n > 0) {
				worked = true;
				_outbound.popFront();
			}
			else {
				int error = SSL_get_error(native, n);

				if (error != SSL_ERROR_WANT_READ && error != SSL_ERROR_WANT_WRITE) {
					fatal = true;
				}

				break;
			}
		}

		if (worked) {
			return Result.Worked;
		}
		else if (fatal) {
			return Result.Fatal;
		}
		else {
			return Result.Failed;
		}
	}

	int getCiphertext (ref ubyte[] buffer)
	{
		int result = 0;

		if (!_unget.empty) {
			if (_unget.length >= buffer.length) {
				buffer[0 .. $] = _unget[0 .. buffer.length];
				_unget         = _unget.length > buffer.length ? _unget[buffer.length .. $] : null;

				result = buffer.length.to!int;
			}
			else {
				buffer[0 .. _unget.length] = _unget[];

				result  = _unget.length.to!int;
				result += BIO_read(_write, buffer.ptr + result, (buffer.length - result).to!int);
			}
		}
		else {
			result = BIO_read(_write, buffer.ptr, buffer.length.to!int);
		}

		return result;
	}

	void ungetCiphertext (ubyte[] buffer)
	{
		_unget ~= buffer;
	}

	@property canGetCiphertext ()
	{
		return cast (bool) BIO_pending(_write);
	}

	@property cipher ()
	{
		char[]      result;
		const char* name = SSL_get_cipher(native);

		result[0 .. $] = name[0 .. strlen(name)];

		return cast (string) result;
	}

	@property context ()
	{
		return _context;
	}

	@property isServer ()
	{
		return context.isServer;
	}

	@property certificate ()
	{
		return context.certificate;
	}

	@property privateKey ()
	{
		return context.privateKey;
	}

	@property peerCertificate ()
	{
		X509* cert;

		if (native) {
			cert = SSL_get_peer_certificate(native);
		}

		if (cert) {
			return new Certificate(cert);
		}

		return null;
	}

	@property isHandshakeCompleted ()
	{
		return _handshake_completed;
	}

	@property connection ()
	{
		return cast (Connection) SSL_get_ex_data(native, 0);
	}

	@property native ()
	{
		return _internal;
	}

private:
	SSL*    _internal;
	Context _context;

	BIO* _read;
	BIO* _write;

	bool _handshake_completed;

	Queue!(ubyte[]) _outbound;
	ubyte[]         _unget;
}

private:
	import core.stdc.string;

	extern (C) int _password_callback (char* buf, int bufsize, int rwflag, void* userdata)
	{
		char* password = cast (char*) userdata;

		strcpy(buf, password);

		return strlen(password).to!int;
	}

	extern (C) int _verify_callback (int preverify_ok, X509_STORE_CTX* ctx)
	{
		int        result;
		X509*      cert       = X509_STORE_CTX_get_current_cert(ctx);
		SSL*       ssl        = cast (SSL*) X509_STORE_CTX_get_ex_data(ctx, SSL_get_ex_data_X509_STORE_CTX_idx());
		Connection connection = cast (Connection) SSL_get_ex_data(ssl, 0);

		return cast (int) connection.verify(new Certificate(cert));
	}
