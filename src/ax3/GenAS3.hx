package ax3;

import ax3.ParseTree;
import ax3.TypedTree;

@:nullSafety
class GenAS3 extends PrinterBase {
	public function writeModule(m:TModule) {
		printPackage(m.pack);
		printTrivia(m.eof.leadTrivia);
	}

	function printPackage(p:TPackageDecl) {
		printTextWithTrivia("package", p.syntax.keyword);
		if (p.syntax.name != null) printDotPath(p.syntax.name);
		printOpenBrace(p.syntax.openBrace);
		printDecl(p.decl);
		printCloseBrace(p.syntax.closeBrace);
	}

	function printDecl(d:TDecl) {
		switch (d) {
			case TDClass(c): printClassClass(c);
		}
	}

	function printClassClass(c:TClassDecl) {
		for (m in c.modifiers) {
			switch (m) {
				case DMPublic(t): printTextWithTrivia(t.text, t);
				case DMInternal(t): printTextWithTrivia(t.text, t);
				case DMFinal(t): printTextWithTrivia(t.text, t);
				case DMDynamic(t): printTextWithTrivia(t.text, t);
			}
		}
		printTextWithTrivia("class", c.syntax.keyword);
		printTextWithTrivia(c.name, c.syntax.name);
		printOpenBrace(c.syntax.openBrace);
		for (m in c.members) {
			switch (m) {
				case TMField(f): printClassField(f);
			}
		}
		printCloseBrace(c.syntax.closeBrace);
	}

	function printClassField(f:TClassField) {
		switch (f.kind) {
			case TFVar:
			case TFProp:
			case TFFun(f):
				printTextWithTrivia("function", f.syntax.keyword);
				printTextWithTrivia(f.name, f.syntax.name);
				printSignature(f.fun.sig);
				printBlock(f.fun.block);
		}
	}

	function printSignature(sig:TFunctionSignature) {
		printOpenParen(sig.syntax.openParen);
		printCloseParen(sig.syntax.closeParen);
	}

	function printExpr(e:TExpr) {
		switch (e.kind) {
			case TEFunction(f):
			case TELiteral(l):
			case TELocal(syntax, v):
			case TEField(syntax, obj, fieldName):
			case TEThis(syntax):
			case TEStaticThis:
			case TESuper(syntax):
			case TEBuiltin(syntax, name):
			case TEDeclRef(c):
			case TECall(syntax, eobj, args):
			case TEArrayDecl(syntax, elems):
			case TEVectorDecl(type, elems):
			case TEReturn(keyword, e):
			case TEThrow(keyword, e):
			case TEDelete(keyword, e):
			case TEBreak(keyword):
			case TEContinue(keyword):
			case TEVars(v):
			case TEObjectDecl(syntax, fields):
			case TEArrayAccess(eobj, eindex):
			case TEBlock(block): printBlock(block);
			case TETry(expr, catches):
			case TEVector(type):
			case TETernary(econd, ethen, eelse):
			case TEIf(econd, ethen, eelse):
			case TEWhile(econd, ebody):
			case TEDoWhile(ebody, econd):
			case TEFor(einit, econd, eincr, ebody):
			case TEForIn(eit, eobj, ebody):
			case TEBinop(a, op, b):
			case TEComma(a, b):
			case TEIs(e, etype):
			case TEAs(e, type):
			case TESwitch(esubj, cases, def):
			case TENew(eclass, args):
			case TECondCompBlock(ns, name, expr):
			case TEXmlAttr(e, name):
			case TEXmlAttrExpr(e, eattr):
			case TEXmlDescend(e, name):
			case TENothing:
		}
	}

	function printBlock(block:TBlock) {
		printOpenBrace(block.syntax.openBrace);
		for (e in block.exprs) {
			printExpr(e.expr);
			if (e.semicolon != null) printSemicolon(e.semicolon);
		}
		printCloseBrace(block.syntax.closeBrace);
	}
}
