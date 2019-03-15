package ax3;

import ax3.ParseTree;
import ax3.TypedTree;
import ax3.Token;
using ax3.WithMacro;

class TypedTreeTools {
	public static function exprPos(e:TExpr):Int {
		return switch e.kind {
			case TEParens(openParen, _): openParen.pos;
			case TELocalFunction(f): f.syntax.keyword.pos;
			case TELiteral(TLThis(t) | TLSuper(t) | TLBool(t) | TLNull(t) | TLUndefined(t) | TLInt(t) | TLNumber(t) | TLString(t) | TLRegExp(t)): t.pos;
			case TELocal(t, _): t.pos;
			case TEField(_, _, fieldToken): fieldToken.pos;
			case TEBuiltin(t, _): t.pos;
			case TEDeclRef(path, _): path.first.pos;
			case TECall(_, args): args.openParen.pos;
			case TECast(c): c.syntax.path.first.pos;
			case TEArrayDecl(a): a.syntax.openBracket.pos;
			case TEVectorDecl(v): v.syntax.newKeyword.pos;
			case TEReturn(keyword, _) | TEThrow(keyword, _) | TEDelete(keyword, _) | TEBreak(keyword) | TEContinue(keyword): keyword.pos;
			case TEVars(VVar(t) | VConst(t), _): t.pos;
			case TEObjectDecl(o): o.syntax.openBrace.pos;
			case TEArrayAccess(a): a.syntax.openBracket.pos;
			case TEBlock(block): block.syntax.openBrace.pos;
			case TETry(t): t.keyword.pos;
			case TEVector(syntax, _): syntax.name.pos;
			case TETernary(t): t.syntax.question.pos;
			case TEIf(i): i.syntax.keyword.pos;
			case TEWhile(w): w.syntax.keyword.pos;
			case TEDoWhile(w): w.syntax.doKeyword.pos;
			case TEFor(f): f.syntax.keyword.pos;
			case TEForIn(f): f.syntax.forKeyword.pos;
			case TEForEach(f): f.syntax.forKeyword.pos;
			case TEBinop(a, OpAdd(t) | OpSub(t) | OpDiv(t) | OpMul(t) | OpMod(t) | OpAssign(t) | OpAssignAdd(t) | OpAssignSub(t) | OpAssignMul(t) | OpAssignDiv(t) | OpAssignMod(t) | OpAssignAnd(t) | OpAssignOr(t) | OpAssignBitAnd(t) | OpAssignBitOr(t) | OpAssignBitXor(t) | OpAssignShl(t) | OpAssignShr(t) | OpAssignUshr(t) | OpEquals(t) | OpNotEquals(t) | OpStrictEquals(t) | OpNotStrictEquals(t) | OpGt(t) | OpGte(t) | OpLt(t) | OpLte(t) | OpIn(t) | OpIs(t) | OpAnd(t) | OpOr(t) | OpShl(t) | OpShr(t) | OpUshr(t) | OpBitAnd(t) | OpBitOr(t) | OpBitXor(t) | OpComma(t), b): t.pos;
			case TEPreUnop(PreNot(t) | PreNeg(t) | PreIncr(t) | PreDecr(t) | PreBitNeg(t), e): t.pos;
			case TEPostUnop(e, PostIncr(t) | PostDecr(t)): t.pos;
			case TEAs(e, keyword, type): keyword.pos;
			case TESwitch(s): s.syntax.keyword.pos;
			case TENew(keyword, eclass, args): keyword.pos;
			case TECondCompValue(v): v.syntax.ns.pos;
			case TECondCompBlock(v, expr): v.syntax.ns.pos;
			case TEXmlChild(x): x.syntax.dot.pos;
			case TEXmlAttr(x): x.syntax.dot.pos;
			case TEXmlAttrExpr(x): x.syntax.openBracket.pos;
			case TEXmlDescend(x): x.syntax.dotDot.pos;
			case TEUseNamespace(ns): ns.useKeyword.pos;
		}
	}

	public static function addParens(e:TExpr):TExpr {
		return switch (e.kind) {
			case TEParens(_):
				e;
			case _:
				var lead = removeLeadingTrivia(e);
				var trail = removeTrailingTrivia(e);
				var openParen = new Token(0, TkParenOpen, "(", lead, []);
				var closeParen = new Token(0, TkParenClose, ")", [], trail);
				e.with(
					kind = TEParens(openParen, e, closeParen),
					type = e.expectedType
				);
		}
	}

