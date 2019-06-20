package ax3.filters;

class CheckUntypedMethodCalls extends AbstractFilter {
	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		switch e.kind {
			case TECall({kind: TEField({type: TTAny | TTObject(_)}, fieldName, _)}, args):
				switch fieldName {
					case "hasOwnProperty" | "___keys": // these are fine :D
					case _:
						reportError(args.openParen.pos, "IMPORTANT: Untyped method call. This can cause possible slowdowns!");
				}
			case _:
		}
		return e;
	}
}
