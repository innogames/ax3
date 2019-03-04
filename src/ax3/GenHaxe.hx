package ax3;

import ax3.ParseTree.VarInit;
import ax3.ParseTree.PreUnop;
import ax3.TypedTree;

class GenHaxe {
	var buf:StringBuf;

	public function new() {
		buf = new StringBuf();
	}

	public function writeModule(m:TModule) {

		printTextWithTrivia("package", m.packDecl.keyword);
		if (m.packDecl.name != null) printDotPath(m.packDecl.name);
		buf.add(";"); // TODO: move semicolon before the newline (if any)

		printTextWithTrivia("", m.packDecl.openBrace);

		printTypeDecl(m.mainType);

		printTextWithTrivia("", m.packDecl.closeBrace);

		printTrivia(m.syntax.eof.leadTrivia);
	}

	function printTypeDecl(t:TDecl) {
		switch (t) {
			case TDClass(c):
				printClassDecl(c);
			case TDInterface(i):
				printInterfaceDecl(i);
		}
	}

	function printClassDecl(c:TClass) {
		for (m in c.syntax.modifiers) {
			switch (m) {
				case DMPublic(t): printTextWithTrivia("/*public*/", t);
				case DMInternal(t): printTextWithTrivia("/*internal*/", t);
				case DMFinal(t): printTextWithTrivia("final", t);
				case DMDynamic(t): printTextWithTrivia("/*dynamic*/", t);
			}
		}
		printTextWithTrivia("class", c.syntax.keyword);
		printIdent(c.syntax.name);
		if (c.syntax.extend != null) {
			printTextWithTrivia("extends", c.syntax.extend.keyword);
			printDotPath(c.syntax.extend.path);
		}
		if (c.syntax.implement != null) {
			printTextWithTrivia("implements", c.syntax.implement.keyword);
			printSeparated(c.syntax.implement.paths, printDotPath, function(sep) {
				printTextWithTrivia(" implements", sep);
			});
		}
		printTextWithTrivia("{", c.syntax.openBrace);
		for (field in c.fields) {
			printClassField(field);
		}
		printTextWithTrivia("}", c.syntax.closeBrace);
	}

	function printClassField(f:TClassField) {
		for (m in f.syntax.modifiers) {
			switch (m) {
				case FMPublic(t): printTextWithTrivia("public", t);
				case FMPrivate(t): printTextWithTrivia("private", t);
				case FMProtected(t): printTextWithTrivia("private", t);
				case FMInternal(t): printTextWithTrivia("/*internal*/public", t);
				case FMOverride(t): printTextWithTrivia("override", t);
				case FMStatic(t): printTextWithTrivia("static", t);
				case FMFinal(t): printTextWithTrivia("final", t);
			}
		}
		switch f.kind {
			case TFVar(v): printVarField(v, f);
			case TFFun(fun): printMethod(fun, f);
		}
	}

	function printMethod(fun:TFFunDecl, f:TClassField) {
		printTextWithTrivia("function", fun.keyword);
		printToken(f.name);
		printFunctionSignature(fun.fun.signature);
		printExpr(fun.fun.expr);
	}

	function printFunctionSignature(sig:TFunctionSignature) {
		printTextWithTrivia("(", sig.syntax.openParen);
		for (arg in sig.args) {
			printToken(arg.syntax.name);
			printTypeHint(arg.v.type, arg.syntax.type);
			if (arg.comma != null) {
				printComma(arg.comma);
			}
		}
		printTextWithTrivia(")", sig.syntax.closeParen);
	}

	function printBracedBlock(block:TBracedExprBlock) {
		printTextWithTrivia("{", block.syntax.openBrace);
		printTextWithTrivia("}", block.syntax.closeBrace);
	}

	function printVarDeclKind(kind:ParseTree.VarDeclKind) {
		switch kind {
			case VVar(t): printTextWithTrivia("var", t);
			case VConst(t): printTextWithTrivia("final", t);
		}
	}

	function printVarField(v:TFVarDecl, f:TClassField) {
		printVarDeclKind(v.kind);

		printTextWithTrivia(v.syntax.name.text, v.syntax.name);
		printTypeHint(v.type, v.syntax.type);

		if (v.init != null) printVarInit(v.init);

		printSemicolon(v.endToken);
	}

	function printVarInit(init:TVarInit) {
		printToken(init.syntax.equals);
		printExpr(init.expr);
	}

	function printCallArgs(args:TCallArgs) {
		printTextWithTrivia("(", args.openParen);
		for (arg in args.args) {
			printExpr(arg.expr);
			if (arg.comma != null) {
				printComma(arg.comma);
			}
		}
		printTextWithTrivia(")", args.closeParen);
	}

