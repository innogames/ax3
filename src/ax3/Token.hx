package ax3;

class Token {
	public static final nullToken = new Token(-1, TkEof, "", [], []);

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

	public inline function with(kind, text) return new Token(this.pos, kind, text, this.leadTrivia, this.trailTrivia);

	public inline function clone():Token {
		return new Token(pos, kind, text, leadTrivia.copy(), trailTrivia.copy());
	}

	public inline function removeLeadingTrivia():Array<Trivia> {
		var trivia = leadTrivia;
		leadTrivia = [];
		return trivia;
	}

	public inline function removeTrailingTrivia():Array<Trivia> {
		var trivia = trailTrivia;
		trailTrivia = [];
		return trivia;
	}

	public function trimTrailingWhitespace() {
		var i = trailTrivia.length - 1;
		if (trailTrivia[i].kind == TrNewline) {
			i--;
		}
		if (trailTrivia[i].kind == TrWhitespace) {
			trailTrivia.splice(i, 1);
		}
	}
}

@:forward(kind, text, leadTrivia, trailTrivia)
abstract PeekToken(Token) from Token {}

class Trivia {
	public final kind:TriviaKind;
	public final text:String;

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
