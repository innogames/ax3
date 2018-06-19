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
	TkIdent;
	TkBraceOpen;
	TkBraceClose;
	TkParenOpen;
	TkParenClose;
	TkColon;
	TkSemicolon;
	TkSlash;
	TkDot;
	TkComma;
	TkEquals;
	TkAsterisk;
}
