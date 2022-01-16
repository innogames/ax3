package ax3.filters;

using StringTools;

class RewriteTypesWithComment extends AbstractFilter {
	override function processExpr(e:TExpr):TExpr {
		return switch e.kind {
			case TEVars(k, [{v: {name: name, type: TTArray(_)}, syntax: syntax, init: init, comma: comma}]):
				final c = context.fileLoader.getContent(currentPath);
				final i = c.indexOf('//' , syntax.name.pos) + 2;
				final end = c.indexOf('\n' , syntax.name.pos);
				if (i < end) {
					final v = c.substring(i, end).trim();
					if ((v.startsWith('Array<')) && v.endsWith('>'))
						e.kind = TEVars(k, [{
							v: {name: name, type: tree.getType(v)},
							syntax: syntax,
							init: init,
							comma: comma
						}]);
				}
				e;
			case TENew(keyword, TNewObject.TNType({type: TTDictionary(_) | TTObject(_), syntax: TPath({first: syntax})}), _):
				final c = context.fileLoader.getContent(currentPath);
				final i = c.indexOf('//' , syntax.pos) + 2;
				final end = c.indexOf('\n' , syntax.pos);
				if (i < end) {
					final v = c.substring(i, end).trim();
					if ((v.startsWith('Dictionary<') || v.startsWith('Object<')) && v.endsWith('>'))
						e.kind = TENew(keyword, TNewObject.TNType({type: tree.getType(v), syntax: TPath({first: syntax, rest: []})}), null);
				}
				e;
			case _:
				mapExpr(processExpr, e);
		}
	}

}