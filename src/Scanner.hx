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
					if (pos < end && isDigit(text.fastCodeAt(pos))) {
						pos++;
						scanFloatAfterDot();
						add(TkFloat);
					} else {
						add(TkDot);
					}

				case ",".code:
					pos++;
					add(TkComma);

				case ":".code:
					pos++;
					if (pos < end && text.fastCodeAt(pos) == ":".code) {
						pos++;
						add(TkColonColon);
					} else {
						add(TkColon);
					}

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

				case "[".code:
					pos++;
					add(TkBracketOpen);

				case "]".code:
					pos++;
					add(TkBracketClose);

				case "0".code:
					pos++;
					var kind = scanZeroLeadingNumber();
					add(kind);

				case "1".code | "2".code | "3".code | "4".code | "5".code | "6".code | "7".code | "8".code | "9".code:
					pos++;
					scanDigits();

					if (pos < end && text.fastCodeAt(pos) == ".".code) {
						pos++;
						scanFloatAfterDot();
						add(TkFloat);
					} else {
						add(TkDecimalInteger);
					}

				case "+".code:
					pos++;
					if (pos < end) {
						switch text.fastCodeAt(pos) {
							case "+".code:
								pos++;
								add(TkPlusPlus);
							case "=".code:
								pos++;
								add(TkPlusEquals);
							case _:
								add(TkPlus);
						}
					} else {
						add(TkPlus);
					}

				case "-".code:
					pos++;
					// TODO: scan negative number literals here too
					if (pos < end) {
						switch text.fastCodeAt(pos) {
							case "-".code:
								pos++;
								add(TkMinusMinus);
							case "=".code:
								pos++;
								add(TkMinusEquals);
							case _:
								add(TkMinus);
						}
					} else {
						add(TkMinus);
					}

				case "*".code:
					pos++;
					if (pos < end && text.fastCodeAt(pos) == "=".code) {
						pos++;
						add(TkAsteriskEquals);
					} else {
						add(TkAsterisk);
					}

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

							case "=".code:
								pos++;
								add(TkSlashEquals);

							case _:
								add(TkSlash);
						}
					} else {
						add(TkSlash);
					}

				case "%".code:
					pos++;
					if (pos < end && text.fastCodeAt(pos) == "=".code) {
						pos++;
						add(TkPercentEquals);
					} else {
						add(TkPercent);
					}

				case "=".code:
					pos++;
					if (nextIsEquals()) {
						pos++;
						if (nextIsEquals()) {
							pos++;
							add(TkEqualsEqualsEquals);
						} else {
							add(TkEqualsEquals);
						}
					} else {
						add(TkEquals);
					}

				case "!".code:
					pos++;
					if (nextIsEquals()) {
						pos++;
						if (nextIsEquals()) {
							pos++;
							add(TkExclamationEqualsEquals);
						} else {
							add(TkExclamationEquals);
						}
					} else {
						add(TkExclamation);
					}

				case "?".code:
					pos++;
					add(TkQuestion);

				case ">".code:
					pos++;
					if (pos < end) {
						switch text.fastCodeAt(pos) {
							case ">".code:
								pos++;
								if (pos < end && text.fastCodeAt(pos) == ">".code) {
									pos++;
									add(TkGtGtGt);
								} else {
									add(TkGtGt);
								}
							case "=".code:
								pos++;
								add(TkGtEquals);
							case _:
								add(TkGt);
						}
					} else {
						add(TkGt);
					}

				case "<".code:
					pos++;
					if (pos < end) {
						switch text.fastCodeAt(pos) {
							case "<".code:
								pos++;
								add(TkLtLt);
							case "=".code:
								pos++;
								add(TkLtEquals);
							case _:
								add(TkLt);
						}
					} else {
						add(TkLt);
					}

				case "&".code:
					pos++;
					if (pos < end && text.fastCodeAt(pos) == "&".code) {
						pos++;
						add(TkAmpersandAmpersand);
					} else {
						add(TkAmpersand);
					}

				case "|".code:
					pos++;
					if (pos < end && text.fastCodeAt(pos) == "|".code) {
						pos++;
						add(TkPipePipe);
					} else {
						add(TkPipe);
					}

				case "^".code:
					pos++;
					if (pos < end && text.fastCodeAt(pos) == "=".code) {
						pos++;
						add(TkCaretEquals);
					} else {
						add(TkCaret);
					}

				case "\"".code:
					pos++;
					scanString(ch);
					add(TkStringDouble);

				case "'".code:
					pos++;
					scanString(ch);
					add(TkStringSingle);

				case _ if (isIdentStart(ch)):
					pos++;
					while (pos < end) {
						ch = text.fastCodeAt(pos);
						if (!isIdentPart(ch))
							break;
						pos++;
					}
					add(TkIdent);

				case _:
					throw "Invalid token at " + tokenStartPos + ": " + haxe.Json.stringify(text.substring(tokenStartPos, pos+1));
			}
		}
	}

	function scanZeroLeadingNumber():TokenKind {
		if (pos < end) {
			var ch = text.fastCodeAt(pos);

			if (ch == "x".code || ch == "X".code) {
				pos++;
				if (pos >= end || !isHexDigit(text.fastCodeAt(pos)))
					throw "Unterminated hexadecimal number";
				pos++;
				scanHexDigits();
				return TkHexadecimalInteger;
			}

			if (ch == ".".code) {
				pos++;
				scanFloatAfterDot();
				return TkFloat;
			}

			if (isDigit(ch)) {
				throw "octal literals are not supported";
			}
		}
		return TkDecimalInteger;
	}

	inline function nextIsEquals() {
		return pos < end && text.fastCodeAt(pos) == "=".code;
	}

	inline function scanDigits() {
		while (pos < end && isDigit(text.fastCodeAt(pos))) {
			pos++;
		}
	}

	inline function scanHexDigits() {
		while (pos < end && isHexDigit(text.fastCodeAt(pos))) {
			pos++;
		}
	}

	function scanFloatAfterDot() {
		scanDigits();
		if (pos < end) {
			switch text.fastCodeAt(pos) {
				case "e".code | "E".code:
					pos++;

					if (pos >= end)
						throw "Unterminated float literal";

					switch text.fastCodeAt(pos) {
						case "+".code | "-".code:
							pos++;
						case _:
					}

					if (pos >= end)
						throw "Unterminated float literal";

					if (!isDigit(text.fastCodeAt(pos)))
						throw "Unterminated float literal";

					pos++;
					scanDigits();

				case _:
			}
		}
	}

	inline function isDigit(ch) {
		return ch >= "0".code && ch <= "9".code;
	}

	inline function isHexDigit(ch) {
		return (ch >= "0".code && ch <= "9".code) || (ch >= "a".code && ch <= "f".code) || (ch >= "A".code && ch <= "F".code);
	}

	inline function isIdentStart(ch) {
		return ch == "_".code || (ch >= "a".code && ch <= "z".code) || (ch >= "A".code && ch <= "Z".code);
	}

	inline function isIdentPart(ch) {
		return isDigit(ch) || isIdentStart(ch);
	}

	function scanString(delimeter:Int) {
		while (true) {
			if (pos >= end) {
				throw "Unterminated string at " + tokenStartPos;
			}
			// not using switch because of https://github.com/HaxeFoundation/haxe/pull/4964
			var ch = text.fastCodeAt(pos);
			if (ch == delimeter) {
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
			case "'".code:
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
