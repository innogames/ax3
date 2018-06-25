import sys.FileSystem;

class Main {
	static function main() {
		walk(Sys.args()[0]);
	}

	static function walk(dir:String) {
		function loop(dir) {
			for (name in FileSystem.readDirectory(dir)) {
				var absPath = dir + "/" + name;
				if (FileSystem.isDirectory(absPath)) {
					walk(absPath);
				} else if (StringTools.endsWith(name, ".as")) {
					parseFile(absPath);
				}
			}
		}
		loop(dir);
	}

	static function parseFile(path:String) {
		print('Parsing $path');
		var content = sys.io.File.getContent(path);
		var scanner = new Scanner(content);
		var head = scanner.scan();
		var stream = new TokenInfoStream(head);
		var parser = new Parser(stream);
		try {
			var file = parser.parse();
			// var dump = ParseTreeDump.printFile(file, "");
			// Sys.println(dump);
		} catch (e:Any) {
			var pos = getPos(head, stream.advance());
			var line = getLine(content, pos);
			printerr('$path:$line: $e');
		}
	}

	static function print(s:String) js.Node.console.log(s);
	static function printerr(s:String) js.Node.console.error(s);

	static function getLine(content:String, pos:Int):Int {
		var line = 1;
		var p = 0;
		while (p < pos) {
			switch StringTools.fastCodeAt(content, p++) {
				case '\n'.code:
					line++;
				case '\r'.code:
					p++;
					line++;
			}
		}
		return line;
	}

	static function getPos(head:Token, token:Token):Int {
		var pos = 0;
		while (true) {
			if (head == token || head.kind == TkEof)
				break;
			pos += head.text.length;
			head = head.next;
		}
		return pos;
	}
}
