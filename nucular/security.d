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

module nucular.security;

import std.socket : Address, InternetAddress, Internet6Address;
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
	6l7vyDagi3xqpuPpWssMUjPjlh0ePAny41fKGzXkwgAdprdSCAcEuw/a8hVorf/I
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

class Errors : Exception
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

enum Type
{
	Any,
	SSLv2,
	SSLv3,
	TLSv1,
	DTLSv1
}

class PrivateKey
{
	this (EVP_PKEY* value)
	{
		assert(value);

		_internal_evp = value;
	}

	this (RSA* value)
	{
		assert(value);

		_internal_rsa = value;
	}

	this (string source, string password = null)
	{
		BIO* bio;

		if (exists(source)) {
			bio = BIO_new_file(source.toStringz(), "r".toStringz());
		}
		else {
			bio = BIO_new_mem_buf(cast (void*) source.ptr, source.length.to!int);
		}

		assert(bio);

		scope (exit) {
			BIO_free(bio);
		}

		if (password) {
			_internal_evp = PEM_read_bio_PrivateKey(bio, null, &_password_callback, cast (void*) password.toStringz());
		}
		else {
			_internal_evp = PEM_read_bio_PrivateKey(bio, null, null, null);
		}

		if (!isEVP) {
			if (password) {
				_internal_rsa = PEM_read_bio_RSAPrivateKey(bio, null, &_password_callback, cast (void*) password.toStringz());
			}
			else {
				_internal_rsa = PEM_read_bio_RSAPrivateKey(bio, null, null, null);
			}

			if (!isRSA) {
				if (password) {
					_internal_dsa = PEM_read_bio_DSAPrivateKey(bio, null, &_password_callback, cast (void*) password.toStringz());
				}
				else {
					_internal_dsa = PEM_read_bio_DSAPrivateKey(bio, null, null, null);
				}

				if (!isDSA) {
					throw new Errors;
				}
			}
		}
	}

	~this ()
	{
		if (_internal_evp) {
			EVP_PKEY_free(_internal_evp);
		}

		if (_internal_rsa) {
			RSA_free(_internal_rsa);
		}

		if (_internal_dsa) {
			DSA_free(_internal_dsa);
		}
	}

	@property native(T : EVP_PKEY) ()
	{
		return _internal_evp;
	}

	@property native(T : RSA) ()
	{
		return _internal_rsa;
	}

	@property native(T : DSA) ()
	{
		return _internal_dsa;
	}

	@property isEVP ()
	{
		return _internal_evp !is null;
	}

	@property isRSA ()
	{
		return _internal_rsa !is null;
	}

	@property isDSA ()
	{
		return _internal_dsa !is null;
	}

private:
	EVP_PKEY* _internal_evp;
	RSA*      _internal_rsa;
	DSA*      _internal_dsa;
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
	this (Type type = Type.Any)
	{
		this(DefaultPrivateKey, DefaultCertificate, type);
	}

	this (PrivateKey key, Type type = Type.Any)
	{
		final switch (type) {
			case Type.Any:    _internal = SSL_CTX_new(SSLv23_method()); break;
			case Type.SSLv2:  _internal = SSL_CTX_new(SSLv2_method()); break;
			case Type.SSLv3:  _internal = SSL_CTX_new(SSLv3_method()); break;
			case Type.TLSv1:  _internal = SSL_CTX_new(TLSv1_method()); break;
			case Type.DTLSv1: _internal = SSL_CTX_new(DTLSv1_method()); break;
		}

		enforceEx!Errors(native);

		_private_key = key;

		SSL_CTX_set_options(native, SSL_OP_ALL);
		SSL_CTX_set_mode(native, SSL_MODE_RELEASE_BUFFERS);

		if (privateKey.isEVP) {
			enforceEx!Errors(SSL_CTX_use_PrivateKey(native, privateKey.native!EVP_PKEY));
		}
		else if (privateKey.isRSA) {
			enforceEx!Errors(SSL_CTX_use_RSAPrivateKey(native, privateKey.native!RSA));
		}
		else {
			assert(0);
		}

		SSL_CTX_set_session_id_context(native, cast (ubyte*) "nucular".ptr, 7);

		ciphers = "ALL:!ADH:!LOW:!EXP:!DES-CBC3-SHA:@STRENGTH";
	}

