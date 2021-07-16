package ax3;

import haxe.extern.EitherType;
import haxe.DynamicAccess;
import ax3.Utils.printerr;

using StringTools;

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
		if (config.dataout != null && !config.dataout.endsWith('/')) config.dataout += '/';
		if (config.unpackout != null && !config.unpackout.endsWith('/')) config.unpackout += '/';
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
	var ?src:EitherType<String,Array<String>>;
	var ?swc:Array<String>;
	var ?skipFiles:Array<String>;
	var ?hxout:String;
	var ?injection:InjectionConfig;
	var ?haxeTypes:DynamicAccess<HaxeTypeAnnotation>;
	var ?rootImports:String;
	var ?settings:Settings;
	var ?keepTypes:Bool;
	var ?dataout:String;
	var ?dataext:Array<String>;
	var ?datafiles:Array<String>;
	var ?unpackout:String;
	var ?unpackswc:Array<String>;
	var ?hxoutClean:Bool;
	var ?dataoutClean:Bool;
	var ?formatter:Bool;
	var ?copy:Array<{unit: String, to: String}>;
}

typedef InjectionConfig = {
	var magicInterface:String;
	var magicBaseClasses:Array<String>;
}

typedef Settings = {
	var ?checkNullIteratee:Bool;
	var ?haxeRobotlegs:Bool;
	var ?flashProperties:FlashPropertiesSetting;
}

enum abstract FlashPropertiesSetting(String) {
	var none;
	var externInterface;
	var all;
}
