package ax3.filters;

import ax3.TokenTools.mkIdent;
import ax3.TokenTools.mkDot;
import ax3.ParseTree.dotPathToArray;

class ExternModuleLevelImports extends AbstractFilter {
	final globals = new Map<String, {dotPath:String, kind:TDeclKind}>();

	static final asToken = new Token(0, TkIdent, "as", [new Trivia(TrWhitespace, " ")], [new Trivia(TrWhitespace, " ")]);

	override function processImport(i:TImport) {
		switch i.kind {
			case TIDecl(decl):
				switch decl.kind {
					case TDClassOrInterface(_): // ok
					case TDNamespace(_): // ignored
					case TDVar(_) | TDFunction(_): // need to be replaced
						var path = dotPathToArray(i.syntax.path);
						var fieldName = path.join("_"); // TODO: possible name clashes;
						globals[fieldName] = {dotPath: path.join("."), kind: decl.kind};

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
			switch desc.kind{
				case TDVar(v):
					var type = "Dynamic";

					buf.add('\tpublic static var $name(get,set):$type;\n');
					buf.add('\tstatic function get_$name():$type {\n\t\treturn $globalRef;\n\t}\n');
					buf.add('\tstatic function set_$name(value:$type):$type {\n\t\treturn $globalRef = value;\n\t}\n');

				case TDFunction(f):
					var args = [], callArgs = [];
					for (arg in f.fun.sig.args) {
						switch (arg.kind) {
							case TArgNormal(_, init):
								var type = "Dynamic";
								args.push((if (init != null) "?" + arg.name else arg.name) + ":" + type);
							case TArgRest(_, _): trace("TODO: rest args for " + desc.dotPath);
						}
						callArgs.push(arg.name);
					}
					var returnPrefix, returnType;
					switch (f.fun.sig.ret.type) {
						case TTVoid:
							returnPrefix = "";
							returnType = "Void";
						case _:
							returnPrefix = "return ";
							returnType = "Dynamic";
					};
					buf.add('\tpublic static function $name(${args.join(", ")}):$returnType {\n\t\t$returnPrefix$globalRef(${callArgs.join(", ")});\n\t}\n');

				case TDClassOrInterface(_) | TDNamespace(_): throw "assert";
			}
		}
		buf.add("}");
		return buf.toString();
	}
}
