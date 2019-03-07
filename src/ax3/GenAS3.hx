package ax3;

import ax3.ParseTree;
import ax3.TypedTree;

class GenAS3 extends PrinterBase {
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
