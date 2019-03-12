package ax3.filters;

import ax3.TypedTree;
import ax3.TypedTreeTools.mapExpr;
import ax3.TypedTreeTools.mk;
import ax3.TypedTreeTools.mkNullExpr;
import ax3.TypedTreeTools.removeTrailingTrivia;
import ax3.TokenBuilder.mkNotEqualsToken;
using ax3.WithMacro;

class CoerceToBool {
	public static function process(e:TExpr):TExpr {
		// first, recurse into sub-expressions
		e = mapExpr(process, e);

		// then handle coercions in this expression if applicable
		return switch (e.kind) {
			case TEIf(i):
				e.with(kind = TEIf(i.with(econd = coerce(i.econd))));

			case TETernary(t):
				e.with(kind = TETernary(t.with(econd = coerce(t.econd))));

			case TEBinop(a, op = OpAnd(_) | OpOr(_), b):
				e.with(kind = TEBinop(coerce(a), op, coerce(b)));

			case _:
				e;
		}
	}

	static function coerce(e:TExpr):TExpr {
		return switch (e.type) {
			case TTBoolean:
				e;
			case TTFunction | TTFun(_) | TTClass | TTObject | TTInst(_) | TTStatic(_) | TTArray | TTVector(_):
				var trail = removeTrailingTrivia(e);
				e.with(kind = TEBinop(e, OpNotEquals(mkNotEqualsToken()), mkNullExpr(e.type, [], trail)));
			case TTInt | TTUint:
				var trail = removeTrailingTrivia(e);
				var zeroExpr = mk(TELiteral(TLInt(new Token(0, TkDecimalInteger, "0", [], trail))), e.type);
				e.with(kind = TEBinop(e, OpNotEquals(mkNotEqualsToken()), zeroExpr));
			case _:
				// TODO
				// string: null or empty
				// number: Nan or 0
				// any: runtime helper + warning?
				// void: should NOT happen (cases like `v && v.f()` should be filtered before)
				trace("(not) coercing " + e.type.getName());
				e;
		}
	}
}

