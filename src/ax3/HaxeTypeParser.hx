package ax3;

import ax3.Token;
using StringTools;

enum HaxeType {
	HTPath(path:String, params:Array<HaxeType>);
	HTFun(args:Array<HaxeType>, ret:HaxeType);
	HTParen(t:HaxeType);
}

typedef HaxeSignature = {
	var args:Map<String,HaxeType>;
	var ret:HaxeType;
}

@:nullSafety
class HaxeTypeParser {
	public static function readHaxeType(trivia:Array<Trivia>):Null<HaxeType> {
		var typeString = extractHaxeType(trivia);
		return if (typeString == null) null else parseTypeHint(typeString);
	}

	public static function readHaxeSignature(trivia:Array<Trivia>):Null<HaxeSignature> {
		var typeString = extractHaxeType(trivia);
		return if (typeString == null) null else parseSignature(typeString);
	}

	@:noCompletion
	public inline static function malformed():Dynamic throw "malformed @haxe-type annotation";

	static function parseTypeHint(typeString:String):HaxeType {
		return parseType(new MiniScanner(typeString));
	}

	static function parseType(s:MiniScanner):HaxeType {
		var first = parseTypeInner(s);
		return parseTypeNext(s, first);
	}

	static function parseTypeNext(s:MiniScanner, first:HaxeType):HaxeType {
		return switch s.peek() {
			case TkArrow:
				s.consume();
				var args = switch first {
						case HTPath("Void", []): [];
						case _: [first];
					};
				var last = parseTypeInner(s);
				while (true) {
					switch s.peek() {
						case TkArrow:
							s.consume();
							args.push(last);
							last = parseTypeInner(s);
						case _:
							break;
					}
				}
				HTFun(args, last);

			case _:
				first;
		}
	}

	static function parseDotPath(s:MiniScanner, first:String):String {
		return switch s.peek() {
			case TkDot:
				s.consume();
				var next = s.expectIdent();
				parseDotPath(s, first + "." + next);

			case _:
				first;
		}
	}

	static function parseTypeParams(s:MiniScanner) {
		return switch s.peek() {
			case TkLt:
				s.consume();

				var params = [parseType(s)];
				while (true) {
					switch s.peek() {
						case TkComma:
							s.consume();
							params.push(parseType(s));
						case _:
							break;
					}
				}

				s.expect(TkGt);
				params;
			case _:
				[];
		}
	}

	static function parseTypeInner(s:MiniScanner) {
		return switch s.peek() {
			case TkOpenParen:
				s.consume();
				var t = parseType(s);
				s.expect(TkCloseParen);
				HTParen(t);

			case TkIdent(i):
				s.consume();
				HTPath(parseDotPath(s, i), parseTypeParams(s));

			case _:
				malformed();
		}
	}

	static function parseSignature(typeString:String):HaxeSignature {
		var s = new MiniScanner(typeString);
		var args = new Map<String,HaxeType>();
		var ret:Null<HaxeType> = null;

		function parseArg() {
			var name = s.expectIdent();
			s.expect(TkColon);
			var type = parseType(s);
			if (name == "return") {
				ret = type;
			} else {
				args[name] = type;
			}
		}

		while (true) {
			parseArg();
			switch s.peek() {
				case TkPipe: s.consume();
				case _: break;
			}
		}

		if (ret == null) malformed();

		return {
			args: args,
			ret: (ret:HaxeType) // null-safety is dumb
		};
	}

	static function extractHaxeType(trivia:Array<Trivia>):Null<String> {
		for (tr in trivia) {
			if (tr.kind == TrLineComment) {
				var comment = tr.text.substring(2).ltrim(); // strip `//` and trim whitespaces
				if (comment.startsWith("@haxe-type(")) {
					return comment.substring("@haxe-type(".length);
				}
			}
		}
		return null;
	}
}

private class MiniScanner {
	final text:String;
	final end:Int;
	var pos:Int;
	var lastToken:Null<MiniToken>;

	public function new(text) {
		this.text = text;
		this.end = text.length;
		pos = 0;
	}

	public function peek():MiniToken {
		if (lastToken == null) {
			lastToken = scan();
		}
		return lastToken;
	}

	public function consume():MiniToken {
		var t = lastToken;
		lastToken = null;
		return t;
	}

	public function expect(t:MiniToken) {
		if (peek() != t) HaxeTypeParser.malformed() else consume();
	}

	public function expectIdent():String {
		return switch peek() {
			case TkIdent(i): consume(); i;
			case _: HaxeTypeParser.malformed();
		}
	}

	function scan():MiniToken {
		while (true) {
			if (pos >= end) {
				return TkEnd;
			}
			var ch = text.fastCodeAt(pos);
			switch ch {
				case " ".code:
					pos++;
				case ".".code:
					pos++;
					return TkDot;
				case ",".code:
					pos++;
					return TkComma;
				case ":".code:
					pos++;
					return TkColon;
				case "|".code:
					pos++;
					return TkPipe;
				case "<".code:
					pos++;
					return TkLt;
				case ">".code:
					pos++;
					return TkGt;
				case "(".code:
					pos++;
					return TkOpenParen;
				case ")".code:
					pos++;
					return TkCloseParen;
				case "-".code:
					pos++;
					if (pos < end && text.fastCodeAt(pos) == ">".code) {
						pos++;
						return TkArrow;
					} else {
						HaxeTypeParser.malformed();
					}
				case _ if (isIdentStart(ch)):
					var startPos = pos;
					pos++;
					while (pos < end) {
						ch = text.fastCodeAt(pos);
						if (!isIdentPart(ch)) {
							break;
						}
						pos++;
					}
					return TkIdent(text.substring(startPos, pos));
				case _:
					HaxeTypeParser.malformed();
			}
		}
	}

	inline function isDigit(ch) {
		return ch >= "0".code && ch <= "9".code;
	}

	inline function isIdentStart(ch) {
		return ch == "_".code || (ch >= "a".code && ch <= "z".code) || (ch >= "A".code && ch <= "Z".code);
	}

	inline function isIdentPart(ch) {
		return isDigit(ch) || isIdentStart(ch);
	}
}

private enum MiniToken {
	TkIdent(ident:String);
	TkOpenParen;
	TkCloseParen;
	TkLt;
	TkGt;
	TkDot;
	TkComma;
	TkArrow;
	TkColon;
	TkPipe;
	TkEnd;
}
