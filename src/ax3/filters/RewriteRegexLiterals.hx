package ax3.filters;

class RewriteRegexLiterals extends AbstractFilter {
	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch e.kind {
			case TELiteral(TLRegExp(token)):

				var lastSlashIndex = token.text.lastIndexOf("/");
				var pattern = token.text.substring(1, lastSlashIndex);
				var options = token.text.substring(lastSlashIndex + 1);

				var ePattern = mk(TELiteral(TLString(new Token(0, TkStringDouble, haxe.Json.stringify(pattern), [], []))), TTString, TTString);

				var args;
				if (options != "") {
					var eOptions = mk(TELiteral(TLString(new Token(0, TkStringDouble, haxe.Json.stringify(options), [], []))), TTString, TTString);
					args = [
						{expr: ePattern, comma: commaWithSpace},
						{expr: eOptions, comma: null}
					];
				} else {
					args = [{expr: ePattern, comma: null}];
				}

				var newToken = new Token(token.pos, TkIdent, "new", token.leadTrivia, [whitespace]);
				var args:TCallArgs = {
					openParen: mkOpenParen(),
					args: args,
					closeParen: mkCloseParen(token.trailTrivia)
				}
				e.with(kind = TENew(newToken, TNType({syntax: TPath({first: mkIdent("RegExp"), rest: []}), type: TTRegExp}), args));

			case TENew(newKeyword, TNType({type: TTRegExp}), args = {args: [{expr: eOtherRegExp = {type: TTRegExp}}]}):
				processLeadingToken(t -> t.leadTrivia = newKeyword.leadTrivia.concat(args.openParen.trailTrivia).concat(t.leadTrivia), eOtherRegExp);
				processTrailingToken(t -> t.trailTrivia = t.trailTrivia.concat(args.closeParen.trailTrivia), eOtherRegExp);
				eOtherRegExp.with(expectedType = TTRegExp);

			case _:
				e;
		}
	}
}
