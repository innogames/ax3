package ax3.filters;

class DateApi extends AbstractFilter {
	override function processExpr(e:TExpr):TExpr {
		return switch e.kind {
			case TENew(keyword, TNType(ref = {type: TTInst(dateCls = {name: "Date", parentModule: {parentPack: {name: ""}}})}), args):
				args = mapCallArgs(processExpr, args);
				switch args {
					case null | {args: []}: // no arg ctor: rewrite to Date.now()
						var tDate = TTStatic(dateCls);
						var eDate = mk(TEDeclRef(switch ref.syntax { case TPath(p): p; case _: throw "assert";}, {name: "Date", kind: TDClassOrInterface(dateCls)}), tDate, tDate);

						processLeadingToken(t -> t.leadTrivia = t.leadTrivia.concat(keyword.leadTrivia), eDate);

						if (args == null) args = {
							openParen: mkOpenParen(),
							args: [],
							closeParen: new Token(0, TkParenClose, ")", [], removeTrailingTrivia(e))
						}
						var eNowField = mk(TEField({kind: TOExplicit(mkDot(), eDate), type: tDate}, "now", mkIdent("now")), TTFunction, TTFunction);
						e.with(kind = TECall(eNowField, args));

					case {args: [arg]}: // single-arg - rewrite to Date.fromTime(arg)
						var tDate = TTStatic(dateCls);
						var eDate = mk(TEDeclRef(switch ref.syntax { case TPath(p): p; case _: throw "assert";}, {name: "Date", kind: TDClassOrInterface(dateCls)}), tDate, tDate);

						processLeadingToken(t -> t.leadTrivia = t.leadTrivia.concat(keyword.leadTrivia), eDate);
						var efromTimeMethod = mk(TEField({kind: TOExplicit(mkDot(), eDate), type: tDate}, "fromTime", mkIdent("fromTime")), TTFunction, TTFunction);

						switch arg.expr.type {
							case TTInst(cls) if (cls == dateCls):
								// rewrite `new Date(otherDate)` to `Date.fromTime(otherDate.getTime())`
								var eGetTimeMethod = mk(TEField({kind: TOExplicit(mkDot(), arg.expr), type: arg.expr.type}, "getTime", mkIdent("getTime")), TTFunction, TTFunction);
								arg.expr = mk(TECall(eGetTimeMethod, {openParen: mkOpenParen(), args: [], closeParen: mkCloseParen()}), TTNumber, TTNumber);

							case TTInt | TTUint | TTNumber:
								// exactly what we want

							case other:
								// other types can break stuff, report, but continue
								reportError(exprPos(arg.expr), "Unknown parameter type for the Date constructor: " + other);
						}

						e.with(kind = TECall(efromTimeMethod, args));

					case _:
						e;
				}

			case TEBinop({kind: TEField({kind: TOExplicit(dot, eDate = {type: TTInst({name: "Date", parentModule: {parentPack: {name: ""}}})})}, fieldName, fieldToken)}, op = OpAssign(_) | OpAssignOp(_), expr):
				if (e.expectedType != TTVoid) {
					// this is annoying, because these `set*` methods return a timestamp instead of the passed value,
					// so we'll have to handle this specifically if we have a codebase that depends on this
					throwError(exprPos(e), "Using Date property assignments as values are not yet implemented");
				}

				if (op.match(OpAssignOp(_))) {
					reportError(exprPos(e), "TODO: Date property assignment operators (generated incorrectly now!!!)");
				}

				var to = {kind: TOExplicit(dot, processExpr(eDate)), type: eDate.type};
				expr = processExpr(expr);
				switch fieldName {
					case "date"
					   | "fullYear"
					   | "hours"
					   | "milliseconds"
					   | "minutes"
					   | "month"
					   | "seconds"
					   | "time"
					   :
						var methodName = "set" + fieldName.charAt(0).toUpperCase() + fieldName.substring(1);
						var eMethod = mk(TEField(to, methodName, mkIdent(methodName, fieldToken.leadTrivia)), TTFunction, TTFunction);
						e.with(kind = TECall(eMethod, {
							openParen: mkOpenParen(),
							args: [{expr: expr, comma: null}],
							closeParen: new Token(0, TkParenClose, ")", [], fieldToken.trailTrivia)
						}));

					case _:
						e;
				}

			case TEField({kind: TOExplicit(dot, eDate = {type: TTInst({name: "Date", parentModule: {parentPack: {name: ""}}})})}, fieldName, fieldToken):
				var to = {kind: TOExplicit(dot, processExpr(eDate)), type: eDate.type};
				switch fieldName {
					case "date"
					   | "day"
					   | "fullYear"
					   | "hours"
					   | "milliseconds"
					   | "minutes"
					   | "month"
					   | "seconds"
					   | "time"
					   | "timezoneOffset"
					   :
						var methodName = "get" + fieldName.charAt(0).toUpperCase() + fieldName.substring(1);
						var eMethod = mk(TEField(to, methodName, mkIdent(methodName, fieldToken.leadTrivia)), TTFunction, TTFunction);
						e.with(kind = TECall(eMethod, {
							openParen: mkOpenParen(),
							args: [],
							closeParen: new Token(0, TkParenClose, ")", [], fieldToken.trailTrivia)
						}));

					case "valueOf":
						e.with(kind = TEField(to, "getTime", new Token(fieldToken.pos, TkIdent, "getTime", fieldToken.leadTrivia, fieldToken.trailTrivia)));

					case _:
						mapExpr(processExpr, e);
				}

			case _:
				mapExpr(processExpr, e);
		}
	}
}