	/** Is it safe to repeat this expression a couple times :) **/
	public static function canBeRepeated(e:TExpr):Bool {
		return switch (e.kind) {
			case TEParens(_, e, _): canBeRepeated(e);

			case TELocal(_) | TELiteral(_) | TEBuiltin(_) | TEDeclRef(_): true;

			// TODO: check whether it's a getter
			case TEField({kind: TOExplicit(_, e)}, _, _): canBeRepeated(e);
			case TEField({kind: TOImplicitThis(_) | TOImplicitClass(_)}, _, _): true;

			case TEArrayAccess(a): canBeRepeated(a.eobj) && canBeRepeated(a.eindex);

			case _: false;
		}
	}

	public static inline function mk(kind:TExprKind, type:TType, expectedType:TType):TExpr {
		return {kind: kind, type: type, expectedType: expectedType};
	}

	public static inline function mkNullExpr(t = TTAny, ?lead, ?trail):TExpr {
		return mk(TELiteral(TLNull(new Token(0, TkIdent, "null", if (lead != null) lead else [], if (trail != null) trail else []))), t, t);
	}

	public static function skipParens(e:TExpr):TExpr {
		return switch e.kind {
			case TEParens(_, einner, _): einner;
			case _: e;
		};
	}

	/** remove and return the leading trivia of an expression **/
	public static function removeLeadingTrivia(e:TExpr):Array<Trivia> {
		function r(token:Token) {
			var trivia = token.leadTrivia;
			token.leadTrivia = [];
			return trivia;
		}

		inline function fromDotPath(p:DotPath) {
			return r(p.first);
		}

		function fromSyntaxType(t:SyntaxType) {
			return switch (t) {
				case TAny(star): r(star);
				case TPath(path): fromDotPath(path);
				case TVector(v): r(v.t.gt);
			}
		}

		return switch e.kind {
			case TEParens(openParen, _, _): r(openParen);
			case TELocalFunction(f): r(f.syntax.keyword);
			case TELiteral(TLThis(t) | TLSuper(t)| TLBool(t)| TLNull(t)| TLUndefined(t)| TLInt(t)| TLNumber(t)| TLString(t)| TLRegExp(t)): r(t);
			case TELocal(t, _): r(t);
			case TEField({kind: TOImplicitThis(_) | TOImplicitClass(_)}, _, fieldToken): r(fieldToken);
			case TEField({kind: TOExplicit(_, obj)}, _, _): removeLeadingTrivia(obj);
			case TEBuiltin(t, _): r(t);
			case TEDeclRef(path, _): fromDotPath(path);
			case TECall(eobj, _): removeLeadingTrivia(eobj);
			case TECast(c): fromDotPath(c.syntax.path);
			case TEArrayDecl(a): r(a.syntax.openBracket);
			case TEVectorDecl(v): r(v.syntax.newKeyword);
			case TEReturn(keyword, _) | TEThrow(keyword, _) | TEDelete(keyword, _) | TEBreak(keyword) | TEContinue(keyword): r(keyword);
			case TEVars(VVar(t) | VConst(t), _): r(t);
			case TEObjectDecl(o): r(o.syntax.openBrace);
			case TEArrayAccess(a): removeLeadingTrivia(a.eobj);
			case TEBlock(block): r(block.syntax.openBrace);
			case TETry(t): r(t.keyword);
			case TEVector(syntax, _): r(syntax.name);
			case TETernary(t): removeLeadingTrivia(t.econd);
			case TEIf(i): r(i.syntax.keyword);
			case TEWhile(w): r(w.syntax.keyword);
			case TEDoWhile(w): r(w.syntax.doKeyword);
			case TEFor(f): r(f.syntax.keyword);
			case TEForIn(f): r(f.syntax.forKeyword);
			case TEForEach(f): r(f.syntax.forKeyword);
			case TEBinop(a, _, _): removeLeadingTrivia(a);
			case TEPreUnop(PreNot(t) | PreNeg(t) | PreIncr(t) | PreDecr(t) | PreBitNeg(t), _): r(t);
			case TEPostUnop(e, _): removeLeadingTrivia(e);
			case TEAs(e, _, _): removeLeadingTrivia(e);
			case TESwitch(s): r(s.syntax.keyword);
			case TENew(keyword, _, _): r(keyword);
			case TECondCompValue(v) | TECondCompBlock(v, _): r(v.syntax.ns);
			case TEXmlChild(x): removeLeadingTrivia(x.eobj);
			case TEXmlAttr(x): removeLeadingTrivia(x.eobj);
			case TEXmlAttrExpr(x): removeLeadingTrivia(x.eobj);
			case TEXmlDescend(x): removeLeadingTrivia(x.eobj);
			case TEUseNamespace(ns): r(ns.useKeyword);
		}
	}

