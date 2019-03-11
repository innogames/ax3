package ax3;

import ax3.Token.Trivia;
import ax3.TypedTree;
import ax3.TypedTreeTools.mk;
import ax3.TypedTreeTools.mapExpr;
import ax3.Structure;
using ax3.WithMacro;

class Filters {
	static function mkTokenWithSpaces(kind, text) {
		return new Token(0, kind, text, [new Trivia(TrWhitespace, " ")], [new Trivia(TrWhitespace, " ")]);
	}

	static inline function mkEqualsEqualsToken() {
		return mkTokenWithSpaces(TkEqualsEquals, "==");
	}

	static inline function mkNotEqualsToken() {
		return mkTokenWithSpaces(TkExclamationEquals, "!=");
	}

	static inline function mkNullExpr(t = TTAny) {
		return mk(TELiteral(TLNull(new Token(0, TkIdent, "null", [], []))), t);
	}

	static function debugExpr(prefix = "", e:TExpr) {
		trace(prefix, {var g = new GenAS3(); @:privateAccess g.printExpr(e); g.toString();}, e.type.getName());
	}

	static function coerceToBool(e:TExpr):TExpr {
		function modify(e:TExpr):TExpr {
			e = coerceToBool(e);
			return switch (e.type) {
				case TTBoolean:
					// already a boolean - nothing to do
					e;
				case TTInst(_) | TTFunction | TTFun(_):
					// instances should be checked for != null
					mk(TEBinop(e, OpNotEquals(mkNotEqualsToken()), mkNullExpr()), TTBoolean);
				case _:
					// something temporary
					var comment = new Trivia(TrBlockComment, "/*TODO*/");
					return mk(TELiteral(TLBool(new Token(0, TkIdent, "false", [comment], []))), TTBoolean);
			}
			return e;
		}

		return switch (e.kind) {
			case TEBinop(a, op = OpAnd(_) | OpOr(_), b):
				e.with(kind = TEBinop(modify(a), op, modify(b)), type = TTBoolean);
			case TEIf(i):
				e.with(kind = TEIf(i.with(
					econd = modify(i.econd),
					// don't forget to recurse into then and else exprs
					ethen = coerceToBool(i.ethen),
					eelse = if (i.eelse == null) null else i.eelse.with(expr = coerceToBool(i.eelse.expr))
				)));
			case _:
				mapExpr(coerceToBool, e);
		}
	}

	static function processClass(f:TExpr->TExpr, c:TClassDecl) {
		for (m in c.members) {
			switch (m) {
				case TMField(field):
					switch (field.kind) {
						case TFVar(v): processVars(f, v.vars);
						case TFFun(field): processFunction(f, field.fun);
						case TFGetter(field) | TFSetter(field): processFunction(f, field.fun);
					}
				case TMStaticInit(b): processBlock(f, b);
				case TMUseNamespace(_):
				case TMCondCompBegin(_):
				case TMCondCompEnd(_):
			}
		}
	}

	static function processVars(f:TExpr->TExpr, vars:Array<TVarFieldDecl>) {
		for (v in vars) {
			if (v.init != null) {
				v.init.expr = mapExpr(f, v.init.expr);
			}
		}
	}

	static function processFunction(f:TExpr->TExpr, fun:TFunction) {
		processBlock(f, fun.block);
	}

	static function processBlock(f:TExpr->TExpr, b:TBlock) {
		for (i in 0...b.exprs.length) {
			b.exprs[i].expr = f(b.exprs[i].expr);
		}
	}

	static function processDecl(f:TExpr->TExpr, decl:TDecl) {
		switch (decl) {
			case TDClass(c): processClass(f, c);
			case TDVar(v): processVars(f, v.vars);
			case TDFunction(fun): processFunction(f, fun.fun);
			case TDInterface(_):
			case TDNamespace(_):
		}
	}

	public static function run(structure:Structure, modules:Array<TModule>) {
		for (mod in modules) {
			processDecl(coerceToBool, mod.pack.decl);
			for (decl in mod.privateDecls) {
				processDecl(coerceToBool, decl);
			}
		}
	}
}