	function printExpr(e:TExpr) {
		switch e.kind {
			case TNull(t): printTextWithTrivia("null", t);
			case TThis(t): printTextWithTrivia("this", t);
			case TSuper(t): printTextWithTrivia("super", t);
			case TELocal(t, _): printToken(t);
			case TEPreUnop(op, e):
				switch (op) {
					case PreNot(t): printTextWithTrivia("!", t);
					case PreNeg(t): printTextWithTrivia("-", t);
					case PreIncr(t): printTextWithTrivia("++", t);
					case PreDecr(t): printTextWithTrivia("--", t);
					case PreBitNeg(t): printTextWithTrivia("~", t);
				}
				printExpr(e);
			case TEPostUnop(e, op):
				printExpr(e);
				switch (op) {
					case PostIncr(t): printTextWithTrivia("++", t);
					case PostDecr(t): printTextWithTrivia("--", t);
				}
			case TECall(e, args):
				printExpr(e);
				printCallArgs(args);
			case TENew(keyword, e, args):
				printTextWithTrivia("new", keyword);
				printExpr(e);
				if (args != null) {
					printCallArgs(args);
				} else {
					buf.add("()");
				}
			case TEArrayAccess(e, openBracket, eindex, closeBracket):
				printExpr(e);
				printTextWithTrivia("[", openBracket);
				printExpr(eindex);
				printTextWithTrivia("]", closeBracket);
			case TELiteral(l):
				printLiteral(l);
			case TEContinue(syntax):
				printTextWithTrivia("continue", syntax);
			case TEBreak(syntax):
				printTextWithTrivia("break", syntax);
			case TEReturn(keyword, e):
				printTextWithTrivia("return", keyword);
				if (e != null) printExpr(e);
			case TEThrow(keyword, e):
				printTextWithTrivia("return", keyword);
				printExpr(e);
			case TEBinop(a, op, b):
				printExpr(a);
				printBinop(op);
				printExpr(b);
			case TEBlock(openBrace, exprs, closeBrace):
				printTextWithTrivia("{", openBrace);
				for (e in exprs) {
					printExpr(e.expr);
					if (e.semicolon != null) {
						printSemicolon(e.semicolon);
					} else {
						buf.add(";");
					}
				}
				printTextWithTrivia("}", closeBrace);
			case TETernary(econd, question, ethen, colon, eelse):
				printExpr(econd);
				printTextWithTrivia("?", question);
				printExpr(ethen);
				printColon(colon);
				printExpr(eelse);
			case TEIf(keyword, openParen, econd, closeParen, ethen, eelse):
				printTextWithTrivia("if", keyword);
				printTextWithTrivia("(", openParen);
				printExpr(econd);
				printTextWithTrivia(")", closeParen);
				printExpr(ethen);
				if (eelse != null) {
					printTextWithTrivia("else", eelse.keyword);
					printExpr(eelse.expr);
				}
			case TEWhile(keyword, openParen, cond, closeParen, body):
				printTextWithTrivia("while", keyword);
				printTextWithTrivia("(", openParen);
				printExpr(cond);
				printTextWithTrivia(")", closeParen);
				printExpr(body);
			case TEDoWhile(doKeyword, body, whileKeyword, openParen, cond, closeParen):
				printTextWithTrivia("do", doKeyword);
				printExpr(body);
				printTextWithTrivia("while", whileKeyword);
				printTextWithTrivia("(", openParen);
				printExpr(cond);
				printTextWithTrivia(")", closeParen);
			case TEComma(a, comma, b):
				buf.add("{");
				printExpr(a);
				printTextWithTrivia(";", comma);
				printExpr(b);
				buf.add(";}");
			case TETry(keyword, expr, catches):
				printTextWithTrivia("try", keyword);
				printExpr(expr);
				for (c in catches) {
					printTextWithTrivia("catch", c.syntax.keyword);
					printTextWithTrivia("(", c.syntax.openParen);
					printToken(c.syntax.name);
					printTypeHint(c.v.type, c.syntax.type);
					printTextWithTrivia(")", c.syntax.closeParen);
					printExpr(c.expr);
				}
			case TEParens(openParen, e, closeParen):
				printTextWithTrivia("(", openParen);
				printExpr(e);
				printTextWithTrivia(")", closeParen);
			case TEIs(e, keyword, type, syntaxType):
				// TODO: rewrite this to Std.is and friends, preserve trivia
				buf.add("Std.is(");
				printExpr(e);
				buf.add(", ");
				printType(type);
				buf.add(")");
			case TEDelete(keyword, e):
				buf.add("'[TODO: delete]'");
			case TEVars(kind, vars):
				printVarDeclKind(kind);
				for (v in vars) {
					printToken(v.decl.syntax.name);
					if (v.decl.init != null) printVarInit(v.decl.init);
					if (v.comma != null) printComma(v.comma);
				}
			case TEArrayDecl(d):
				printTextWithTrivia("[", d.openBracket);
				for (e in d.elems) {
					printExpr(e.expr);
					if (e.comma != null) printComma(e.comma);
				}
				printTextWithTrivia("]", d.closeBracket);
			case TEObjectDecl(openBrace, fields, closeBrace):
				printTextWithTrivia("{", openBrace);
				for (f in fields) {
					printToken(f.field.name);
					printColon(f.field.colon);
					printExpr(f.field.value);
					if (f.comma != null) printComma(f.comma);
				}
				printTextWithTrivia("}", closeBrace);
			case TEField(e, dot, fieldName):
				function checkNonWhitespaceTrivia(trivia:Array<Token.Trivia>) {
					for (t in trivia) switch (t.kind) {
						case TrWhitespace | TrNewline: // just don't generate it \o/
						case TrBlockComment | TrLineComment:
							throw "no comments allowed between dot and field name";
					}
				}
				checkNonWhitespaceTrivia(dot.trailTrivia);
				checkNonWhitespaceTrivia(fieldName.leadTrivia);
				printExpr(e);
				printTrivia(dot.leadTrivia);
				buf.add(".");
				buf.add(fieldName.text);
				printTrivia(fieldName.trailTrivia);
		}
	}

