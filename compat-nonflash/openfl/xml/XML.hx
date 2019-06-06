package openfl.xml;

import Xml as StdXml;

abstract XML(StdXml) from StdXml to StdXml {
	public inline function new(x:Any) {
		this = StdXml.parse(Std.string(x)).firstElement();
	}

	public function appendChild(x:XML):Void {
		this.addChild(x);
	}

	public function attribute(name:String):XMLList {
		return new XMLList([StdXml.createPCData(this.get(name))]);
	}

	public function child(name:String):XMLList {
		return new XMLList([for (x in this.elementsNamed(name)) x]);
	}

	public function descendants(name:String):XMLList {
		var r = new Array<XML>();
		for (e in this.elements()) {
			if (e.nodeName == name)
				r.push(e);
			else
				r = r.concat((e : XML).descendants(name));
		}
		return new XMLList(r);
	}

	public inline function toString():String {
		return this.toString();
	}

	public inline function toXMLString():String {
		return toString();
	}
}
