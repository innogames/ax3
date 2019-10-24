package ax3.filters;

// TODO: maybe we could detect if we REALLY need to init the local var by checking if we read before writing or not
class VarInits extends AbstractFilter {
	override function processExpr(e:TExpr):TExpr {
		return switch e.kind {
			case TEVars(_, vars):
				for (v in vars) {
					v.init = processVarInit(v.v.type, v.init, true);
				}
				e;

			case _:
				mapExpr(processExpr, e);
		}
	}

	override function processVarField(v:TVarField) {
		v.init = processVarInit(v.type, v.init, false);
	}

	static function processVarInit(type:TType, init:Null<TVarInit>, initNull:Bool):TVarInit {
		if (init == null) {
			var expr = getDefaultInitExpr(type, initNull);
			return if (expr == null) null else { equalsToken: equalsToken, expr: expr };
		} else {
			return init;
		}
	}

	static final equalsToken = new Token(0, TkEquals, "=", [whitespace], [whitespace]);
	static final eFalse = mk(TELiteral(TLBool(mkIdent("false"))), TTBoolean, TTBoolean);
	static final eZeroInt = mk(TELiteral(TLInt(new Token(0, TkDecimalInteger, "0", [], []))), TTInt, TTInt);
	static final eZeroUint = mk(TELiteral(TLInt(new Token(0, TkDecimalInteger, "0", [], []))), TTUint, TTUint);
	static final eNaN = mkBuiltin("NaN", TTNumber);

	static function getDefaultInitExpr(t:TType, initNull:Bool):TExpr {
		return switch t {
			case TTBoolean: eFalse;
			case TTInt: eZeroInt;
			case TTUint: eZeroUint;
			case TTNumber: eNaN;
			case _: if (initNull) mkNullExpr(t) else null;
		};
	}
}
