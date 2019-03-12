package ax3;

import haxe.io.Output;
import ax3.ParseTree;
import ax3.TypedTree;

// TODO: skip tokens (optionally)
@:build(ax3.TypedTreeDumpMacro.build())
class TypedTreeDump {
	final out:Output;

	function new(out) {
		this.out = out;
	}

	public static function dump(module:TModule, path:String) {
		var out = sys.io.File.write(path);
		new TypedTreeDump(out).printTModule(module, "");
		out.close();
	}

	inline function str(s) out.writeString(s);

	function printToken(t:Token, indent:String) {
		str(haxe.Json.stringify(t.text));
	}

	function printArray<T>(elems:Array<T>, printer:(v:T, indent:String)->Void, indent:String) {
		if (elems.length == 0) {
			str("[]");
			return;
		}

		var nextIndent = indent + "  ";
		str("[\n");
		for (elem in elems) {
			str(nextIndent);
			printer(elem, nextIndent);
			str(",\n");
		}
		str(indent);
		str("]");
	}

	function printSeparated<T>(elems:Separated<T>, printer:(v:T, indent:String)->Void, indent:String) {
		if (elems == null) {
			str("<>");
			return;
		}
		var nextIndent = indent + "  ";
		str("<\n");
		str(nextIndent);
		printer(elems.first, nextIndent);
		for (elem in elems.rest) {
			str("\n");
			str(nextIndent);
			str("(");
			printToken(elem.sep, nextIndent);
			str(")");
			str("\n");
			str(nextIndent);
			printer(elem.element, nextIndent);
		}
		str("\n");
		str(indent);
		str(">");
	}

	inline function printNullable<T>(print:(v:Null<T>, indent:String)->Void, v:Null<T>, indent:String) {
		if (v == null) str("null") else print(v, indent);
	}
}