	function printBinop(op:ParseTree.Binop) {
		printToken(switch (op) {
			case OpAdd(t): t;
			case OpSub(t): t;
			case OpDiv(t): t;
			case OpMul(t): t;
			case OpMod(t): t;
			case OpAssign(t): t;
			case OpAssignAdd(t): t;
			case OpAssignSub(t): t;
			case OpAssignMul(t): t;
			case OpAssignDiv(t): t;
			case OpAssignMod(t): t;
			case OpAssignAnd(t): t;
			case OpAssignOr(t): t;
			case OpAssignBitAnd(t): t;
			case OpAssignBitOr(t): t;
			case OpAssignBitXor(t): t;
			case OpAssignShl(t): t;
			case OpAssignShr(t): t;
			case OpAssignUshr(t): t;
			case OpEquals(t): t;
			case OpNotEquals(t): t;
			case OpStrictEquals(t): t;
			case OpNotStrictEquals(t): t;
			case OpGt(t): t;
			case OpGte(t): t;
			case OpLt(t): t;
			case OpLte(t): t;
			case OpIn(t): t;
			case OpAnd(t): t;
			case OpOr(t): t;
			case OpShl(t): t;
			case OpShr(t): t;
			case OpUshr(t): t;
			case OpBitAnd(t): t;
			case OpBitOr(t): t;
			case OpBitXor(t): t;
		});
	}

	function printLiteral(l:ParseTree.Literal) {
		switch (l) {
			case LString(t): printToken(t);
			case LDecInt(t): printToken(t);
			case LHexInt(t): printToken(t);
			case LFloat(t): printToken(t);
			case LRegExp(t): printTextWithTrivia("~" + t.text, t);
		}
	}

	function printToken(t:Token) {
		printTextWithTrivia(t.text, t);
	}

	function printType(type:TType) {
		buf.add(switch (type) {
			case TString: "String";
			case TNumber: "Float";
			case TInt: "Int";
			case TUint: "UInt";
			case TBoolean: "Bool";
			case TAny: "Dynamic";
			case TObject: "Dynamic<Dynamic>";
			case TArray: "Array<Dynamic>";
			case TVoid: "Void";
			case TUnresolved(path): path;
		});
	}

	function printTypeHint(type:TType, hint:Null<ParseTree.TypeHint>) {
		if (hint == null) {
			buf.add(":");
			printType(type);
		} else {
			printColon(hint.colon);
			// TODO: print trivias from hint.type
			// or supply tokens in TType
			printType(type);
		}
	}

	function printInterfaceDecl(c:TInterface) {}

	function printImport(i:ParseTree.ImportDecl) {
		printTextWithTrivia("import", i.keyword);
		printDotPath(i.path);
		if (i.wildcard != null) {
			printDot(i.wildcard.dot);
			printTextWithTrivia("*", i.wildcard.asterisk);
		}
		printSemicolon(i.semicolon);
	}

	inline function printIdent(token:Token) {
		printTextWithTrivia(token.text, token);
	}

	inline function printDot(s:Token) {
		printTextWithTrivia(".", s);
	}

	inline function printComma(c:Token) {
		printTextWithTrivia(",", c);
	}

	inline function printSemicolon(s:Token) {
		printTextWithTrivia(";", s);
	}

	inline function printColon(s:Token) {
		printTextWithTrivia(":", s);
	}

	function printDotPath(p:ParseTree.DotPath) {
		printSeparated(p, t -> printTextWithTrivia(t.text, t), t -> printTextWithTrivia(".", t));
	}

	function printSeparated<T>(s:ParseTree.Separated<T>, f:T->Void, fsep:Token->Void) {
		f(s.first);
		for (v in s.rest) {
			fsep(v.sep);
			f(v.element);
		}
	}

	function printTextWithTrivia(text:String, triviaToken:Token) {
		printTrivia(triviaToken.leadTrivia);
		buf.add(text);
		printTrivia(triviaToken.trailTrivia);
	}

	function printTrivia(trivia:Array<Token.Trivia>) {
		for (item in trivia) {
			buf.add(item.text);
		}
	}

	public function getContent() {
		return buf.toString();
	}
}