package ax3.filters;

class HandleBasicValueDictionaryLookups extends AbstractFilter {
	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);

		return switch skipParens(e).kind {
			case TEBinop(a, op = OpAssign(_) | OpAssignOp(_), b) if (needsUnwrap(b)):
				e.with(kind = TEBinop(a, op, unwrap(b)));

			case TEVars(kind, vars):
				final mappedVars = mapVarDecls(maybeUnwrap, vars);
				if (mappedVars == vars) e else e.with(kind = TEVars(kind, mappedVars));

			case TECall(eobj, args):
				final mappedArgs = mapCallArgs(maybeUnwrap, args);
				if (mappedArgs == args) e else e.with(kind = TECall(eobj, mappedArgs));

			case TENew(keyword, obj, args):
				final mappedArgs = if (args == null) null else mapCallArgs(maybeUnwrap, args);
				if (mappedArgs == args) e else e.with(kind = TENew(keyword, obj, mappedArgs));

			case TEReturn(keyword, e) if (e != null && needsUnwrap(e)):
				e.with(kind = TEReturn(keyword, unwrap(e)));

			case _:
				e;
		}
	}

	static function maybeUnwrap(e:TExpr):TExpr {
		return if (needsUnwrap(e)) unwrap(e) else e;
	}

	static function unwrap(e:TExpr):TExpr {
		final lead = removeLeadingTrivia(e);
		final tail = removeTrailingTrivia(e);
		final eUnwrapMethod = mkBuiltin("ASCompat.processNull", TTFunction, lead, []);
		return e.with(kind = TECall(eUnwrapMethod, {
			openParen: mkOpenParen(),
			args: [{expr: e, comma: null}],
			closeParen: mkCloseParen(tail)
		}));
	}

	static function needsUnwrap(e:TExpr):Bool {
		return switch [e.kind, e.expectedType] {
			case [TEArrayAccess({eobj: {type: TTDictionary(_, TTInt | TTUint)}}), TTInt | TTUint]: true;
			case [TEArrayAccess({eobj: {type: TTDictionary(_, TTNumber)}}), TTNumber]: true;
			case [TEArrayAccess({eobj: {type: TTDictionary(_, TTBoolean)}}), TTBoolean]: true;
			case _: false;
		}
	}
}
