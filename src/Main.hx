class Main {
	static function main() {
		var content = sys.io.File.getContent("Test.as");
		var scanner = new Scanner(content);
		var head = scanner.scan();
		var stream = new TokenInfoStream(head);
		var parser = new Parser(stream);
		var file = parser.parse();
		trace(file);
	}
}
