package ax3;

import ax3.Token;
import ax3.ParseTree;
using StringTools;

enum HaxeType {
	HTPath(path:String, params:Array<HaxeType>);
	HTFun(args:Array<HaxeType>, ret:HaxeType);
}

typedef HaxeSignature = {
	var args:Map<String,HaxeType>;
	var ret:HaxeType;
}

abstract HaxeTypeAnnotation(String) {

	static function extractFromMetadata(m:Array<Metadata>):Null<HaxeTypeAnnotation> {
		if (m.length > 0) {
			return HaxeTypeAnnotation.extract(m[0].openBracket.leadTrivia);
		} else {
			return null;
		}
	}

	static function extractFromDeclModifiers(m:Array<DeclModifier>):Null<HaxeTypeAnnotation> {
		if (m.length > 0) {
			return HaxeTypeAnnotation.extract(switch (m[0]) {
				case DMPublic(t) | DMInternal(t) | DMFinal(t) | DMDynamic(t): t.leadTrivia;
			});
		} else {
			return null;
		}
	}

	public static function extractFromClassField(f:ClassField):Null<HaxeTypeAnnotation> {
		// before first meta
		var t = extractFromMetadata(f.metadata);
		if (t != null) return t;

		// before namespace
		if (f.namespace != null) {
			var t = HaxeTypeAnnotation.extract(f.namespace.leadTrivia);
			if (t != null) return t;
		}

		// before first modifier
		if (f.modifiers.length > 0) {
			var tok = switch (f.modifiers[0]) {
				case FMPublic(t) | FMPrivate(t) | FMProtected(t) | FMInternal(t) | FMOverride(t) | FMStatic(t) | FMFinal(t): t;
			};
			var t = HaxeTypeAnnotation.extract(tok.leadTrivia);
			if (t != null) return t;
		}

		// before the keyword
		switch (f.kind) {
			case FVar(VVar(keyword) | VConst(keyword), _) | FFun(keyword, _) | FGetter(keyword, _) | FSetter(keyword, _):
				return HaxeTypeAnnotation.extract(keyword.leadTrivia);
		}
	}

	public static function extractFromInterfaceField(f:InterfaceField):Null<HaxeTypeAnnotation> {
		// before first meta
		var t = extractFromMetadata(f.metadata);
		if (t != null) return t;

		// before the keyword
		switch (f.kind) {
			case IFFun(keyword, _) | IFGetter(keyword, _) | IFSetter(keyword, _):
				return HaxeTypeAnnotation.extract(keyword.leadTrivia);
		}
	}

	public static function extractFromModuleVarDecl(v:ModuleVarDecl):Null<HaxeTypeAnnotation> {
		// before first meta
		var t = extractFromMetadata(v.metadata);
		if (t != null) return t;

		// before first modifier
		t = extractFromDeclModifiers(v.modifiers);
		if (t != null) return t;

		// before the keyword
		return switch (v.kind) {
			case VVar(t) | VConst(t): HaxeTypeAnnotation.extract(t.leadTrivia);
		}
	}

	public static function extractFromModuleFunDecl(f:FunctionDecl):Null<HaxeTypeAnnotation> {
		// before first meta
		var t = extractFromMetadata(f.metadata);
		if (t != null) return t;

		// before first modifier
		t = extractFromDeclModifiers(f.modifiers);
		if (t != null) t;

		// before the keyword
		return HaxeTypeAnnotation.extract(f.keyword.leadTrivia);
	}

	public static function extractTrivia(trivia:Array<Trivia>, f:(tr:Trivia, comment:String)->Void) {
		var start = 0;
		for (i in 0...trivia.length) {
			var tr = trivia[i];
			switch tr.kind {
				case TrWhitespace:
					// remove whitespace
				case TrNewline | TrBlockComment:
					// remove after newline/blockcomment
					start = i + 1;
				case TrLineComment:
					var comment = tr.text.substring(2).ltrim(); // strip `//` and trim whitespaces
					if (comment.startsWith("@haxe-type(")) {
						var toDelete = i - start + 1;
						if (i < trivia.length - 1 && trivia[i + 1].kind == TrNewline) { // this should always be the case, but check just to be safe
							toDelete++;
						}
						trivia.splice(start, toDelete);
						f(tr, comment);
						return;
					}
			}
		}
	}

	public static function extract(trivia:Array<Trivia>):Null<HaxeTypeAnnotation> {
		var result:Null<HaxeTypeAnnotation> = null;
		extractTrivia(trivia, (tr, comment) -> result = cast comment.substring("@haxe-type(".length));
		return result;
	}

	public inline function parseTypeHint():HaxeType {
		return HaxeTypeParser.parseTypeHint(this);
	}

	public inline function parseSignature():HaxeSignature {
		return HaxeTypeParser.parseSignature(this);
	}
}

private class HaxeTypeParser {
	@:noCompletion // TODO: keep and properly report positions
	public inline static function malformed():Dynamic throw "malformed @haxe-type annotation";

	public static function parseTypeHint(typeString:String):HaxeType {
		var s = new MiniScanner(typeString);
		var t = parseType(s);
		// s.expect(TkCloseParen);
		return t;
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
				t;

			case TkIdent(i):
				s.consume();
				HTPath(parseDotPath(s, i), parseTypeParams(s));

			case _:
				malformed();
		}
	}

	public static function parseSignature(typeString:String):HaxeSignature {
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

		// s.expect(TkCloseParen);

		return {
			args: args,
			ret: (ret:HaxeType) // null-safety is dumb
		};
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
