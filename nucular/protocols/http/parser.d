/*
 *            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
 *                    Version 2, December 2004
 *
 *            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
 *   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
 *
 *  0. You just DO WHAT THE FUCK YOU WANT TO.
 **/

module nucular.protocols.http.parser;

import pegged.grammar;

mixin(grammar(`
HTTP:
	Version <- :"HTTP" :Slash ~(DIGIT+ '.' DIGIT+)

	MessageHeader <- FieldName :':' FieldValue
	FieldName     <~ Token
	FieldValue    <~ (:LWS / FieldContent)*
	FieldContent  <~ OCTET+

	# Basic Rules
	Token        <~ (!(CTL / Separators) CHAR)+
	Separators   <- '(' / ')' / '<' / '>' / '@' / ',' / ';' / ':' / '\\' / '[' / ']' / '?' / '=' / '{' / '}'
	Comment      <: '(' (CText / QuotedPair / Comment) ')'
	CText        <- !('(' / ')') TEXT
	QuotedString <- DoubleQuote (QDText / QuotedPair) DoubleQuote
	QDText       <- !DoubleQuote TEXT
	QuotedPair   <- BackSlash CHAR

	OCTET   <- .
	CHAR    <- [\x00-\x7f]
	UPALPHA <- [A-Z]
	LOALPHA <- [a-z]
	ALPHA   <- UPALPHA / LOALPHA
	DIGIT   <- [0-9]
	CTL     <- '[\x00-\x1f]'
	CR      <- '\n'
	LF      <- '\r'
	SP      <- ' '
	HT      <- '\x09'

	CRLF <~ CR LF
	LWS  <~ CRLF? (SP / HT)+
	TEXT <~ !CTL OCTET
	HEX  <~ [A-F] / [a-f] / DIGIT
`));

unittest {
	ParseTree p;

	p = HTTP.Version.parse("HTTP/1.1");
	assert(p.capture[0] == "1.1");

	p = HTTP.MessageHeader.parse("lol: wut");
	assert(p.capture[0] == "lol");
	assert(p.capture[1] == "wut");
}
