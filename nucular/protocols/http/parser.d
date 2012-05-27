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
	QuotedPair   <- '\\' CHAR

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
	auto p = MessageHeader.parse("lol: wut");

	assert(p.children[0].capture[0] == "lol");
	assert(p.children[1].capture[0] == "wut");
}
