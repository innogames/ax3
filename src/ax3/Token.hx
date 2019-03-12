package ax3;

class Token {
	public final pos:Int;
	public final kind:TokenKind;
	public final text:String;
	public var leadTrivia:Array<Trivia>;
	public var trailTrivia:Array<Trivia>;

	public function new(pos, kind, text, leadTrivia, trailTrivia) {
		this.pos = pos;
		this.kind = kind;
		this.text = text;
		this.leadTrivia = leadTrivia;
		this.trailTrivia = trailTrivia;
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
	TkGtGtEquals;
	TkGtGtGt;
	TkGtGtGtEquals;
	TkGtEquals;
	TkLt;
	TkLtLt;
	TkLtLtEquals;
	TkLtEquals;
	TkStringSingle;
	TkStringDouble;
	TkRegExp;
	TkXml;
	TkQuestion;
	TkTilde;
	TkAt;
	TkExclamation;
	TkExclamationEquals;
	TkExclamationEqualsEquals;
	TkDecimalInteger;
	TkHexadecimalInteger;
	TkFloat;
	TkUnknown;
}
