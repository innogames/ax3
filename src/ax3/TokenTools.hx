package ax3;

import ax3.Token;

class TokenTools {
	public static function containsOnlyWhitespace(tr:Array<Trivia>):Bool {
		for (t in tr) {
			if (t.kind != TrWhitespace) {
				return false;
			}
		}
		return true;
	}

	public static inline function mkIdent(n) return new Token(0, TkIdent, n, [], []);
	public static inline function mkOpenParen() return new Token(0, TkParenOpen, "(", [], []);
	public static inline function mkCloseParen() return new Token(0, TkParenClose, ")", [], []);
	public static inline function mkOpenBracket() return new Token(0, TkBracketOpen, "[", [], []);
	public static inline function mkCloseBracket() return new Token(0, TkBracketClose, "]", [], []);
	public static inline function mkOpenBrace() return new Token(0, TkBraceOpen, "{", [], []);
	public static inline function mkCloseBrace() return new Token(0, TkBraceClose, "}", [], []);
	public static inline function mkComma() return new Token(0, TkComma, ",", [], []);
	public static inline function mkDot() return new Token(0, TkDot, ".", [], []);
	public static inline function mkSemicolon() return new Token(0, TkSemicolon, ";", [], []);

	public static inline function addTrailingNewline(t:Token):Token {
		t.trailTrivia.push(newline);
		return t;
	}

	public static final whitespace = new Trivia(TrWhitespace, " ");
	public static final newline = new Trivia(TrNewline, "\n");
	public static final commaWithSpace = new Token(0, TkComma, ",", [], [whitespace]);

	public static function mkTokenWithSpaces(kind:TokenKind, text:String):Token {
		return new Token(0, kind, text, [whitespace], [whitespace]);
	}

	public static inline function mkEqualsEqualsToken():Token {
		return mkTokenWithSpaces(TkEqualsEquals, "==");
	}

	public static inline function mkNotEqualsToken():Token {
		return mkTokenWithSpaces(TkExclamationEquals, "!=");
	}

	public static inline function mkAndAndToken():Token {
		return mkTokenWithSpaces(TkAmpersandAmpersand, "&&");
	}
}
