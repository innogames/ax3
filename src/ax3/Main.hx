package ax3;

import sys.io.File;
import sys.FileSystem;

import haxe.zip.Reader;
import haxe.io.Path;

import ax3.Utils.*;
import ax3.Context;

using StringTools;

class Main {
	static var ctx:Context;
	static var skipFiles = new Map<String,Bool>();

	static function main() {
		var total = stamp();

		var args = Sys.args();
		if (args.length != 1) error('invalid args');

		var config:Config = haxe.Json.parse(File.getContent(args[0]));
		checkSet(config.src, 'src');
		checkSet(config.hxout, 'hxout');
		checkSet(config.swc, 'swc');

		ctx = new Context(config);
		clean();
		copy();
		unpackswc();
		copydatafiles();

		var tree = new TypedTree();

		var t = stamp();
		SWCLoader.load(tree, config.haxeTypes, config.swc);
		Timers.swcs = stamp() - t;

		if (ctx.config.dataout != null) FileSystem.createDirectory(ctx.config.dataout);

		var files = [];
		var srcs = if (Std.isOfType(config.src, String)) [config.src] else config.src;
		for (src in srcs) {
			walk(src, files);
		}

		t = stamp();
		Typer.process(ctx, tree, files);
		Timers.typing = stamp() - t;

		// File.saveContent("structure.txt", tree.dump());

		t = stamp();
		Filters.run(ctx, tree);
		Timers.filters = stamp() - t;

		var haxeDir = FileSystem.absolutePath(config.hxout);
		t = stamp();
		for (packName => pack in tree.packages) {

			var dir = Path.join({
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
				File.saveContent(path, out);
			}
		}

		var imports = [];
		for (path => kind in ctx.getToplevelImports()) {
			imports.push('$kind $path;');
		}
		if (config.rootImports != null) {
			imports.push(File.getContent(config.rootImports));
		}
		if (imports.length > 0) {
			imports.unshift("#if !macro");
			imports.push("#end");
			File.saveContent(Path.join([haxeDir, "import.hx"]), imports.join("\n"));
		}

		Timers.output = stamp() - t;

		formatter();

		total = (stamp() - total);

		if (Timers.copy > 0)
		print("copy      " + Timers.copy);
		if (Timers.unpack > 0)
		print("unpack    " + Timers.unpack);
		print("parsing   " + Timers.parsing);
		print("swcs      " + Timers.swcs);
		print("typing    " + Timers.typing);
		print("filters   " + Timers.filters);
		print("output    " + Timers.output);
		if (Timers.formatter > 0)
		print("formatter " + Timers.formatter);
		print("-- TOTAL  " + total);
	}

	static function checkSet(value: Any, name: String): Void {
		if (value == null) error('$name not set');
	}

	static function error(message: String): Void {
		printerr(message);
		Sys.exit(1);
	}

	static function shouldSkip(path:String):Bool {
		var skipFiles = ctx.config.skipFiles;
		return skipFiles != null && skipFiles.contains(path);
	}

	static function walk(dir:String, files:Array<ParseTree.File>) {
		for (name in FileSystem.readDirectory(dir)) {
			var absPath = dir + "/" + name;
			if (FileSystem.isDirectory(absPath)) {
				walk(absPath, files);
			} else if (!shouldSkip(absPath)) {
				final extIndex = name.lastIndexOf('.') + 1;
				if (extIndex <= 1) continue;
				final ext = name.substr(extIndex);
				if (ext == "as") {
					var file = parseFile(absPath);
					if (file != null) {
						files.push(file);
					}
				} else if (
					ctx.config.dataout != null && ctx.config.dataext != null &&
					ctx.config.dataext.indexOf(ext) != -1
				) {
					print('Walk copy file ' + absPath);
					final t = stamp();
					final dst = ctx.config.dataout + name;
					if (FileSystem.exists(dst)) print('File exists, overwrite');
					File.copy(absPath, dst);
					Timers.copy += stamp() - t;
				}
			}
		}
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

	static function unpackswc() {
		if (ctx.config.unpackswc == null && ctx.config.unpackout == null) return;
		final t = stamp();
		if (!FileSystem.exists(ctx.config.unpackout)) FileSystem.createDirectory(ctx.config.unpackout);

		for (swc in ctx.config.unpackswc)
			for (entry in Reader.readZip(File.read(swc)))
				if (entry.fileName == 'library.swf') {
					print('Unpack ' + swc);
					File.saveBytes(ctx.config.unpackout + fileName(swc) + 'swf', Reader.unzip(entry));
					break;
				}
		Timers.unpack = stamp() - t;
	}

	static function fileName(path: String): String {
		return path.substring(path.lastIndexOf('/'), path.lastIndexOf('.') + 1);
	}

	static function copydatafiles(): Void {
		if (ctx.config.datafiles != null && ctx.config.dataout != null && ctx.config.datafiles.length > 0) {
			final t = stamp();
			for (path in ctx.config.datafiles) {
				final fileName = path.substr(path.lastIndexOf('/') + 1);
				print('Copy file $fileName');
				File.copy(path, ctx.config.dataout + fileName);
			}
			Timers.copy += stamp() - t;
		}
	}

	static function clean(): Void {
		if (ctx.config.dataoutClean && ctx.config.dataout != null) deleteDirRecursively(ctx.config.dataout);
		if (ctx.config.hxoutClean) deleteDirRecursively(ctx.config.hxout);
	}

	static function deleteDirRecursively(path: String): Void {
		if (FileSystem.exists(path) && FileSystem.isDirectory(path)) {
			for (entry in FileSystem.readDirectory(path)) {
				if (FileSystem.isDirectory(path + '/' + entry)) {
					deleteDirRecursively(path + '/' + entry);
					FileSystem.deleteDirectory(path + '/' + entry);
				} else {
					FileSystem.deleteFile(path + '/' + entry);
				}
			}
		}
	}

	static function formatter(): Void {
		if (!ctx.config.formatter) return;
		final t = stamp();
		final args = ['run', 'formatter', '-s', ctx.config.hxout];
		print('haxelib ' + args.join(' '));
		Sys.command('haxelib', args);
		Timers.formatter = stamp() - t;
	}

	static function copy(): Void {
		if (ctx.config.copy != null && ctx.config.copy.length > 0) {
			final t = stamp();
			for (copy in ctx.config.copy) copyUnit(copy.unit, copy.to);
			Timers.copy += stamp() - t;
		}
	}

	static function copyUnit(unit: String, to: String): Void {
		if (FileSystem.isDirectory(unit)) {
			if (!unit.endsWith('/')) unit += '/';
			if (!to.endsWith('/')) to += '/';
			if (!FileSystem.exists(to)) FileSystem.createDirectory(to);
			for (u in FileSystem.readDirectory(unit)) copyUnit(unit + u, to + u);
		} else {
			print('Copy file $unit to $to');
			File.copy(unit, to);
		}
	}
}
