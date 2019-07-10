package ax3;

import ax3.Utils.printerr;

class Context {
	public final fileLoader = new FileLoader();
	public final injectionConfig:Null<InjectionConfig>;

	public function new(injectionConfig) {
		this.injectionConfig = injectionConfig;
	}

	public function reportError(path:String, pos:Int, message:String) {
		var posStr = fileLoader.formatPosition(path, pos);
		printerr('$posStr: $message');
	}
}

typedef InjectionConfig = {
	var magicInterface:String;
	var magicBaseClasses:Array<String>;
};
