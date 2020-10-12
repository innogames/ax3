package ax3;

import haxe.io.Path;

class Run {
	static function main() {
		// haxelib run runs the script with the current directory set to the library dir,
		// while passing actual current directory as a last argument, so we have to do this little dance
		var ax3Dir = Sys.getCwd();
		var args = Sys.args();
		Sys.setCwd(args.pop());
		var jarFile = Path.join([ax3Dir, "converter.jar"]);
		Sys.exit(Sys.command("java", ["-jar", jarFile].concat(args)));
	}
}
