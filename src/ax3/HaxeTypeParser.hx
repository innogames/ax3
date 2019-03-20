package ax3;

import ax3.Token;
using StringTools;

enum HaxeType {
	HTPath(path:String, params:Array<HaxeType>);
	HTFun(args:Array<HaxeType>, ret:HaxeType);
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

	static function parseTypeHint(typeString:String):HaxeType {
		throw "TODO";
	}

	static function parseSignature(typeString:String):HaxeSignature {
		throw "TODO";
	}

	static function extractHaxeType(trivia:Array<Trivia>):Null<String> {
		for (tr in trivia) {
			if (tr.kind == TrLineComment) {
				var comment = tr.text.substring(2).trim(); // strip `//` and trim whitespaces
				if (comment.startsWith("@haxe-type(")) {
					if (comment.charCodeAt(comment.length - 1) != ")".code) {
						throw 'malformed @haxe-type comment';
					}
					return comment.substring("@haxe-type(".length, comment.length - 1);
				}
			}
		}
		return null;
	}
}