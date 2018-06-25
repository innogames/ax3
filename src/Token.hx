class Token {
	public var kind:TokenKind;
	public var text:String;
	public var prev:Token;
	public var next:Token;

	public function new(kind, text) {
		this.kind = kind;
		this.text = text;
	}

	public function toString() {
		return '${kind.getName()}(${haxe.Json.stringify(text)})';
	}
}

enum TokenKind {
	TkEof;
	TkWhitespace;
	TkNewline;
	TkBlockComment;
	TkLineComment;
	TkAmpersand;
	TkAmpersandAmpersand;
	TkPipe;
	TkPipePipe;
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
	TkGtEquals;
	TkLt;
	TkLtEquals;
	TkStringSingle;
	TkStringDouble;
	TkQuestion;
	TkExclamation;
	TkExclamationEquals;
	TkExclamationEqualsEquals;
	TkDecimalInteger;
	TkHexadecimalInteger;
	TkFloat;
}
