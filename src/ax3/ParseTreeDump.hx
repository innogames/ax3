package ax3;

import ax3.ParseTree;

@:build(ax3.ParseTreeDumpMacro.build())
class ParseTreeDump {
	public static function printToken(t:Token, indent:String):String {
		return haxe.Json.stringify(t.text);
	}

	static function printArray<T>(elems:Array<T>, printer:(v:T, indent:String)->String, indent:String):String {
		if (elems.length == 0)
			return "[]";

		var nextIndent = indent + "  ";
		var elems = [for (elem in elems) nextIndent + printer(elem, nextIndent) + ","];
		return "[\n" + elems.join("\n") + "\n" + indent + "]";
	}

	static function printSeparated<T>(elems:Separated<T>, printer:(v:T, indent:String)->String, indent:String):String {
		if (elems == null)
			return "<>";
		var nextIndent = indent + "  ";
		var parts = [nextIndent + printer(elems.first, nextIndent)];
		for (elem in elems.rest) {
			parts.push(nextIndent + "(" + printToken(elem.sep, nextIndent) + ")");
			parts.push(nextIndent + printer(elem.element, nextIndent));
		}
		return "<\n" + parts.join("\n") + "\n" + indent + ">";
	}

	static inline function printNullable<T>(print:(v:Null<T>, indent:String)->String, v:Null<T>, indent:String):String {
		return if (v == null) "null" else print(v, indent);
	}
}
