import sys.FileSystem;
import ParseTree;

class Utils {

	public static function dotPathToArray(d:DotPath):Array<String> {
		return foldSeparated(d, [], (part, acc) -> acc.push(part.text));
	}

	public static function foldSeparated<T,S>(d:Separated<T>, acc:S, f:(T,S)->Void):S {
		f(d.first, acc);
		for (p in d.rest) {
			f(p.element, acc);
		}
		return acc;
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