	/** remove and return the trailing trivia of an expression **/
	public static function removeTrailingTrivia(e:TExpr):Array<Trivia> {
		function r(token:Token) {
			var trivia = token.trailTrivia;
			token.trailTrivia = [];
			return trivia;
		}

		function fromDotPath(p:DotPath) {
			return
				if (p.rest.length == 0) r(p.first)
				else r(p.rest[p.rest.length - 1].element);
		}

		function fromSyntaxType(t:SyntaxType) {
			return switch (t) {
				case TAny(star): r(star);
				case TPath(path): fromDotPath(path);
				case TVector(v): r(v.t.gt);
			}
		}

		return switch e.kind {
			case TEParens(_, _, closeParen): r(closeParen);
			case TELocalFunction(f): removeTrailingTrivia(f.fun.expr);
			case TELiteral(TLThis(t) | TLSuper(t)| TLBool(t)| TLNull(t)| TLUndefined(t)| TLInt(t)| TLNumber(t)| TLString(t)| TLRegExp(t)): r(t);
			case TELocal(t, _): r(t);
			case TEField(_, _, t): r(t);
			case TEBuiltin(t, _): r(t);
			case TEDeclRef(path, _): fromDotPath(path);
			case TECall(_, args): r(args.closeParen);
			case TECast(c): r(c.syntax.closeParen);
			case TEArrayDecl(a): r(a.syntax.closeBracket);
			case TEVectorDecl(v): r(v.elements.syntax.closeBracket);
			case TEBreak(keyword) | TEContinue(keyword) | TEReturn(keyword, null): r(keyword);
			case TEReturn(_, e) | TEThrow(_, e) | TEDelete(_, e): removeTrailingTrivia(e);
			case TEObjectDecl(o): r(o.syntax.closeBrace);
			case TEArrayAccess(a): r(a.syntax.closeBracket);
			case TEBlock(block): r(block.syntax.closeBrace);
			case TETry(t): removeTrailingTrivia(t.catches[t.catches.length - 1].expr);
			case TEIf(i): removeTrailingTrivia(if (i.eelse == null) i.ethen else i.eelse.expr);
			case TEVars(_, vars):
				var v = vars[vars.length - 1];
				if (v.init != null) removeTrailingTrivia(v.init.expr)
				else if (v.syntax.type != null) fromSyntaxType(v.syntax.type.type)
				else r(v.syntax.name);
			case TEVector(syntax, type): r(syntax.t.gt);
			case TETernary(t): removeTrailingTrivia(t.eelse);
			case TEWhile(w): removeTrailingTrivia(w.body);
			case TEDoWhile(w): r(w.syntax.closeParen);
			case TEFor(f): removeTrailingTrivia(f.body);
			case TEForIn(f): removeTrailingTrivia(f.body);
			case TEForEach(f): removeTrailingTrivia(f.body);
			case TEBinop(_, _, b): removeTrailingTrivia(b);
			case TEPreUnop(_, e): removeTrailingTrivia(e);
			case TEPostUnop(_, PostIncr(t) | PostDecr(t)): r(t);
			case TEAs(_, _, type): fromSyntaxType(type.syntax);
			case TESwitch(s): r(s.syntax.closeBrace);
			case TENew(_, eclass, args):
				if (args == null) removeTrailingTrivia(eclass)
				else r(args.closeParen);
			case TECondCompValue(v): r(v.syntax.name);
			case TECondCompBlock(_, expr): removeTrailingTrivia(expr);
			case TEXmlChild(x): r(x.syntax.name);
			case TEXmlAttr(x): r(x.syntax.name);
			case TEXmlAttrExpr(x): r(x.syntax.closeBracket);
			case TEXmlDescend(x): r(x.syntax.name);
			case TEUseNamespace(ns): r(ns.name);
		}
	}

