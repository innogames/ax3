package ax3.filters;

class AddRequiredParens extends AbstractFilter {
	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch (e.kind) {
			case TEBinop(a, op, b):
				var ep = getPrecedence(e);
				var ap = getPrecedence(a);
				if (ep < ap)
					e.with(kind = TEBinop(addParens(a), op, b))
				else
					e;
			case _:
				e;
		}
	}

	static function getPrecedence(e:TExpr):Int
		return switch e.kind {
			case TEParens(_)
				| TEObjectDecl(_)
				| TEArrayAccess(_)
				| TEXmlAttrExpr(_)
				| TEXmlChild(_)
				| TEXmlAttr(_)
				| TEXmlDescend(_)
				| TEArrayDecl(_)
				| TEVectorDecl(_)
				| TEField(_)
				| TECall(_)
				| TECast(_)
				| TELocalFunction(_)
				| TELiteral(_)
				| TELocal(_)
				| TEBuiltin(_)
				| TEDeclRef(_)
				| TENew(_)
				| TECondCompValue(_)
				: 1;

			case TEPostUnop(_): 2;

			case TEPreUnop(_)
				| TEDelete(_)
				: 3;

			case TEBinop(_, OpDiv(_) | OpMul(_) | OpMod(_), _): 4;

			case TEBinop(_, OpAdd(_) | OpSub(_), _): 5;

			case TEBinop(_, OpShl(_) | OpShr(_) | OpUshr(_), _): 6;

			case TEBinop(_, OpGt(_) | OpGte(_) | OpLt(_) | OpLte(_) | OpIn(_), _) | TEIs(_) | TEAs(_): 7;

			case TEBinop(_, OpEquals(_) | OpNotEquals(_) | OpStrictEquals(_) | OpNotStrictEquals(_), _): 8;

			case TEBinop(_, OpBitAnd(_), _): 9;

			case TEBinop(_, OpBitXor(_), _): 10;

			case TEBinop(_, OpBitOr(_), _): 11;

			case TEBinop(_, OpAnd(_), _): 12;

			case TEBinop(_, OpOr(_), _): 13;

			case TETernary(_): 14;

			case TEBinop(_, OpAssign(_) | OpAssignAdd(_) | OpAssignSub(_) | OpAssignMul(_) | OpAssignDiv(_) | OpAssignMod(_) | OpAssignAnd(_) | OpAssignOr(_) | OpAssignBitAnd(_) | OpAssignBitOr(_) | OpAssignBitXor(_) | OpAssignShl(_) | OpAssignShr(_) | OpAssignUshr(_), _): 15;

			case TEBinop(_, OpComma(_), _): 16;

			// statements
			case TEReturn(_): 100;
			case TEThrow(_): 100;
			case TEBreak(_): 100;
			case TEContinue(_): 100;
			case TEVars(_): 100;
			case TEBlock(_): 100;
			case TETry(_): 100;
			case TEVector(_): 100;
			case TEIf(_): 100;
			case TEWhile(_): 100;
			case TEDoWhile(_): 100;
			case TEFor(_): 100;
			case TEForIn(_): 100;
			case TEForEach(_): 100;
			case TESwitch(_): 100;
			case TECondCompBlock(_): 100;
			case TEUseNamespace(_): 100;
	}
}
