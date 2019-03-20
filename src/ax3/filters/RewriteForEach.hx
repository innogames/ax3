package ax3.filters;

class RewriteForEach extends AbstractFilter {
	override function processExpr(e:TExpr):TExpr {
		return e;
		return switch (e.kind) {
			case TEForEach(f):
				// var body = processExpr(f.body);

				// var itName, vit, eobj;
				switch (f.iter.eit.kind) {
					// for each (var x in obj)
					case TEVars(kind, [varDecl]):

					// for each (x in obj)
					case TELocal(_, v):

					case _:
						reportError(exprPos(f.iter.eit), "Unsupported `for each in` iterator");
						throw "assert";
				};

				// mapExpr(processExpr, e);
				e;

			case _:
				e;
				// mapExpr(processExpr, e);
		}
	}
}
