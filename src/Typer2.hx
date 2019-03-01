import ParseTree;

class Typer2 {
	public function new() {}

	public function process(files:Array<File>, libs:Array<String>) {
		var structure = Structure.build(files, libs);
		sys.io.File.saveContent("structure.txt", structure.dump());
	}
}