	this (string key, Type type = Type.Any)
	{
		this(new PrivateKey(key), type);
	}

	this (PrivateKey key, Certificate cert, Type type = Type.Any)
	{
		this(key, type);

		_certificate = cert;

		enforceEx!Errors(SSL_CTX_use_certificate(native, certificate.native));
	}

	this (string key, string cert, Type type = Type.Any)
	{
		this(new PrivateKey(key), new Certificate(cert), type);
	}

	~this ()
	{
		if (native) {
			SSL_CTX_free(native);
		}
	}

	@property ciphers (string value)
	{
		SSL_CTX_set_cipher_list(native, value.toStringz());
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
	SSL_CTX* _internal;

	PrivateKey  _private_key;
	Certificate _certificate;
}

private template SecureAddressConstructor()
{
	private static string constructorsFor(string signature)
	{
		string parameters; // = signature.split(",").map!(`a[a.lastIndexOf(" ") .. $]`).join(", ");

		foreach (piece; signature.split(",")) {
			parameters ~= ", " ~ piece[piece.lastIndexOf(" ") .. $];
		}

		parameters = parameters[2 .. $];

		return
			`this (` ~ signature ~ `, bool verify = false) {
				super(` ~ parameters ~`);

				set(verify);
			}` ~

			`this (` ~ signature ~ `, Context context, bool verify = false) {
				super(` ~ parameters ~`);

				set(context, verify);
			}` ~

			`this (` ~ signature ~ `, Type type, bool verify = false) {
				super(` ~ parameters ~`);

				set(type, verify);
			}` ~

			`this (` ~ signature ~ `, PrivateKey key, bool verify = false) {
				super(` ~ parameters ~`);

				set(key, verify);
			}` ~

			`this (` ~ signature ~ `, string key, bool verify = false) {
				super(` ~ parameters ~`);

				set(key, verify);
			}` ~

			`this (` ~ signature ~ `, PrivateKey key, Certificate certificate, bool verify = false) {
				super(` ~ parameters ~`);

				set(key, certificate, verify);
			}` ~

			`this (` ~ signature ~ `, string key, string certificate, bool verify = false) {
				super(` ~ parameters ~`);

				set(key, certificate, verify);
			}` ~

			`this (` ~ signature ~ `, Type type, PrivateKey key, bool verify = false) {
				super(` ~ parameters ~`);

				set(type, key, verify);
			}` ~

			`this (` ~ signature ~ `, Type type, string key, bool verify = false) {
				super(` ~ parameters ~`);

				set(type, key, verify);
			}` ~

			`this (` ~ signature ~ `, Type type, PrivateKey key, Certificate certificate, bool verify = false) {
				super(` ~ parameters ~`);

				set(type, key, certificate, verify);
			}` ~

			`this (` ~ signature ~ `, Type type, string key, string certificate, bool verify = false) {
				super(` ~ parameters ~`);

				set(type, key, certificate, verify);
			}`;
	}

	void set (bool verify)
	{
		_context = new Context();
		_verify  = verify;
	}

	void set (Context context, bool verify)
	{
		_context = context;
		_verify  = verify;
	}

	void set (Type type, bool verify)
	{
		_context = new Context(type);
		_verify  = verify;
	}

	void set (PrivateKey key, bool verify)
	{
		_context = new Context(key);
		_verify  = verify;
	}

	void set (string key, bool verify)
	{
		_context = new Context(new PrivateKey(key));
		_verify  = verify;
	}

	void set (PrivateKey key, Certificate certificate, bool verify)
	{
		_context = new Context(key, certificate);
		_verify  = verify;
	}

	void set (string key, string certificate, bool verify)
	{
		_context = new Context(new PrivateKey(key), new Certificate(certificate));
		_verify  = verify;
	}

	void set (Type type, PrivateKey key, bool verify)
	{
		_context = new Context(key, type);
		_verify  = verify;
	}

	void set (Type type, string key, bool verify)
	{
		_context = new Context(new PrivateKey(key), type);
		_verify  = verify;
	}

	void set (Type type, PrivateKey key, Certificate certificate, bool verify)
	{
		_context = new Context(key, certificate, type);
		_verify  = verify;
	}

	void set (Type type, string key, string certificate, bool verify)
	{
		_context = new Context(new PrivateKey(key), new Certificate(certificate), type);
		_verify  = verify;
	}

	@property context ()
	{
		return _context;
	}

	@property verify ()
	{
		return _verify;
	}

private:
	Context _context;
	bool    _verify;
}

class SecureInternetAddress : InternetAddress
{
	mixin SecureAddressConstructor;

