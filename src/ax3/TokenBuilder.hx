package ax3;

import ax3.Token;

class TokenBuilder {
	public static function mkTokenWithSpaces(kind:TokenKind, text:String):Token {
		return new Token(0, kind, text, [new Trivia(TrWhitespace, " ")], [new Trivia(TrWhitespace, " ")]);
	}

	public static inline function mkEqualsEqualsToken():Token {
		return mkTokenWithSpaces(TkEqualsEquals, "==");
	}

	public static inline function mkNotEqualsToken():Token {
		return mkTokenWithSpaces(TkExclamationEquals, "!=");
	}
}
