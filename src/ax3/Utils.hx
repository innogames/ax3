package ax3;

import sys.FileSystem;

class Utils {
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