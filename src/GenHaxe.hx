import TypedTree;

class GenHaxe {
	var buf:StringBuf;

	public function new() {
		buf = new StringBuf();
	}

	public function writeModule(m:TModule) {

		printTextWithTrivia("package", m.pack.keyword);
		if (m.pack.name != null) printDotPath(m.pack.name);
		buf.add(";"); // TODO: move semicolon before the newline (if any)
		printTextWithTrivia("", m.pack.openBrace);

		for (i in m.imports) {
			printImport(i); // TODO: strip indentation
		}

		if (m.publicDecl == null) trace("WARNING: no public decl!");
		else printTypeDecl(m.publicDecl);

		printTextWithTrivia("", m.pack.closeBrace);

		printTrivia(m.eof.leadTrivia);
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
				case DMFinal(t): printTextWithTrivia("@:final", t);
				case DMDynamic(t): printTextWithTrivia("/*dynamic*/", t);
			}
		}
		printTextWithTrivia("class", c.syntax.keyword);
		printIdent(c.syntax.name);
		if (c.syntax.extend != null) {
			printTextWithTrivia("extends", c.syntax.extend.keyword);
			printDotPath(c.syntax.extend.path);
		}
		printTextWithTrivia("{", c.syntax.openBrace);
		printTextWithTrivia("}", c.syntax.closeBrace);
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