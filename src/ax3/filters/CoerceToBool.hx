package ax3.filters;
/**
	Replace non-boolean values that are used where boolean is expected with a coercion call.
	E.g. `if (object)` to `if (object != null)`
**/
class CoerceToBool {
	public static function process(e:TExpr):TExpr {
		// first, recurse into sub-expressions
		e = mapExpr(process, e);

		// then handle coercions in this expression if applicable
		return switch (e.kind) {
			case TEIf(i):
				// TODO: here and in the TETernary case we can generate `object == null` for `!object` (and similar for numeric and others)
				e.with(kind = TEIf(i.with(econd = coerce(i.econd))));

			case TETernary(t):
				e.with(kind = TETernary(t.with(econd = coerce(t.econd))));

			case TEBinop(a, op = OpAnd(_) | OpOr(_), b):
				mk(TEBinop(coerce(a), op, coerce(b)), TTBoolean);

			case TEVars(kind, vars):
				e.with(kind = TEVars(kind, [
					for (v in vars)
						switch v.v.type {
							case TTBoolean if (v.init != null):
								v.with(init = v.init.with(expr = coerce(v.init.expr)));
							case _:
								v;
						}
				]));

			case TECall(obj, args):
				switch (obj.type) {
					case TTFun(argTypes, _, rest):
						var newArgs = [];
						for (i in 0...args.args.length) {
							var arg = args.args[i];
							var argType =
								if (i >= argTypes.length) {
									if (!rest) throw "invalid call arg count: " + debugExpr(e) else TTAny;
								} else {
									argTypes[i];
								};
							newArgs.push(switch (argType) {
								case TTBoolean:
									arg.with(expr = coerce(arg.expr));
								case _:
									arg;
							});
						}
						e.with(kind = TECall(obj, args.with(args = newArgs)));
					case _:
						e;
				}

			case _:
				e;
		}
	}

	static function coerce(e:TExpr):TExpr {
		// TODO: add parens where needed
		return switch (e.type) {
			case TTBoolean:
				e;

			case TTFunction | TTFun(_) | TTClass | TTObject | TTInst(_) | TTStatic(_) | TTArray | TTVector(_) | TTRegExp | TTXML | TTXMLList:
				var trail = removeTrailingTrivia(e);
				mk(TEBinop(e, OpNotEquals(mkNotEqualsToken()), mkNullExpr(e.type, [], trail)), TTBoolean);

			case TTInt | TTUint:
				var trail = removeTrailingTrivia(e);
				var zeroExpr = mk(TELiteral(TLInt(new Token(0, TkDecimalInteger, "0", [], trail))), e.type);
				mk(TEBinop(e, OpNotEquals(mkNotEqualsToken()), zeroExpr), TTBoolean);

			case TTString if (canBeRepeated(e)):
				var trail = removeTrailingTrivia(e);
				var nullExpr = mkNullExpr(TTString);
				var emptyExpr = mk(TELiteral(TLString(new Token(0, TkStringDouble, '""', [], trail))), TTString);
				var nullCheck = mk(TEBinop(e, OpNotEquals(mkNotEqualsToken()), nullExpr), TTBoolean);
				var emptyCheck = mk(TEBinop(e, OpNotEquals(mkNotEqualsToken()), emptyExpr), TTBoolean);
				mk(TEBinop(nullCheck, OpAnd(mkAndAndToken()), emptyCheck), TTBoolean);

			case TTString | TTNumber | TTAny | TTVoid | TTBuiltin:
				// TODO
				// string: null or empty
				// number: Nan or 0
				// any: runtime helper + warning?
				// builtin: gotta remove this really
				// void: should NOT happen (cases like `v && v.f()` should be filtered before)
				trace("(not) coercing " + e.type.getName());
				e;
		}
	}
}

