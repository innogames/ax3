import ParseTree;

class Typer2 {
	public function new() {}

	public function process(files:Array<File>) {
		var structure = Structure.build(files);
		sys.io.File.saveContent("structure.txt", structure.dump());
	}
}
