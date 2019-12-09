package ax3;

import haxe.extern.EitherType;
import haxe.DynamicAccess;
import ax3.Utils.printerr;

enum abstract ToplevelImportKind(String) to String {
	var Import = "import";
	var Using = "using";
}

class Context {
	public final fileLoader = new FileLoader();
	public final config:Config;
	final toplevelImports = new Map<String,ToplevelImportKind>();

	public function new(config:Config) {
		this.config = config;
	}

	public function reportError(path:String, pos:Int, message:String) {
		var posStr = fileLoader.formatPosition(path, pos);
		printerr('$posStr: $message');
	}

	public inline function addToplevelImport(path, kind) toplevelImports[path] = kind;

	// TODO: sort the keys?
	public inline function getToplevelImports() return toplevelImports.keyValueIterator();
}

typedef Config = {
	var src:EitherType<String,Array<String>>;
	var swc:Array<String>;
	var ?hxout:String;
	var ?injection:InjectionConfig;
	var ?haxeTypes:DynamicAccess<HaxeTypeAnnotation>;
	var ?rootImports:String;
	var ?settings:Settings;
}

typedef InjectionConfig = {
	var magicInterface:String;
	var magicBaseClasses:Array<String>;
}

typedef Settings = {
	var ?checkNullIteratee:Bool;
	var ?haxeRobotlegs:Bool;
	var ?flashProperties:Bool;
}
