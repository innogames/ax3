package ax3;

import ax3.Token;
import ax3.ParseTree;

class PrinterBase {
	final buf:StringBuf;

	public function new(?buf) {
		this.buf = if (buf != null) buf else new StringBuf();
	}

	public function toString() {
		return buf.toString();
	}

	inline function printDot(s:Token) {
		printTextWithTrivia(".", s);
	}

	inline function printComma(c:Token) {
		printTextWithTrivia(",", c);
	}

	inline function printColon(s:Token) {
		printTextWithTrivia(":", s);
	}

	inline function printSemicolon(s:Token) {
		printTextWithTrivia(";", s);
	}

	inline function printOpenBracket(s:Token) {
		printTextWithTrivia("[", s);
	}

	inline function printCloseBracket(s:Token) {
		printTextWithTrivia("]", s);
	}

	inline function printOpenBrace(s:Token) {
		printTextWithTrivia("{", s);
	}

	inline function printCloseBrace(s:Token) {
		printTextWithTrivia("}", s);
	}

	inline function printOpenParen(s:Token) {
		printTextWithTrivia("(", s);
	}

	inline function printCloseParen(s:Token) {
		printTextWithTrivia(")", s);
	}

	function printDotPath(p:DotPath) {
		printSeparated(p, t -> printTextWithTrivia(t.text, t), t -> printDot(t));
	}

	function printSeparated<T>(s:Separated<T>, f:T->Void, fsep:Token->Void) {
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

	function printTrivia(trivia:Array<Trivia>) {
		for (item in trivia) {
			buf.add(item.text);
		}
	}
}
