import haxe.io.Path;
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
		trace('Parsing $path');
		var content = sys.io.File.getContent(path);
		var scanner = new Scanner(content);
		var head = scanner.scan();
		var stream = new TokenInfoStream(head);
		var parser = new Parser(stream);
		var file = parser.parse();
		// var dump = ParseTreeDump.printFile(file, "");
		// Sys.println(dump);
	}
}
