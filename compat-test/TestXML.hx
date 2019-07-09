import utest.Assert.*;

class TestXML extends utest.Test {
	#if flash
	function setupClass() {
		flash.xml.XML.prettyPrinting = false;
	}

	function teardownClass() {
		flash.xml.XML.prettyPrinting = true;
	}
	#end

	function testNew() {
		var x = new compat.XML("<p>Hello</p>");
		equals("<p>Hello</p>", x.toXMLString());
	}

	function testAppendChild() {
		var x = new compat.XML("<ul/>");
		x.appendChild(new compat.XML("<li>1</li>"));
		x.appendChild(new compat.XML("<li>2</li>"));
		equals("<ul><li>1</li><li>2</li></ul>", x.toXMLString());
	}

	function testAttribute() {
		var x = new compat.XML('<item name="Cow"/>');
		equals("Cow", x.attribute("name"));
		equals("", x.attribute("id"));
	}

	function testSetAttribute() {
		var x = new compat.XML('<item name="Cow"/>');
		x.setAttribute("name", "Dog");
		x.setAttribute("id", "42");
		equals('<item name="Dog" id="42"/>', x.toXMLString());
	}

	function testChild() {
		var x = new compat.XML('<ul><li>1</li><notli/><li>2</li></ul>');
		equals("<li>1</li>\n<li>2</li>", x.child("li").toXMLString());
	}

	function testChildren() {
		var x = new compat.XML('<ul><li>1</li><notli/><li>2</li></ul>');
		equals("<li>1</li>\n<notli/>\n<li>2</li>", x.children().toXMLString());
	}

	function testLocalName() {
		var x = new compat.XML('<element/>');
		equals("element", x.localName());
	}

	function testDescendants() {
		var x = new compat.XML('
			<root>
				<child>
					<a id="1"/>
				</child>
				<a id="2"/>
				<a id="3"><a id="4"/></a>
			</root>
		');
		equals('<a id="1"/>\n<a id="2"/>\n<a id="3"><a id="4"/></a>\n<a id="4"/>', x.descendants("a").toXMLString());
	}

	function testToString() {
		// simple
		var x = new compat.XML("<a>hello</a>");
		equals("hello", x.toString());

		// complex
		x = new compat.XML("<a>hello<i/></a>");
		equals("<a>hello<i/></a>", x.toString());
	}

	function testXMLListToString() {
		// if there are more than one element - toXMLString is always used
		var x = new compat.XML("<x><a>hello</a><a>bye</a></x>");
		equals("<a>hello</a>\n<a>bye</a>", x.child("a").toString());

		// for a single-element XMLList, toString is called on it
		x = new compat.XML("<x><a>hello</a></x>");
		equals("hello", x.child("a").toString());

		// ...but of course not if it has "complex" content
		x = new compat.XML("<x><a><inner/>hello</a></x>");
		equals("<a><inner/>hello</a>", x.child("a").toString());
	}

	function testXMLListIterator() {
		var x = new compat.XML('<x><a id="1"/><a id="2"/></x>');
		var i = 1;
		for (child in x.child("a")) {
			equals('<a id="$i"/>', child.toXMLString());
			i++;
		}
		equals(3, i);
	}

	function testXMLListChild() {
		var x = new compat.XML('
			<root>
				<x>
					<a id="1"/>
					<b id="1"/>
				</x>
				<x>
					<a id="2"/>
					<b id="2"/>
				</x>
			</root>
		');
		equals('<a id="1"/>\n<a id="2"/>', x.child("x").child("a").toXMLString());
	}

	function testXMLListAttribute() {
		var x = new compat.XML('
			<root>
				<x id="1"/>
				<x id="2"/>
			</root>
		');
		equals('12', x.child("x").attribute("id"));
	}
}
