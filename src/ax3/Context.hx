package ax3;

import ax3.Utils.printerr;

enum abstract ToplevelImportKind(String) to String {
	var Import = "import";
	var Using = "using";
}

class Context {
	public final fileLoader = new FileLoader();
	public final injectionConfig:Null<InjectionConfig>;
	final toplevelImports = new Map<String,ToplevelImportKind>();

	public function new(injectionConfig) {
		this.injectionConfig = injectionConfig;
	}

	public function reportError(path:String, pos:Int, message:String) {
		var posStr = fileLoader.formatPosition(path, pos);
		printerr('$posStr: $message');
	}

	public inline function addToplevelImport(path, kind) toplevelImports[path] = kind;

	// TODO: sort the keys?
	public inline function getToplevelImports() return toplevelImports.keyValueIterator();
}

typedef InjectionConfig = {
	var magicInterface:String;
	var magicBaseClasses:Array<String>;
};
