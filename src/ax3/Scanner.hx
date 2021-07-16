package ax3;

import ax3.Token;

using StringTools;

enum ScanMode {
	MNormal;
	MNoRightShift;
	MExprStart;
}

class Scanner {
	var text:String;
	var end:Int;
	var pos:Int;
	var prevPos:Int = -1;
	var tokenStartPos:Int;
	var leadTrivia:Array<Trivia>;

	var lastPos:Int;
	var prevLastPos:Int = -1;
	var lastToken:Token;
	var prevConsumedToken:Token;
	var lastMode:ScanMode;
	var prevLastMode:ScanMode;

	public var lastConsumedToken(default,null):Token;

	public function new(text) {
		this.text = text;
		end = text.length;
		pos = tokenStartPos = 0;
	}

	public inline function advance() return doAdvance(MNormal);
	public inline function advanceNoRightShift() return doAdvance(MNoRightShift);
	public inline function advanceExprStart() return doAdvance(MExprStart);

	public function doAdvance(mode:ScanMode):PeekToken {
		if (lastToken != null) {
			if (mode == lastMode)
				return lastToken;
			else
				pos = lastPos;
		}
		lastPos = pos;
		lastMode = mode;
		lastToken = scan(mode);
		return lastToken;
	}

	public function consume():Token {
		prevLastMode = lastMode;
		prevConsumedToken = lastConsumedToken;
		lastConsumedToken = lastToken;
		lastToken = null;
		lastMode = null;
		return lastConsumedToken;
	}

	public function cancelConsume():Token {
		if (prevConsumedToken == null) return lastConsumedToken;
		lastMode = prevLastMode;
		lastToken = lastConsumedToken;
		lastConsumedToken = prevConsumedToken;
		prevConsumedToken = null;
		prevLastMode = null;
		return lastToken;
	}

	public function savePos(): Void {
		prevPos = pos;
		prevLastPos = lastPos;
	}

	public function restorePos(): Void {
		if (prevPos == -1) return;
		pos = prevPos;
		prevLastPos = lastPos;
	}

	function scanTrivia(breakOnNewLine:Bool):Array<Trivia> {
		var trivia = [];
		while (pos < end) {
			tokenStartPos = pos;

			var ch = text.fastCodeAt(pos);
			switch ch {
				case "\r".code:
					pos++;
					if (text.fastCodeAt(pos) == "\n".code)
						pos++;
					trivia.push(mkTrivia(TrNewline));
					if (breakOnNewLine)
						break;

				case "\n".code:
					pos++;
					trivia.push(mkTrivia(TrNewline));
					if (breakOnNewLine)
						break;

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
					trivia.push(mkTrivia(TrWhitespace));

				case "/".code:
					if (pos + 1 < end) {
						switch text.fastCodeAt(pos + 1) {
							case "/".code:
								pos += 2;
								while (pos < end) {
									ch = text.fastCodeAt(pos);
									if (ch == "\r".code || ch == "\n".code)
										break;
									pos++;
								}
								trivia.push(mkTrivia(TrLineComment));

							case "*".code:
								pos += 2;
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
								trivia.push(mkTrivia(TrBlockComment));
							case _:
								break;
						}
					}

				case _:
					break;
			}
		}
		return trivia;
	}

