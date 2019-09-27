package ax3.filters;

class RemoveRedundantParenthesis extends AbstractFilter {
	override function processExpr(e:TExpr):TExpr {
		return switch e.kind {
			case TEParens(openParen, eInnerOriginal, closeParen):
				var eInner = processExpr(eInnerOriginal);
				if (exprDoesntNeedParens(eInner)) {
					removeParens(openParen, eInner, closeParen, e.expectedType);
				} else if (eInner != eInnerOriginal) {
					e.with(kind = TEParens(openParen, eInner, closeParen));
				} else {
					e;
				}

			case TEReturn(token, eValue) if (eValue != null):
				processReturnThrow(e, token, eValue, TEReturn);

			case TEThrow(token, eValue):
				processReturnThrow(e, token, eValue, TEThrow);

			case _:
				mapExpr(processExpr, e);
		}
	}

	function processReturnThrow(eOriginal:TExpr, token:Token, eOriginalValue:TExpr, ctor:(Token,TExpr)->TExprKind):TExpr {
		var eValue = processExpr(eOriginalValue);
		if (eValue == eOriginalValue) {
			// nothing changed at all: just return the original expr
			return eOriginal;
		} else {
			if (!eValue.kind.match(TEParens(_))) {
				// ensure there's a space after the return/throw keyword if the parens are no more
				ensureTrailingWhitespace(token);
			}
			return eOriginal.with(kind = ctor(token, eValue));
		}
	}

	static inline function ensureTrailingWhitespace(token:Token) {
		if (token.trailTrivia.length == 0) {
			token.trailTrivia.push(whitespace);
		}
	}

	static function removeParens(openParen:Token, eInner:TExpr, closeParen:Token, expectedType:TType):TExpr {
		var lead = openParen.leadTrivia.concat(openParen.trailTrivia);
		var tail = closeParen.leadTrivia.concat(closeParen.trailTrivia);
		processLeadingToken(t -> t.leadTrivia = lead.concat(t.leadTrivia), eInner);
		processTrailingToken(t -> t.trailTrivia = t.trailTrivia.concat(tail), eInner);
		return eInner.with(expectedType = expectedType);
	}

	static function exprDoesntNeedParens(e:TExpr):Bool {
		return switch e.kind {
			case TEParens(_)
			   | TECall(_)
			   | TELiteral(_)
			   | TELocal(_)
			   | TEField(_)
			   | TEArrayAccess(_)
			   | TEBuiltin(_)
			   | TEDeclRef(_)
			   | TEArrayDecl(_)
			   | TEVectorDecl(_)
			   | TENew(_):
				true;
			case _:
				false;
		};
	}
}
