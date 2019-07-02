package ax3;

import sys.FileSystem;

class Utils {
	public static inline function print(s:String) {
		#if hxnodejs js.Node.console.log(s) #else Sys.println(s) #end;
	}

	public static inline function printerr(s:String) {
		#if hxnodejs js.Node.console.error(s) #else Sys.println(s) #end;
	}

	public static function stripBOM(text:String):String {
		return if (StringTools.fastCodeAt(text, 0) == 0xFEFF) text.substring(1) else text;
	}

	public static function createDirectory(dir:String) {
		var tocreate = [];
		while (!FileSystem.exists(dir) && dir != '') {
			var parts = dir.split("/");
			tocreate.unshift(parts.pop());
			dir = parts.join("/");
		}
		for (part in tocreate) {
			if (part == '')
				continue;
			dir += "/" + part;
			try {
				FileSystem.createDirectory(dir);
			} catch (e:Any) {
				throw "unable to create dir: " + dir;
			}
		}
	}
}