	public static function mapExpr(f:TExpr->TExpr, e1:TExpr):TExpr {
		return switch (e1.kind) {
			case TEVector(_) | TELiteral(_) | TEUseNamespace(_) | TELocal(_) | TEBuiltin(_) | TEDeclRef(_) | TEReturn(_, null) | TEBreak(_) | TEContinue(_) | TECondCompValue(_):
				e1;

			case TECast(c):
				e1.with(kind = TECast(c.with(expr = f(c.expr))));

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
				e1.with(kind = TECall(f(eobj), mapCallArgs(f, args)));

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
				e1.with(kind = TEIf(e.with(
					econd = f(e.econd),
					ethen = f(e.ethen),
					eelse = if (e.eelse == null) null else e.eelse.with(expr = f(e.eelse.expr))
				)));

			case TETry(t):
				e1.with(kind = TETry(t.with(
					expr = f(t.expr),
					catches = [for (c in t.catches) c.with(expr = f(c.expr))]
				)));

			case TELocalFunction(fun):
				e1.with(kind = TELocalFunction(fun.with(
					fun = fun.fun.with(expr = f(fun.fun.expr))
				)));

			case TEVectorDecl(v):
				e1.with(kind = TEVectorDecl(v.with(elements = mapArrayDecl(f, v.elements))));

			case TEArrayAccess(a):
				e1.with(kind = TEArrayAccess(a.with(
					eobj = f(a.eobj),
					eindex = f(a.eindex)
				)));

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

			case TEForIn(l):
				e1.with(kind = TEForIn(l.with(
					iter = l.iter.with(eit = f(l.iter.eit), eobj = f(l.iter.eobj)),
					body = f(l.body)
				)));

			case TEForEach(l):
				e1.with(kind = TEForEach(l.with(
					iter = l.iter.with(eit = f(l.iter.eit), eobj = f(l.iter.eobj)),
					body = f(l.body)
				)));

			case TEBinop(a, op, b):
				e1.with(kind = TEBinop(f(a), op, f(b)));

			case TEPreUnop(op, e):
				e1.with(kind = TEPreUnop(op, f(e)));

			case TEPostUnop(e, op):
				e1.with(kind = TEPostUnop(f(e), op));

			case TEAs(e, keyword, type):
				e1.with(kind = TEAs(f(e), keyword, type));

			case TESwitch(s):
				e1.with(kind = TESwitch(s.with(
					subj = f(s.subj),
					cases = [
						for (c in s.cases)
							c.with(value = f(c.value), body = mapBlockExprs(f, c.body))
					],
					def = if (s.def == null) null else s.def.with(body = mapBlockExprs(f, s.def.body))
				)));

			case TENew(keyword, eclass, args):
				e1.with(kind = TENew(keyword, f(eclass), if (args == null) null else mapCallArgs(f, args)));

			case TECondCompBlock(v, expr):
				e1.with(kind = TECondCompBlock(v, f(expr)));

			case TEXmlAttr(x):
				e1.with(kind = TEXmlAttr(x.with(eobj = f(x.eobj))));

			case TEXmlChild(x):
				e1.with(kind = TEXmlChild(x.with(eobj = f(x.eobj))));

			case TEXmlAttrExpr(x):
				e1.with(kind = TEXmlAttrExpr(x.with(
					eobj = f(x.eobj),
					eattr = f(x.eattr)
				)));

			case TEXmlDescend(x):
				e1.with(kind = TEXmlDescend(x.with(eobj = f(x.eobj))));
		}
	}

	static function mapArrayDecl(f:TExpr->TExpr, a:TArrayDecl):TArrayDecl {
		return a.with(elements = [for (e in a.elements) e.with(expr = f(e.expr))]);
	}

	static function mapCallArgs(f:TExpr->TExpr, a:TCallArgs):TCallArgs {
		return a.with(args = [for (arg in a.args) arg.with(expr = f(arg.expr))]);
	}

	static function mapBlock(f:TExpr->TExpr, b:TBlock):TBlock {
		return b.with(exprs = mapBlockExprs(f, b.exprs));
	}

	static function mapBlockExprs(f:TExpr->TExpr, exprs:Array<TBlockExpr>):Array<TBlockExpr> {
		return [for (e in exprs) e.with(expr = f(e.expr))];
	}
}
