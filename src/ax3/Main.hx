package ax3;

import sys.FileSystem;

import ax3.Utils.*;
import ax3.Context;

class Main {
	static var ctx:Context;

	static function main() {
		var args = Sys.args();
		if (args.length != 1) {
			throw "invalid args";
		}
		var config:Config = haxe.Json.parse(sys.io.File.getContent(args[0]));
		ctx = new Context(config);

		var total = stamp();

		var tree = new TypedTree();

		var t = stamp();
		SWCLoader.load(tree, config.haxeTypes, config.swc);
		Timers.swcs = stamp() - t;

		var files = [];
		var srcs = if (Std.is(config.src, String)) [config.src] else config.src;
		for (src in srcs) {
			walk(src, files);
		}

		t = stamp();
		Typer.process(ctx, tree, files);
		Timers.typing = stamp() - t;

		// sys.io.File.saveContent("structure.txt", tree.dump());

		t = stamp();
		Filters.run(ctx, tree);
		Timers.filters = stamp() - t;

		var haxeDir = FileSystem.absolutePath(config.hxout);
		t = stamp();
		for (packName => pack in tree.packages) {

			var dir = haxe.io.Path.join({
				var parts = packName.split(".");
				parts.unshift(haxeDir);
				parts;
			});

			for (mod in pack) {
				if (mod.isExtern) continue;
				Utils.createDirectory(dir);
				var gen = new ax3.GenHaxe(ctx);
				gen.writeModule(mod);
				var out = gen.toString();
				var path = dir + "/" + mod.name + ".hx";
				sys.io.File.saveContent(path, out);
			}
		}

		var imports = [];
		for (path => kind in ctx.getToplevelImports()) {
			imports.push('$kind $path;');
		}
		if (config.rootImports != null) {
			imports.push(sys.io.File.getContent(config.rootImports));
		}
		if (imports.length > 0) {
			sys.io.File.saveContent(haxe.io.Path.join([haxeDir, "import.hx"]), imports.join("\n"));
		}

		Timers.output = stamp() - t;

		total = (stamp() - total);

		print("parsing   " + Timers.parsing);
		print("swcs      " + Timers.swcs);
		print("typing    " + Timers.typing);
		print("filters   " + Timers.filters);
		print("output    " + Timers.output);
		print("-- TOTAL  " + total);
	}

	static function walk(dir:String, files:Array<ParseTree.File>) {
		function loop(dir) {
			for (name in FileSystem.readDirectory(dir)) {
				var absPath = dir + "/" + name;
				if (FileSystem.isDirectory(absPath)) {
					walk(absPath, files);
				} else if (StringTools.endsWith(name, ".as")) {
					var file = parseFile(absPath);
					if (file != null) {
						files.push(file);
					}
				}
			}
		}
		loop(dir);
	}

	static function parseFile(path:String):ParseTree.File {
		// print('Parsing $path');
		var t = stamp();
		var content = stripBOM(ctx.fileLoader.getContent(path));
		var scanner = new Scanner(content);
		var parser = new Parser(scanner, path);
		var parseTree = null;
		try {
			parseTree = parser.parse();
			// var dump = ParseTreeDump.printFile(parseTree, "");
			// Sys.println(dump);
		} catch (e:Any) {
			ctx.reportError(path, @:privateAccess scanner.pos, Std.string(e));
		}
		Timers.parsing += (stamp() - t);
		if (parseTree != null) {
			// checkParseTree(path, content, parseTree);
		}
		return parseTree;
	}

	static function checkParseTree(path:String, expected:String, parseTree:ParseTree.File) {
		var actual = Printer.print(parseTree);
		if (actual != expected) {
			printerr(actual);
			printerr("-=-=-=-=-");
			printerr(expected);
			// throw "not the same: " + haxe.Json.stringify(actual);
			throw '$path not the same';
		}
	}
}
