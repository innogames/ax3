import sys.FileSystem;

class Main {
	static var eagerFail = false;

	static var typer:Typer;

	static function main() {
		var args = Sys.args();
		var dir = switch args {
			case ["eagerFail", path]:
				eagerFail = true;
				path;
			case [path]:
				path;
			case _:
				throw "invalid args";
		}
		typer = new Typer();
		walk(dir);
		typer.process();
		typer.write("./OUT/");
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
		// print('Parsing $path');
		var content = stripBOM(sys.io.File.getContent(path));
		var scanner = new Scanner(content);
		var parser = new Parser(scanner, new haxe.io.Path(path).file);
		var parseTree = null;
		if (eagerFail) {
			parseTree = parser.parse();
			var dump = ParseTreeDump.printFile(parseTree, "");
			// Sys.println(dump);
		} else {
			try {
				parseTree = parser.parse();
			} catch (e:Any) {
				var pos = @:privateAccess scanner.pos;
				var line = getLine(content, pos);
				printerr('$path:$line: $e');
			}
		}
		if (parseTree != null) {
			checkParseTree(content, parseTree);

			try
				typer.addFile(parseTree)
			catch (e:Any)
				printerr('$path:0: $e');
		}
	}

	static function checkParseTree(expected:String, parseTree:ParseTree.File) {
		var actual = Printer.print(parseTree);
		if (actual != expected)
			throw "not the same: " + haxe.Json.stringify(actual);
	}

	static function stripBOM(text:String):String {
		return if (StringTools.fastCodeAt(text, 0) == 0xFEFF) text.substring(1) else text;
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
}
