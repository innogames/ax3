import ParseTree;
import ParseTree.*;

class Typer2 {
	final structure:Structure;

	public function new(structure) {
		this.structure = structure;
	}

	public function process(files:Array<File>) {
		for (file in files) {

			var pack = getPackageDecl(file);

			var mainDecl = getPackageMainDecl(pack);

			var privateDecls = getPrivateDecls(file);

			var imports = getImports(file);

			// TODO: just skipping conditional-compiled ones for now
			if (mainDecl == null) return;

			switch (mainDecl) {
				case DPackage(p):
				case DImport(i):
				case DClass(c):
					typeClass(c);
				case DInterface(i):
				case DFunction(f):
				case DVar(v):
				case DNamespace(ns):
				case DUseNamespace(n, semicolon):
				case DCondComp(v, openBrace, decls, closeBrace):
			}

		}
	}

	function typeClass(c:ClassDecl) {
		for (m in c.members) {
			switch (m) {
				case MCondComp(v, openBrace, members, closeBrace):
				case MUseNamespace(n, semicolon):
				case MField(f):
					typeClassField(f);
				case MStaticInit(block):
			}
		}
	}

	function typeClassField(f:ClassField) {
		switch (f.kind) {
			case FVar(kind, vars, semicolon):
				iterSeparated(vars, function(v) {
				});
			case FFun(keyword, name, fun):
			case FProp(keyword, kind, name, fun):
		}
	}
}
