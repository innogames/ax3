package ax3;

import ax3.TypedTree;
using ax3.WithMacro;

class TypedTreeTools {
	static function mapArrayDecl(f:TExpr->TExpr, a:TArrayDecl):TArrayDecl {
		return a.with(elements = [for (e in a.elements) e.with(expr = f(e.expr))]);
	}

	static function mapBlock(f:TExpr->TExpr, b:TBlock):TBlock {
		return b.with(exprs = [for (e in b.exprs) e.with(expr = f(e.expr))]);
	}

	static function mapBlockExpr(f:TExpr->TExpr, e:TBlockExpr):TBlockExpr {
		return e.with(expr = f(e.expr));
	}

	public static function mapExpr(f:TExpr->TExpr, e1:TExpr):TExpr {
		return switch (e1.kind) {
			case TEVector(_) | TELiteral(_) | TEUseNamespace(_) | TELocal(_) | TEBuiltin(_) | TEDeclRef(_) | TEReturn(_, null) | TEBreak(_) | TEContinue(_) | TECondCompValue(_):
				e1;

			case TECast(c):
				e1.with(kind = TECast(c.with(e = f(c.e))));

			case TEParens(openParen, e, closeParen):
				e1.with(kind = TEParens(openParen, f(e), closeParen));

			case TEField(obj, fieldName, fieldToken):
				var obj = switch (obj.kind) {
					case TOExplicit(dot, e):
						obj.with(kind = TOExplicit(dot, f(e)));
					case TOImplicitThis(_) | TOImplicitClass(_):
						obj;
				};
				e1.with(kind = TEField(obj, fieldName, fieldToken));

			case TECall(eobj, args):
				var eobj = f(eobj);
				var args = args.with(args = [for (arg in args.args) arg.with(expr = f(arg.expr))]);
				e1.with(kind = TECall(eobj, args));

			case TEArrayDecl(a):
				e1.with(kind = TEArrayDecl(mapArrayDecl(f, a)));

			case TEReturn(keyword, e):
				e1.with(kind = TEReturn(keyword, f(e)));

			case TEThrow(keyword, e):
				e1.with(kind = TEThrow(keyword, f(e)));

			case TEDelete(keyword, e):
				e1.with(kind = TEDelete(keyword, f(e)));

			case TEBlock(block):
				e1.with(kind = TEBlock(mapBlock(f, block)));

			case TEIf(e):
				e1.with(
					kind = TEIf(e.with(
						econd = f(e.econd),
						ethen = f(e.ethen),
						eelse = if (e.eelse == null) null else e.eelse.with(expr = f(e.eelse.expr))
					))
				);

			case TETry(t):
				e1.with(
					kind = TETry(t.with(
						expr = f(t.expr),
						catches = [for (c in t.catches) c.with(expr = f(c.expr))]
					))
				);

			case TELocalFunction(fun):
				e1.with(
					kind = TELocalFunction(fun.with(
						fun = fun.fun.with(block = mapBlock(f, fun.fun.block))
					))
				);

			case TEVectorDecl(v):
				e1.with(kind = TEVectorDecl(v.with(elements = mapArrayDecl(f, v.elements))));

			case TEArrayAccess(a):
				e1.with(kind =
					TEArrayAccess(a.with(
						eobj = f(a.eobj),
						eindex = f(a.eindex)
					))
				);

			case TEVars(kind, vars):
				e1.with(kind = TEVars(kind, [
					for (v in vars) {
						if (v.init == null) v else v.with(init = v.init.with(expr = f(v.init.expr)));
					}
				]));


			case TEObjectDecl(o):
				e1.with(kind = TEObjectDecl(o.with(
					fields = [for (field in o.fields) field.with(expr = f(field.expr))]
				)));

			case TETernary(t):
				e1.with(kind = TETernary(t.with(
					econd = f(t.econd),
					ethen = f(t.ethen),
					eelse = f(t.eelse)
				)));


			case TEWhile(w):
				e1.with(kind = TEWhile(w.with(
					cond = f(w.cond),
					body = f(w.body)
				)));

			case TEDoWhile(w):
				e1.with(kind = TEDoWhile(w.with(
					body = f(w.body),
					cond = f(w.cond)
				)));

			case TEFor(l):
				e1.with(kind = TEFor(l.with(
					einit = if (l.einit == null) null else f(l.einit),
					econd = if (l.econd == null) null else f(l.econd),
					eincr = if (l.eincr == null) null else f(l.eincr),
					body = f(l.body)
				)));

			case TEForIn(f): e1;

			case TEForEach(f): e1;

			case TEBinop(a, op, b):
				e1.with(kind = TEBinop(f(a), op, f(b)));

			case TEPreUnop(op, e):
				e1.with(kind = TEPreUnop(op, f(e)));

			case TEPostUnop(e, op):
				e1.with(kind = TEPostUnop(f(e), op));

			case TEComma(a, comma, b):
				e1.with(kind = TEComma(f(a), comma, f(b)));

			case TEIs(e, keyword, etype): e1;

			case TEAs(e, keyword, type): e1;

			case TESwitch(s): e1;

			case TENew(keyword, eclass, args): e1;

			case TECondCompBlock(v, expr): e1;

			case TEXmlAttr(x): e1;

			case TEXmlAttrExpr(x): e1;

			case TEXmlDescend(x): e1;
		}
	}
}
