package ax3.filters;

class StringApi extends AbstractFilter {
	static final tCompareMethod = TTFun([TTAny, TTAny], TTInt);
	static final tReplaceMethod = TTFun([TTString, TTString], TTString);
	static final tSplitMethod = TTFun([TTString], TTArray(TTString));
	static final tMatchMethod = TTFun([TTString], TTArray(TTString));
	static final tSearchMethod = TTFun([TTString], TTInt);
	static final tStringToolsReplace = TTFun([TTString, TTString, TTString], TTString);

	override function processExpr(e:TExpr):TExpr {
		return switch e.kind {
			case TECall({kind: TEField({kind: TOExplicit(dot, eString = {type: TTString})}, "replace", replaceToken)}, args):
				eString = processExpr(eString);
				args = mapCallArgs(processExpr, args);
				switch args.args {
					case [ePattern = {expr: {type: TTRegExp}}, eBy = {expr: {type: TTString | TTFunction | TTFun(_) | TTAny /*hmm*/}}]:
						processLeadingToken(t -> t.leadTrivia = removeLeadingTrivia(eString).concat(t.leadTrivia), ePattern.expr);
						var obj:TFieldObject = {
							kind: TOExplicit(dot, ePattern.expr),
							type: TTRegExp
						}
						var eReplaceMethod = mk(TEField(obj, "replace", replaceToken), tReplaceMethod, tReplaceMethod);
						e.with(kind = TECall(eReplaceMethod, args.with(args = [
							{expr: eString, comma: ePattern.comma}, eBy
						])));

					case [ePattern = {expr: {type: TTString}}, eBy = {expr: {type: TTString}}]:
						var eStringToolsReplace = mkBuiltin("StringTools.replace", tStringToolsReplace, removeLeadingTrivia(eString));
						e.with(kind = TECall(eStringToolsReplace, args.with(args = [
							{expr: eString, comma: commaWithSpace}, ePattern, eBy
						])));

					case _:
						throwError(exprPos(e), "Unsupported String.replace arguments");
				}

			case TECall({kind: TEField({kind: TOExplicit(dot, eString = {type: TTString})}, "match", fieldToken)}, args):
				eString = processExpr(eString);
				args = mapCallArgs(processExpr, args);
				switch args.args {
					case [ePattern = {expr: {type: TTRegExp}}]:
						processLeadingToken(t -> t.leadTrivia = removeLeadingTrivia(eString).concat(t.leadTrivia), ePattern.expr);
						var obj:TFieldObject = {
							kind: TOExplicit(dot, ePattern.expr),
							type: TTRegExp
						}
						var eMatchMethod = mk(TEField(obj, "match", fieldToken), tMatchMethod, tMatchMethod);
						e.with(kind = TECall(eMatchMethod, args.with(args = [{expr: eString, comma: null}])));

					case _:
						throwError(exprPos(e), "Unsupported String.match arguments");
				}

			case TECall({kind: TEField(fieldObject = {kind: TOExplicit(dot, eString = {type: TTString})}, "search", fieldToken)}, args):
				eString = processExpr(eString);
				args = mapCallArgs(processExpr, args);
				switch args.args {
					case [ePattern = {expr: {type: TTRegExp}}]:
						processLeadingToken(t -> t.leadTrivia = removeLeadingTrivia(eString).concat(t.leadTrivia), ePattern.expr);
						var obj:TFieldObject = {
							kind: TOExplicit(dot, ePattern.expr),
							type: TTRegExp
						}
						var eSearchMethod = mk(TEField(obj, "search", fieldToken), tSearchMethod, tSearchMethod);
						e.with(kind = TECall(eSearchMethod, args.with(args = [{expr: eString, comma: null}])));

					case [{expr: {type: TTString}}]:
						var fieldToken = new Token(fieldToken.pos, TkIdent, "indexOf", fieldToken.leadTrivia, fieldToken.trailTrivia);
						var eSearchMethod = mk(TEField(fieldObject, "indexOf", fieldToken), tSearchMethod, tSearchMethod);
						e.with(kind = TECall(eSearchMethod, args));

					case _:
						throwError(exprPos(e), "Unsupported String.search arguments");
				}

			case TECall({kind: TEField(fieldObject = {kind: TOExplicit(dot, eString = {type: TTString})}, "localeCompare", _)}, args):
				eString = processExpr(eString);
				args = mapCallArgs(processExpr, args);
				switch args.args {
					case [{expr: eOtherString = {type: TTString}}]:
						var eCompareMethod = mkBuiltin("Reflect.compare", tCompareMethod, removeLeadingTrivia(eString));
						e.with(kind = TECall(eCompareMethod, args.with(args = [
							{expr: eString, comma: commaWithSpace}, {expr: eOtherString, comma: null}
						])));

					case _:
						throwError(exprPos(e), "Unsupported String.localeCompare arguments");
				}

			case TECall({kind: TEField({kind: TOExplicit(_, eString = {type: TTString})}, "concat", _)}, args):
				eString = processExpr(eString);
				args = mapCallArgs(processExpr, args);
				var e = eString;
				for (arg in args.args) {
					e = mk(TEBinop(e, OpAdd(new Token(0, TkPlus, "+", [whitespace], [whitespace])), arg.expr.with(expectedType = TTString)), TTString, TTString);
				}
				e;

			case TECall(eMethod = {kind: TEField({kind: TOExplicit(dot, eString = {type: TTString})}, "split", fieldToken)}, args):
				args = mapCallArgs(processExpr, args);
				switch args.args {
					case [ePattern = {expr: {type: TTRegExp}}]:
						eString = processExpr(eString);

						processLeadingToken(t -> t.leadTrivia = removeLeadingTrivia(eString).concat(t.leadTrivia), ePattern.expr);
						var obj:TFieldObject = {
							kind: TOExplicit(dot, ePattern.expr),
							type: TTRegExp
						}
						var eSplitMethod = mk(TEField(obj, "split", fieldToken), tSplitMethod, tSplitMethod);
						e.with(kind = TECall(eSplitMethod, args.with(args = [{expr: eString, comma: null}])));

					case [{expr: {type: TTString}}]:
						eMethod = eMethod.with(kind = TEField({kind: TOExplicit(dot, processExpr(eString)), type: TTString}, "split", fieldToken));
						e.with(kind = TECall(eMethod, args));

					case _:
						throwError(exprPos(e), "Unsupported String.split arguments");
				}

			case TEField(fobj = {type: TTString}, "slice", fieldToken):
				mapExpr(processExpr, e).with(kind = TEField(fobj, "substring", new Token(fieldToken.pos, TkIdent, "substring", fieldToken.leadTrivia, fieldToken.trailTrivia)));

			case TEField(fobj = {type: TTString}, "toLocaleLowerCase", fieldToken):
				mapExpr(processExpr, e).with(kind = TEField(fobj, "toLowerCase", new Token(fieldToken.pos, TkIdent, "toLowerCase", fieldToken.leadTrivia, fieldToken.trailTrivia)));

			case TEField(fobj = {type: TTString}, "toLocaleUpperCase", fieldToken):
				mapExpr(processExpr, e).with(kind = TEField(fobj, "toUpperCase", new Token(fieldToken.pos, TkIdent, "toUpperCase", fieldToken.leadTrivia, fieldToken.trailTrivia)));

			case TEField({type: TTString}, name = "replace" | "match" | "split" | "concat" | "search" | "localeCompare", _):
				throwError(exprPos(e), "closure on String." + name);

			case _:
				mapExpr(processExpr, e);
		}
	}
}