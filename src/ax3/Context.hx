package ax3;

import ax3.Utils.printerr;

class Context {
	public final fileLoader = new FileLoader();

	public function new() {}

	public function reportError(path:String, pos:Int, message:String) {
		var posStr = fileLoader.formatPosition(path, pos);
		printerr('$posStr: $message');
	}
}
