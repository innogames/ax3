package ax3.filters;

class MathApi extends AbstractFilter {
	override function processExpr(e:TExpr):TExpr {
		return switch e.kind {
			case TECall(
					eMethod = {
						kind: TEField(
							fieldObj = {kind: TOExplicit(_,
								{kind: TEDeclRef(_, {kind: TDClassOrInterface({name: "Math", parentModule: {parentPack: {name: ""}}})}) }
							)},
							fieldName = "round" | "floor" | "ceil",
							fieldToken)
					},
					args
				):

				args = mapCallArgs(processExpr, args);

				if (e.expectedType.match(TTInt | TTUint)) {
					e.with(type = TTInt);
				} else {
					fieldName = "f" + fieldName;
					fieldToken = mkIdent(fieldName, fieldToken.leadTrivia, fieldToken.trailTrivia);
					eMethod = eMethod.with(kind = TEField(fieldObj, fieldName, fieldToken));
					e.with(kind = TECall(eMethod, args));
				}

			case TECall(
					eMethod = {
						kind: TEField(
							fieldObj = {kind: TOExplicit(_,
								{kind: TEDeclRef(_, mathDecl = {kind: TDClassOrInterface({name: "Math", parentModule: {parentPack: {name: ""}}})}) }
							)},
							fieldName = "min" | "max",
							_)
					},
					args
				) if (args.args.length > 2):

				args = mapCallArgs(processExpr, args);

				var eMethod2 = eMethod.with(kind = TEField({
					kind: TOExplicit(mkDot(), mkDeclRef({first: mkIdent("Math"), rest: []}, mathDecl, TTAny)),
					type: fieldObj.type,
				}, fieldName, mkIdent(fieldName)));
				var openParen = mkOpenParen();
				var closeParen = mkCloseParen();

				var firstArg = args.args[0];
				var secondArg = args.args[1];
				for (i in 2...args.args.length) {
					var arg = args.args[i];
					var argExpr = arg.expr.with(expectedType = TTNumber); // because the typer didn't know it must be a number
					secondArg = arg.with(
						expr = mk(
							TECall(eMethod2, {
								openParen: openParen,
								args: [secondArg, {expr: argExpr, comma: null}],
								closeParen: closeParen
							}),
							TTNumber,
							TTNumber
						)
					);
				}

				e.with(kind = TECall(eMethod, args.with(args = [firstArg, secondArg])));

			case TEDeclRef(_, {name: "Infinity", kind: TDVar({parentModule: {parentPack: {name: ""}}})}):
				var name = "Math.POSITIVE_INFINITY";
				e.with(kind = TEBuiltin(mkIdent(name, removeLeadingTrivia(e), removeTrailingTrivia(e)), name));

			case TEPreUnop(PreNeg(_), {kind: TEDeclRef(_, {name: "Infinity", kind: TDVar({parentModule: {parentPack: {name: ""}}})})}):
				var name = "Math.NEGATIVE_INFINITY";
				e.with(kind = TEBuiltin(mkIdent(name, removeLeadingTrivia(e), removeTrailingTrivia(e)), name));

			case _:
				mapExpr(processExpr, e);
		}
	}
}
