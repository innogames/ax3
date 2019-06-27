package ax3.filters;

class DateApi extends AbstractFilter {
	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch e.kind {
			case TENew(keyword, TNType(ref = {type: TTInst(dateCls = {name: "Date", parentModule: {parentPack: {name: ""}}})}), args):
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

					case {args: [_]}: // single-arg - rewrite to Date.fromTime(arg)
						var tDate = TTStatic(dateCls);
						var eDate = mk(TEDeclRef(switch ref.syntax { case TPath(p): p; case _: throw "assert";}, {name: "Date", kind: TDClassOrInterface(dateCls)}), tDate, tDate);

						processLeadingToken(t -> t.leadTrivia = t.leadTrivia.concat(keyword.leadTrivia), eDate);
						var eNowField = mk(TEField({kind: TOExplicit(mkDot(), eDate), type: tDate}, "fromTime", mkIdent("fromTime")), TTFunction, TTFunction);
						e.with(kind = TECall(eNowField, args));

					case _:
						e;
				}

			case TEField(to = {type: TTInst({name: "Date", parentModule: {parentPack: {name: ""}}})}, fieldName, fieldToken):
				switch fieldName {
					case "fullYear" | "time": // TODO other getters
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
						e;
				}

			case _:
				e;
		}
	}
}