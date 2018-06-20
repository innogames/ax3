import Token;
using StringTools;

/**
	Scanner builds a linked list of all the tokens for a given source,
	including whitespace and comments.
**/
class Scanner {
	var text:String;
	var end:Int;
	var pos:Int;
	var tokenStartPos:Int;

	var head:Token;
	var tail:Token;

	public function new(text) {
		this.text = text;
		end = text.length;
		pos = tokenStartPos = 0;
	}

	public function scan():Token {
		while (true) {
			tokenStartPos = pos;
			if (pos >= end) {
				add(TkEof);
				return head;
			}

			var ch = text.fastCodeAt(pos);
			switch ch {
				case "\r".code:
					pos++;
					if (text.fastCodeAt(pos) == "\n".code)
						pos++;
					add(TkNewline);

				case "\n".code:
					pos++;
					add(TkNewline);

				case " ".code | "\t".code:
					pos++;
					while (pos < end) {
						ch = text.fastCodeAt(pos);
						if (ch == " ".code || ch == "\t".code) {
							pos++;
						} else {
							break;
						}
					}
					add(TkWhitespace);

				case ".".code:
					pos++;
					add(TkDot);

				case ",".code:
					pos++;
					add(TkComma);

				case ":".code:
					pos++;
					add(TkColon);

				case ";".code:
					pos++;
					add(TkSemicolon);

				case "{".code:
					pos++;
					add(TkBraceOpen);

				case "}".code:
					pos++;
					add(TkBraceClose);

				case "(".code:
					pos++;
					add(TkParenOpen);

				case ")".code:
					pos++;
					add(TkParenClose);

				case "/".code:
					pos++;
					if (pos < end) {
						switch text.fastCodeAt(pos) {
							case "/".code:
								pos++;
								while (pos < end) {
									ch = text.fastCodeAt(pos);
									if (ch == "\r".code || ch == "\n".code)
										break;
									pos++;
								}
								add(TkLineComment);

							case "*".code:
								pos++;
								while (pos < end) {
									if (text.fastCodeAt(pos) == "*".code && pos + 1 < end && text.fastCodeAt(pos + 1) == "/".code) {
										pos += 2;
										break;
									} else {
										pos++;
										if (pos >= end)
											throw "Unterminated block comment at " + tokenStartPos;
									}
								}
								add(TkBlockComment);

							case _:
								add(TkSlash);
						}
					} else {
						add(TkSlash);
					}

				case "=".code:
					pos++;
					add(TkEquals);

				case "*".code:
					pos++;
					add(TkAsterisk);

				case _ if (isIdentStart(ch)):
					pos++;
					while (pos < end) {
						ch = text.fastCodeAt(pos);
						if (!isIdentPart(ch))
							break;
						pos++;
					}
					add(TkIdent);

				case "\"".code:
					pos++;
					scanString();
					add(TkStringDouble);

				case _:
					throw "Invalid token at " + tokenStartPos;
			}
		}
	}

	inline function isNumber(ch) {
		return ch >= "0".code && ch <= "9".code;
	}

	inline function isIdentStart(ch) {
		return ch == "_".code || (ch >= "a".code && ch <= "z".code) || (ch >= "A".code && ch <= "Z".code);
	}

	inline function isIdentPart(ch) {
		return isNumber(ch) || isIdentStart(ch);
	}

	function scanString() {
		while (true) {
			if (pos >= end) {
				throw "Unterminated string at " + tokenStartPos;
			}
			// not using switch because of https://github.com/HaxeFoundation/haxe/pull/4964
			var ch = text.fastCodeAt(pos);
			if (ch == "\"".code) {
				pos++;
				break;
			} else if (ch == "\\".code) {
				pos++;
				scanEscapeSequence(pos - 1);
			} else {
				pos++;
			}
		}
	}

	function scanEscapeSequence(start:Int) {
		if (pos >= end) {
			throw "Unterminated escape sequence at " + start;
		}
		var ch = text.fastCodeAt(pos);
		pos++;
		return switch (ch) {
			case "t".code:
			case "n".code:
			case "r".code:
			case "\"".code:
			default:
				throw "Invalid escape sequence at " + start;
		}
	}

	function add(kind:TokenKind) {
		var token = new Token(kind, text.substring(tokenStartPos, pos));
		if (head == null) {
			head = tail = token;
		} else {
			token.prev = tail;
			tail.next = token;
			tail = token;
		}
	}
}
