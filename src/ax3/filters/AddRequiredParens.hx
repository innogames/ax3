package ax3.filters;

class AddRequiredParens extends AbstractFilter {
	override function processExpr(e:TExpr):TExpr {
		return loop(e, 100);
	}

	static function loop(e:TExpr, p:Int):TExpr {
		inline function maybeWrap(e:TExpr, p2:Int) {
			return if (p < p2) addParens(e) else e;
		}

		inline function binop(a, op, b, p) {
			return maybeWrap(e.with(kind = TEBinop(loop(a, p), op, loop(b, p))), p);
		}

		return switch e.kind {
			case TEHaxeIntIter(_) | TEHaxeRetype(_) | TEParens(_) | TEObjectDecl(_) | TEArrayAccess(_) | TEXmlAttrExpr(_) | TEXmlChild(_) | TEXmlAttr(_) | TEXmlDescend(_) | TEArrayDecl(_) | TEVectorDecl(_) | TEField(_) | TECall(_) | TECast(_) | TELocalFunction(_) | TELiteral(_) | TELocal(_) | TEBuiltin(_) | TEDeclRef(_) | TENew(_) | TECondCompValue(_):
				mapExpr(loop.bind(_, 100), e);

			case TEPostUnop(e2, op):
				maybeWrap(e.with(kind = TEPostUnop(loop(e2, 2), op)), 2);

			case TEPreUnop(op, e2):
				maybeWrap(e.with(kind = TEPreUnop(op, loop(e2, 3))), 3);

			case TEDelete(kwd, e2):
				maybeWrap(e.with(kind = TEDelete(kwd, loop(e2, 3))), 3);

			case TEBinop(a, op = OpDiv(_) | OpMul(_) | OpMod(_), b):
				binop(a, op, b, 4);

			case TEBinop(a, op = OpAdd(_) | OpSub(_), b):
				binop(a, op, b, 5);

			case TEBinop(a, op = OpShl(_) | OpShr(_) | OpUshr(_), b):
				binop(a, op, b, 6);

			case TEBinop(a, op = OpGt(_) | OpGte(_) | OpLt(_) | OpLte(_) | OpIn(_) | OpIs(_), b):
				binop(a, op, b, 7);

			case TEAs(e2, kwd, type):
				maybeWrap(e.with(kind = TEAs(loop(e2, 7), kwd, type)), 7);

			case TEBinop(a, op = OpEquals(_) | OpNotEquals(_) | OpStrictEquals(_) | OpNotStrictEquals(_), b):
				binop(a, op, b, 8);

			case TEBinop(a, op = OpBitAnd(_), b):
				binop(a, op, b, 9);

			case TEBinop(a, op = OpBitXor(_), b):
				binop(a, op, b, 10);

			case TEBinop(a, op = OpBitOr(_), b):
				binop(a, op, b, 11);

			case TEBinop(a, op = OpAnd(_), b):
				binop(a, op, b, 12);

			case TEBinop(a, op = OpOr(_), b):
				binop(a, op, b, 13);

			case TETernary(t):
				e = e.with(kind = TETernary(t.with(
					econd = loop(t.econd, 14),
					ethen = loop(t.ethen, 14),
					eelse = loop(t.eelse, 14)
				)));
				maybeWrap(e, 14);

			case TEBinop(a, op = OpAssign(_) | OpAssignOp(_), b):
				binop(a, op, b, 15);

			case TEBinop(a, op = OpComma(_), b):
				binop(a, op, b, 16);

			// statements
			case TEReturn(_): mapExpr(loop.bind(_, 100), e);
			case TETypeof(_): mapExpr(loop.bind(_, 100), e);
			case TEThrow(_): mapExpr(loop.bind(_, 100), e);
			case TEBreak(_): mapExpr(loop.bind(_, 100), e);
			case TEContinue(_): mapExpr(loop.bind(_, 100), e);
			case TEVars(_): mapExpr(loop.bind(_, 100), e);
			case TEBlock(_): mapExpr(loop.bind(_, 100), e);
			case TETry(_): mapExpr(loop.bind(_, 100), e);
			case TEVector(_): mapExpr(loop.bind(_, 100), e);
			case TEIf(_): mapExpr(loop.bind(_, 100), e);
			case TEWhile(_): mapExpr(loop.bind(_, 100), e);
			case TEDoWhile(_): mapExpr(loop.bind(_, 100), e);
			case TEHaxeFor(_): mapExpr(loop.bind(_, 100), e);
			case TEFor(_): mapExpr(loop.bind(_, 100), e);
			case TEForIn(_): mapExpr(loop.bind(_, 100), e);
			case TEForEach(_): mapExpr(loop.bind(_, 100), e);
			case TESwitch(_): mapExpr(loop.bind(_, 100), e);
			case TECondCompBlock(_): mapExpr(loop.bind(_, 100), e);
			case TEUseNamespace(_): mapExpr(loop.bind(_, 100), e);
		}
	}
}
