package ax3;

import sys.FileSystem;
import ax3.Utils.*;

private typedef Config = {
	var src:String;
	var swc:Array<String>;
	var ?out:String;
	var ?hxout:String;
	var ?dump:String;
}

class Main {
	static final ctx = new Context();

	static function main() {
		var args = Sys.args();
		if (args.length != 1) {
			throw "invalid args";
		}
		var config:Config = haxe.Json.parse(sys.io.File.getContent(args[0]));

		var total = stamp();

		var tree = new TypedTree();
		SWCLoader.load(tree, config.swc);

		var files = [];
		walk(config.src, files);
		Typer.process(ctx, tree, files);

		sys.io.File.saveContent("structure.txt", tree.dump());

		var haxeDir = if (config.hxout == null) null else FileSystem.absolutePath(config.hxout);
		for (packName => pack in tree.packages) {

			var dir = haxe.io.Path.join({
				var parts = packName.split(".");
				parts.unshift(haxeDir);
				parts;
			});
			Utils.createDirectory(dir);

			for (mod in pack) {
				if (mod.isExtern) continue;

				var gen = new ax3.GenHaxe();
				gen.writeModule(mod);
				var out = gen.toString();
				var path = dir + "/" + mod.name + ".hx";
				sys.io.File.saveContent(path, out);
			}
		}

		// var t = stamp();
		// Timers.typing += (stamp() - t);

		/*


		t = stamp();
		Filters.run(ctx, structure, modules);
		Timers.filters += (stamp() - t);

		var outDir = if (config.out == null) null else FileSystem.absolutePath(config.out);
		var dumpDir = if (config.dump == null) null else FileSystem.absolutePath(config.dump);
		var haxeDir = if (config.hxout == null) null else FileSystem.absolutePath(config.hxout);
		t = stamp();
		for (mod in modules) {
			if (outDir != null) {
				var gen = new ax3.GenAS3();
				gen.writeModule(mod);
				var out = gen.toString();

				var dir = haxe.io.Path.join({
					var parts = mod.pack.name.split(".");
					parts.unshift(outDir);
					parts;
				});
				Utils.createDirectory(dir);

				var path = dir + "/" + mod.name + ".as";
				sys.io.File.saveContent(path, out);
			}

			if (haxeDir != null) {
				var gen = new ax3.GenHaxe(structure);
				gen.writeModule(mod);
				var out = gen.toString();

				var dir = haxe.io.Path.join({
					var parts = mod.pack.name.split(".");
					parts.unshift(haxeDir);
					parts;
				});
				Utils.createDirectory(dir);

				var path = dir + "/" + mod.name + ".hx";
				sys.io.File.saveContent(path, out);
			}

			if (dumpDir != null) {
				var dir = haxe.io.Path.join({
					var parts = mod.pack.name.split(".");
					parts.unshift(dumpDir);
					parts;
				});
				Utils.createDirectory(dir);
				TypedTreeDump.dump(mod, dir + "/" + mod.name + ".dump");
			}
		}
		Timers.output += (stamp() - t);

		total = (stamp() - total);


		print("parsing   " + Timers.parsing);
		print("swcs      " + Timers.swcs);
		print("structure " + Timers.structure);
		print("resolve   " + Timers.resolve);
		print("typing    " + Timers.typing);
		print("filters   " + Timers.filters);
		print("output    " + Timers.output);
		print("-- TOTAL  " + total);*/
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
