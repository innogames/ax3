package ax3;

import ax3.ParseTree;
import ax3.TypedTree;

class GenAS3 extends PrinterBase {
	public function writeModule(m:TModule) {
		printPackage(m.pack);
		printTrivia(m.eof.leadTrivia);
	}

	function printPackage(p:TPackageDecl) {
		printDecl(p.decl);
	}

	function printDecl(d:TDecl) {
		switch (d) {
			case TDClass(c): printClassClass(c);
		}
	}

	function printClassClass(c:TClassDecl) {

	}
}
