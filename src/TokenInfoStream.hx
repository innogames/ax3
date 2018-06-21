/**
	TokenInfoStream reads the linked list of plain tokens and construct
	TokenInfo objects with comments and whitespace saved as leading or trailing trivia.
**/
class TokenInfoStream {
	var head:Token;
	var trivia:Array<Token>;

	public var lastConsumedToken(default,null):TokenInfo;

	public function new(head) {
		this.head = head;
		this.trivia = [];
	}

	public function advance():Token {
		while (true) {
			switch head.kind {
				case TkWhitespace | TkNewline | TkLineComment | TkBlockComment:
					trivia.push(head);
				case _:
					break;
			}
			head = head.next;
		}
		return head;
	}

	public function consume():TokenInfo {
		var info = new TokenInfo();
		info.token = head;
		info.leadTrivia = trivia;

		trivia = [];
		head = head.next;

		info.trailTrivia = consumeTrailTrivia();
		lastConsumedToken = info;
		return info;
	}


	function consumeTrailTrivia():Array<Token> {
		var result = [];
		while (true) {
			switch head.kind {
				case TkWhitespace | TkLineComment | TkBlockComment:
					result.push(head);
					head = head.next;
				case TkNewline:
					result.push(head);
					head = head.next;
					break;
				case _:
					break;
			}
		}
		return result;
	}
}
