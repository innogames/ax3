package ax3;

import ax3.ParseTree;
import ax3.TypedTree;

class GenAS3 {
	final buf = new StringBuf();

	public function new() {
	}

	public function getString() {
		return buf.toString();
	}

	public function writeModule(m:TModule) {
		writePackage(m.pack);
	}

	function writePackage(p:TPackageDecl) {
		writeDecl(p.decl);
	}

	function writeDecl(d:TDecl) {
		switch (d) {
			case TDClass(c):
		}
	}

	function writeClass(c:TClassDecl) {

	}
}
