package ax3.filters;

// Haxe forbids comparison between int and uint with `Comparison of Int and UInt might lead to unexpected results`
// so we cast int to uint where needed
// TODO: report a warning here so we can fix types in AS3?
class UintComparison extends AbstractFilter {
	override function processExpr(e:TExpr):TExpr {
		return switch e.kind {
			case TEBinop(a, op = OpEquals(_) | OpNotEquals(_) | OpGt(_) | OpGte(_) | OpLt(_) | OpLte(_), b):
				switch [a.type, b.type] {
					case [TTInt, TTUint] if (!a.kind.match(TELiteral(_))):
						a = processExpr(a);
						b = processExpr(b);
						e.with(kind = TEBinop(a.with(kind = TEHaxeRetype(a), type = TTUint), op, b));

					case [TTUint, TTInt] if (!b.kind.match(TELiteral(_))):
						a = processExpr(a);
						b = processExpr(b);
						e.with(kind = TEBinop(a, op, b.with(kind = TEHaxeRetype(b), type = TTUint)));

					case _:
						mapExpr(processExpr, e);
				}
			case _:
				mapExpr(processExpr, e);
		}
	}
}