	function scan(mode:ScanMode):Token {
		while (true) {
			leadTrivia = scanTrivia(false);

			tokenStartPos = pos;
			if (pos >= end) {
				return mk(TkEof);
			}

			var ch = text.fastCodeAt(pos);
			switch ch {
				case ".".code:
					pos++;
					if (pos < end) {
						ch = text.fastCodeAt(pos);
						if (ch == ".".code) {
							pos++;
							if (pos < end && text.fastCodeAt(pos) == ".".code) {
								pos++;
								return mk(TkDotDotDot);
							} else {
								return mk(TkDotDot);
							}
						} else if (isDigit(ch)) {
							pos++;
							scanFloatAfterDot();
							return mk(TkFloat);
						} else {
							return mk(TkDot);
						}
					} else {
						return mk(TkDot);
					}

				case ",".code:
					pos++;
					return mk(TkComma);

				case ":".code:
					pos++;
					if (pos < end && text.fastCodeAt(pos) == ":".code) {
						pos++;
						return mk(TkColonColon);
					} else {
						return mk(TkColon);
					}

				case ";".code:
					pos++;
					return mk(TkSemicolon);

				case "{".code:
					pos++;
					return mk(TkBraceOpen);

				case "}".code:
					pos++;
					return mk(TkBraceClose);

				case "(".code:
					pos++;
					return mk(TkParenOpen);

				case ")".code:
					pos++;
					return mk(TkParenClose);

				case "[".code:
					pos++;
					return mk(TkBracketOpen);

				case "]".code:
					pos++;
					return mk(TkBracketClose);

				case "0".code:
					pos++;
					var kind = scanZeroLeadingNumber();
					return mk(kind);

				case "1".code | "2".code | "3".code | "4".code | "5".code | "6".code | "7".code | "8".code | "9".code:
					pos++;
					scanDigits();

					if (pos < end && text.fastCodeAt(pos) == ".".code) {
						pos++;
						scanFloatAfterDot();
						return mk(TkFloat);
					} else {
						return mk(TkDecimalInteger);
					}

				case "+".code:
					pos++;
					if (pos < end) {
						switch text.fastCodeAt(pos) {
							case "+".code:
								pos++;
								return mk(TkPlusPlus);
							case "=".code:
								pos++;
								return mk(TkPlusEquals);
							case _:
								return mk(TkPlus);
						}
					} else {
						return mk(TkPlus);
					}

				case "-".code:
					pos++;
					// TODO: scan negative number literals here too
					if (pos < end) {
						switch text.fastCodeAt(pos) {
							case "-".code:
								pos++;
								return mk(TkMinusMinus);
							case "=".code:
								pos++;
								return mk(TkMinusEquals);
							case _:
								return mk(TkMinus);
						}
					} else {
						return mk(TkMinus);
					}

				case "*".code:
					pos++;
					if (pos < end && text.fastCodeAt(pos) == "=".code) {
						pos++;
						return mk(TkAsteriskEquals);
					} else {
						return mk(TkAsterisk);
					}

				case "/".code:
					pos++;
					if (mode == MExprStart) {
						scanRegExp();
						return mk(TkRegExp);
					} else {
						if (pos < end && text.fastCodeAt(pos) == "=".code) {
							pos++;
							return mk(TkSlashEquals);
						} else {
							return mk(TkSlash);
						}
					}

				case "%".code:
					pos++;
					if (pos < end && text.fastCodeAt(pos) == "=".code) {
						pos++;
						return mk(TkPercentEquals);
					} else {
						return mk(TkPercent);
					}

				case "=".code:
					pos++;
					if (nextIsEquals()) {
						pos++;
						if (nextIsEquals()) {
							pos++;
							return mk(TkEqualsEqualsEquals);
						} else {
							return mk(TkEqualsEquals);
						}
					} else {
						return mk(TkEquals);
					}

				case "~".code:
					pos++;
					return mk(TkTilde);

				case "@".code:
					pos++;
					return mk(TkAt);

				case "!".code:
					pos++;
					if (nextIsEquals()) {
						pos++;
						if (nextIsEquals()) {
							pos++;
							return mk(TkExclamationEqualsEquals);
						} else {
							return mk(TkExclamationEquals);
						}
					} else {
						return mk(TkExclamation);
					}

				case "?".code:
					pos++;
					return mk(TkQuestion);

				case ">".code:
					pos++;
					if (pos < end) {
						switch text.fastCodeAt(pos) {
							case ">".code if (mode != MNoRightShift):
								pos++;
								if (pos < end) {
									switch text.fastCodeAt(pos) {
										case ">".code:
											pos++;
											if (pos < end && text.fastCodeAt(pos) == "=".code) {
												pos++;
												return mk(TkGtGtGtEquals);
											} else {
												return mk(TkGtGtGt);
											}
										case "=".code:
											pos++;
											return mk(TkGtGtEquals);
										case _:
											return mk(TkGtGt);
									}
								} else {
									return mk(TkGtGt);
								}
							case "=".code:
								pos++;
								return mk(TkGtEquals);
							case _:
								return mk(TkGt);
						}
					} else {
						return mk(TkGt);
					}

				case "<".code:
					pos++;
					if (mode == MExprStart) {
						scanXml();
						return mk(TkXml);
					} else {
						if (pos < end) {
							switch text.fastCodeAt(pos) {
								case "<".code:
									pos++;
									if (pos < end && text.fastCodeAt(pos) == "=".code) {
										pos++;
										return mk(TkLtLtEquals);
									} else {
										return mk(TkLtLt);
									}
								case "=".code:
									pos++;
									return mk(TkLtEquals);
								case _:
									return mk(TkLt);
							}
						} else {
							return mk(TkLt);
						}
					}

				case "&".code:
					pos++;
					if (pos < end) {
						switch text.fastCodeAt(pos) {
							case "&".code:
								pos++;
								if (pos < end && text.fastCodeAt(pos) == "=".code) {
									pos++;
									return mk(TkAmpersandAmpersandEquals);
								} else {
									return mk(TkAmpersandAmpersand);
								}
							case "=".code:
								pos++;
								return mk(TkAmpersandEquals);
							case _:
								return mk(TkAmpersand);
						}
					} else {
						return mk(TkAmpersand);
					}

				case "|".code:
					pos++;
					if (pos < end) {
						switch text.fastCodeAt(pos) {
							case "|".code:
								pos++;
								if (pos < end && text.fastCodeAt(pos) == "=".code) {
									pos++;
									return mk(TkPipePipeEquals);
								} else {
									return mk(TkPipePipe);
								}
							case "=".code:
								pos++;
								return mk(TkPipeEquals);
							case _:
								return mk(TkPipe);
						}
					} else {
						return mk(TkPipe);
					}

				case "^".code:
					pos++;
					if (pos < end && text.fastCodeAt(pos) == "=".code) {
						pos++;
						return mk(TkCaretEquals);
					} else {
						return mk(TkCaret);
					}

				case "\"".code:
					pos++;
					scanString(ch);
					return mk(TkStringDouble);

				case "'".code:
					pos++;
					scanString(ch);
					return mk(TkStringSingle);

				case _ if (isIdentStart(ch)):
					pos++;
					while (pos < end) {
						ch = text.fastCodeAt(pos);
						if (!isIdentPart(ch))
							break;
						pos++;
					}
					return mk(TkIdent);

				case _:
					pos++;
					return mk(TkUnknown);
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
			case "b".code:
			case "f".code:
			case "\\".code:
			case "/".code:
			case "\"".code:
			case "'".code:
			case "u".code:
				for (_ in 0...4) {
					if (pos >= end) {
						throw "Unterminated unicode character sequence at " + start;
					}
					ch = text.fastCodeAt(pos);
					if (!isHexDigit(ch)) {
						throw "Invalid unicode character sequence at " + start;
					}
					pos++;
				}
			default:
				throw "Invalid escape sequence at " + start;
		}
	}

	function scanRegExp() {
		while (true) {
			if (pos >= end) {
				throw "Unterminated regexp at " + tokenStartPos;
			}
			var ch = text.fastCodeAt(pos);
			if (ch == "/".code) {
				pos++;
				while (pos < end) {
					ch = text.fastCodeAt(pos);
					if (ch >= 'a'.code && ch <= 'z'.code) { // parse flags
						pos++;
					} else {
						break;
					}
				}
				return;
			} else if (ch == "\\".code) {
				pos++;
				if (pos >= end) {
					throw "Unterminated escape sequence at " + (pos - 1);
				}
				pos++;
			} else {
				pos++;
			}
		}
	}

	function scanXml() {
		throw "XML is not supported yet!";
	}

	function mkTrivia(kind:TriviaKind):Trivia {
		return new Trivia(kind, text.substring(tokenStartPos, pos));
	}

	function mk(kind:TokenKind):Token {
		var text = text.substring(tokenStartPos, pos);
		return new Token(tokenStartPos, kind, text, leadTrivia, scanTrivia(true));
	}
}
