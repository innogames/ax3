package ax3.filters;

import ax3.Structure;
import ax3.TokenTools.mkIdent;
import ax3.TokenTools.mkDot;

class ExternModuleLevelImports extends AbstractFilter {
	final globals = new Map<String, {dotPath:String, kind:SDeclKind}>();

	static final asToken = new Token(0, TkIdent, "as", [new Trivia(TrWhitespace, " ")], [new Trivia(TrWhitespace, " ")]);

	override function processImport(i:TImport) {
		switch i.kind {
			case TIDecl(decl):
				switch (decl.kind) {
					case SClass(_): // ok
					case SNamespace: // ignored
					case SVar(_) | SFun(_): // need to be replaced
						var path = if (i.pack.name == "") decl.name else i.pack.name + "." + decl.name;
						var fieldName = StringTools.replace(path, ".", "_"); // TODO: possible name clashes;
						globals[fieldName] = {dotPath: path, kind: decl.kind};

						i.syntax.path = {
							first: mkIdent("Globals"),
							rest: [{sep: mkDot(), element: mkIdent(fieldName)}]
						};
						i.kind = TIAliased(decl, asToken, mkIdent(decl.name));

				}

			case TIAll(_) | TIAliased(_):
		}
	}

	public function printGlobalsClass():String {
		var buf = new StringBuf();
		buf.add("class Globals {\n");
		for (name => desc in globals) {
			var globalRef = 'untyped __global__["${desc.dotPath}"]';
			switch (desc.kind) {
				case SVar(v):
					var type = "Dynamic";

					buf.add('\tpublic static var $name(get,set):$type;\n');
					buf.add('\tstatic function get_$name():$type {\n\t\treturn $globalRef;\n\t}\n');
					buf.add('\tstatic function set_$name(value:$type):$type {\n\t\treturn $globalRef = value;\n\t}\n');

				case SFun(f):
					var args = [], callArgs = [];
					for (arg in f.args) {
						switch (arg.kind) {
							case SArgNormal(opt): args.push(if (opt) "?" + arg.name else arg.name);
							case SArgRest: trace("TODO: rest args for " + desc.dotPath);
						}
						callArgs.push(arg.name);
					}
					var returnPrefix = switch (f.ret) {
						case STVoid: "";
						case _: "return ";
					};
					buf.add('\tpublic static function $name(${args.join(", ")}) {\n\t\t$returnPrefix$globalRef(${callArgs.join(", ")});\n\t}\n');

				case SClass(_) | SNamespace: throw "assert";
			}
		}
		buf.add("}");
		return buf.toString();
	}
}
