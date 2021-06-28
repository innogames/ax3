package ax3.filters;

using StringTools;

class RewriteArrayTypes extends AbstractFilter {
	override function processExpr(e:TExpr):TExpr {
		return switch e.kind {
			case TEVars(k, [{v: {name: name, type: TTArray(_)}, syntax: syntax, init: init, comma: comma}]):
				final c = context.fileLoader.getContent(currentPath);
				final i = c.indexOf('//' , syntax.name.pos) + 2;
				final end = c.indexOf('\n' , syntax.name.pos);
				if (i < end) switch c.substring(i, end).trim() {
					case 'Array<Number>':
						e.kind = TEVars(k, [{
							v: {name: name, type: TTArray(TTNumber)},
							syntax: syntax,
							init: init,
							comma: comma
						}]);
					case 'Array<int>':
						e.kind = TEVars(k, [{
							v: {name: name, type: TTArray(TTInt)},
							syntax: syntax,
							init: init,
							comma: comma
						}]);
					case 'Array<uint>':
						e.kind = TEVars(k, [{
							v: {name: name, type: TTArray(TTUint)},
							syntax: syntax,
							init: init,
							comma: comma
						}]);
					case 'Array<String>':
						e.kind = TEVars(k, [{
							v: {name: name, type: TTArray(TTString)},
							syntax: syntax,
							init: init,
							comma: comma
						}]);
					case _:
				}
				e;
			case _:
				mapExpr(processExpr, e);
		}
	}
}