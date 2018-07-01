class Token {
	public var kind:TokenKind;
	public var text:String;
	public var leadTrivia:Array<Trivia>;
	public var trailTrivia:Array<Trivia>;

	public function new(kind, text) {
		this.kind = kind;
		this.text = text;
	}

	public function toString() {
		return '${kind.getName()}(${haxe.Json.stringify(text)})';
	}
}

@:forward(kind, text)
abstract PeekToken(Token) from Token {}

class Trivia {
	public var kind:TriviaKind;
	public var text:String;

	public function new(kind, text) {
		this.kind = kind;
		this.text = text;
	}

	public function toString() {
		return '${kind.getName()}(${haxe.Json.stringify(text)})';
	}
}

enum TriviaKind {
	TrWhitespace;
	TrNewline;
	TrBlockComment;
	TrLineComment;
}

enum TokenKind {
	TkEof;
	TkAmpersand;
	TkAmpersandAmpersand;
	TkAmpersandAmpersandEquals;
	TkAmpersandEquals;
	TkPipe;
	TkPipePipe;
	TkPipePipeEquals;
	TkPipeEquals;
	TkCaret;
	TkCaretEquals;
	TkIdent;
	TkBraceOpen;
	TkBraceClose;
	TkParenOpen;
	TkParenClose;
	TkBracketOpen;
	TkBracketClose;
	TkColon;
	TkColonColon;
	TkSemicolon;
	TkSlash;
	TkSlashEquals;
	TkDot;
	TkDotDot;
	TkDotDotDot;
	TkComma;
	TkEquals;
	TkEqualsEquals;
	TkEqualsEqualsEquals;
	TkAsterisk;
	TkAsteriskEquals;
	TkPlus;
	TkPlusPlus;
	TkPlusEquals;
	TkMinus;
	TkMinusMinus;
	TkMinusEquals;
	TkPercent;
	TkPercentEquals;
	TkGt;
	TkGtGt;
	TkGtGtGt;
	TkGtEquals;
	TkLt;
	TkLtLt;
	TkLtEquals;
	TkStringSingle;
	TkStringDouble;
	TkRegExp;
	TkXml;
	TkQuestion;
	TkTilde;
	TkExclamation;
	TkExclamationEquals;
	TkExclamationEqualsEquals;
	TkDecimalInteger;
	TkHexadecimalInteger;
	TkFloat;
	TkUnknown;
}
