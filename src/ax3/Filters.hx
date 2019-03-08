package ax3;

import ax3.TypedTree;
import ax3.Structure;
using ax3.WithMacro;

class Filters {

	static function f(e:TExpr):TExpr {
		return e;
	}

	static function processBlock(b:TBlock) {
		for (i in 0...b.exprs.length) {
			b.exprs[i].expr = processExpr(b.exprs[i].expr);
		}
	}

	static function processBlockExpr(e:TBlockExpr):TBlockExpr {
		return e.with(expr = f(e.expr));
	}

	static function processExpr(e1:TExpr):TExpr {
		return switch (e1.kind) {
			case TELiteral(_) | TEUseNamespace(_) | TELocal(_) | TEBuiltin(_) | TEDeclRef(_) | TEReturn(_, null) | TEBreak(_) | TEContinue(_) | TECondCompValue(_):
				e1;

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
				e1.with(
					kind = TEArrayDecl(a.with(
						elements = [
							for (e in a.elements)
								e.with(expr = f(e.expr))
						]
					))
				);

			case TEReturn(keyword, e):
				e1.with(kind = TEReturn(keyword, f(e)));

			case TEThrow(keyword, e):
				e1.with(kind = TEThrow(keyword, f(e)));

			case TEDelete(keyword, e):
				e1.with(kind = TEDelete(keyword, f(e)));

			case TEBlock(block):
				e1.with(
					kind = TEBlock(block.with(
						exprs = [for (e in block.exprs) processBlockExpr(e)]
					))
				);

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

			case TELocalFunction(f): e1;

			case TEVectorDecl(v): e1;
			case TEVars(kind, v): e1;
			case TEObjectDecl(o): e1;
			case TEArrayAccess(a): e1;
			case TEVector(syntax, type): e1;
			case TETernary(e): e1;
			case TEWhile(w): e1;
			case TEDoWhile(w): e1;
			case TEFor(f): e1;
			case TEForIn(f): e1;
			case TEForEach(f): e1;
			case TEBinop(a, op, b): e1;
			case TEPreUnop(op, e): e1.with(kind = TEPreUnop(op, f(e)));
			case TEPostUnop(e, op): e1.with(kind = TEPostUnop(f(e), op));
			case TEComma(a, comma, b): e1.with(kind = TEComma(f(a), comma, f(b)));
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

	static function processClass(c:TClassDecl) {
		for (m in c.members) {
			switch (m) {
				case TMField(f):
					switch (f.kind) {
						case TFVar(v): processVars(v.vars);
						case TFFun(f): processFunction(f.fun);
						case TFGetter(f) | TFSetter(f): processFunction(f.fun);
					}
				case TMStaticInit(b): processBlock(b);
				case TMUseNamespace(_):
				case TMCondCompBegin(_):
				case TMCondCompEnd(_):
			}
		}
	}

	static function processVars(vars:Array<TVarFieldDecl>) {
		for (v in vars) {
			if (v.init != null) {
				v.init.expr = processExpr(v.init.expr);
			}
		}
	}

	static function processFunction(f:TFunction) {
		processBlock(f.block);
	}

	static function processDecl(decl:TDecl) {
		switch (decl) {
			case TDClass(c): processClass(c);
			case TDVar(v): processVars(v.vars);
			case TDFunction(f): processFunction(f.fun);
			case TDInterface(_):
			case TDNamespace(_):
		}
	}

	public static function run(structure:Structure, modules:Array<TModule>) {
		for (mod in modules) {
			processDecl(mod.pack.decl);
			for (decl in mod.privateDecls) {
				processDecl(decl);
			}
		}
	}
}
