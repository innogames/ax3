package ax3;

import ax3.Token;

class PrinterBase {
	final buf = new StringBuf();

	public function new() {}

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