	mixin(constructorsFor("in char[] addr, ushort port"));
	mixin(constructorsFor("uint addr, ushort port"));
	mixin(constructorsFor("ushort port"));
}

class SecureInternet6Address : Internet6Address
{
	mixin SecureAddressConstructor;

	mixin(constructorsFor("in char[] node"));
	mixin(constructorsFor("in char[] node, in char[] service"));
	mixin(constructorsFor("in char[] node, ushort port"));
	mixin(constructorsFor("ubyte[16] addr, ushort port"));
	mixin(constructorsFor("ushort port"));
}

class Box
{
	enum Result
	{
		Fatal = -3,
		Interrupted,
		Failed,
		Worked
	}

	this (bool server, bool verify, Connection connection, Type type = Type.Any)
	{
		this(server, DefaultPrivateKey, DefaultCertificate, verify, connection, type);
	}

	this (bool server, PrivateKey key, bool verify, Connection connection, Type type = Type.Any)
	{
		this(server, new Context(key, type), verify, connection);
	}

	this (bool server, string key, bool verify, Connection connection, Type type = Type.Any)
	{
		this(server, new Context(key, type), verify, connection);
	}

	this (bool server, PrivateKey key, Certificate cert, bool verify, Connection connection, Type type = Type.Any)
	{
		this(server, new Context(key, cert, type), verify, connection);
	}

	this (bool server, string key, string cert, bool verify, Connection connection, Type type = Type.Any)
	{
		this(server, new Context(key, cert, type), verify, connection);
	}

	this (bool server, Context context, bool verify, Connection connection)
	{
		_server  = server;
		_context = context;

		_read  = BIO_new(BIO_s_mem());
		_write = BIO_new(BIO_s_mem());

		_internal = SSL_new(_context.native);

		SSL_set_bio(native, _read, _write);
		SSL_set_ex_data(native, 0, cast (void*) connection);

		if (verify) {
			SSL_set_verify(native, SSL_VERIFY_PEER | SSL_VERIFY_CLIENT_ONCE, &_verify_callback);
		}

		if (!isServer) {
			connect();
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

	int connect ()
	{
		return SSL_connect(native);
	}

	int accept ()
	{
		return SSL_accept(native);
	}

	bool putCiphertext (ubyte[] data)
	{
		return BIO_write(_read, data.ptr, data.length.to!int) == data.length;
	}

	int getPlaintext (ref ubyte[] data)
	{
		if (!SSL_is_init_finished(native)) {
			int error = isServer ? accept() : connect();

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
		return _server;
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
		if (native) {
			if (auto cert = SSL_get_peer_certificate(native)) {
				return new Certificate(cert);
			}
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

	bool _server;
	bool _handshake_completed;

	Queue!(ubyte[]) _outbound;
	ubyte[]         _unget;
}

private extern (C):
	import core.stdc.string;

	int _password_callback (char* buf, int bufsize, int rwflag, void* userdata)
	{
		char* password = cast (char*) userdata;
		int   length   = strlen(password).to!int;

		strncpy(buf, password, bufsize - 1);

		return length >= bufsize ? bufsize - 1 : length;
	}

	int _verify_callback (int preverify_ok, X509_STORE_CTX* ctx)
	{
		int        result;
		X509*      cert       = X509_STORE_CTX_get_current_cert(ctx);
		SSL*       ssl        = cast (SSL*) X509_STORE_CTX_get_ex_data(ctx, SSL_get_ex_data_X509_STORE_CTX_idx());
		Connection connection = cast (Connection) SSL_get_ex_data(ssl, 0);

		return cast (int) connection.verify(new Certificate(cert));
	}
