import utest.Assert.*;

class TestASAny extends utest.Test {
	function testToBool() {
		inline function b(v:ASAny):Bool return v;

		isFalse(b(null));

		isTrue(b(true));
		isFalse(b(false));

		isTrue(b(1));
		isTrue(b(0.1));
		isFalse(b(0));
		isFalse(b(Math.NaN));

		isTrue(b("HI"));
		isTrue(b(" "));
		isTrue(b("\t"));
		isTrue(b("0"));
		isFalse(b(""));

		isTrue(b({}));
		isTrue(b([]));
		isTrue(b(this));
	}

	function testNot() {
		inline function b(v:ASAny):Bool return !!v;

		isFalse(b(null));

		isTrue(b(true));
		isFalse(b(false));

		isTrue(b(1));
		isTrue(b(0.1));
		isFalse(b(0));
		isFalse(b(Math.NaN));

		isTrue(b("HI"));
		isTrue(b(" "));
		isTrue(b("\t"));
		isTrue(b("0"));
		isFalse(b(""));

		isTrue(b({}));
		isTrue(b([]));
		isTrue(b(this));
	}

	function testToInt() {
		inline function i(v:ASAny):Int return v;

		equals(0, i(null));

		equals(0, i(Math.NaN));
		equals(1, i(1));
		equals(3, i(3.5));
		equals(0, i(0.1));
		equals(0, i(0));

		equals(1, i(true));
		equals(0, i(false));

		equals(0, i(""));
		equals(0, i(" "));
		equals(0, i("lol"));
		equals(5, i("5"));
		equals(5, i("5.3"));
		equals(-5, i("-5"));
		equals(-5, i("-5.3"));

		equals(0, i({}));
		equals(0, i([]));
		equals(3, i([3])); // yeah
		equals(0, i(this));
	}

	function testToUInt() {
		inline function i(v:ASAny):UInt return v;

		equals(0, i(null));

		equals(0, i(Math.NaN));
		equals(1, i(1));
		equals(3, i(3.5));
		equals(0, i(0.1));
		equals(0, i(0));

		equals(1, i(true));
		equals(0, i(false));

		equals(0, i(""));
		equals(0, i(" "));
		equals(0, i("lol"));
		equals(5, i("5"));
		equals(5, i("5.3"));
		equals(4294967291, (i("-5") : Float));
		equals(4294967291, (i("-5.3") : Float));

		equals(0, i({}));
		equals(0, i([]));
		equals(3, i([3])); // yeah
		equals(0, i(this));
	}

	function testToFloat() {
		inline function f(v:ASAny):Float return v;

		equals(0, f(null));

		equals(1, f(true));
		equals(0, f(false));

		isTrue(Math.isNaN(f(Math.NaN)));
		equals(1.0, f(1));
		equals(3.5, f(3.5));
		equals(0.1, f(0.1));
		equals(0.0, f(0));


		equals(0, f(""));
		equals(0, f(" "));
		isTrue(Math.isNaN(f("lol")));
		equals(5, f("5"));
		equals(5.3, f("5.3"));
		equals(-5, f("-5"));
		equals(-5.3, f("-5.3"));

		isTrue(Math.isNaN(f({})));
		equals(0, f([])); // yeah
		equals(3, f([3])); // yeah
		isTrue(Math.isNaN(f(this)));
	}

	function testToString() {
		inline function s(v:ASAny):String return v;

		equals("hello", s("hello"));
		equals(null, s(null));

		equals("true", s(true));
		equals("false", s(false));

		equals("NaN", s(Math.NaN));
		equals("1", s(1));
		equals("3.5", s(3.5));
		equals("0.1", s(0.1));
		equals("0", s(0.0));
		equals(toString(), s(this));
	}

	function toString() return "hallo!";

	function testGetSet() {
		var o:ASAny = {a: 10};
		equals(10, o.a);
		equals(15, o.a = 15);
		equals(15, o.a);

		var o:ASAny = {a: 10};
		equals(10, o["a"]);
		equals(15, o["a"] = 15);
		equals(15, o["a"]);

		var c:ASAny = new Cls(new Cls(null));
		equals(10, c.field);
		equals(15, c.field = 15);
		equals(15, c.field);

		equals(20, c.prop);
		equals(25, c.prop = 25);
		equals(25, c.prop);

		equals(28, c.meth(3));
		equals(28, getValue(c.meth, 3));

		equals(10, c.sub.field);
		equals(15, c.sub.field = 15);
		equals(15, c.sub.field);

		equals(20, c.sub.prop);
		equals(25, c.sub.prop = 25);
		equals(25, c.sub.prop);

		equals(28, c.sub.meth(3));
		equals(28, getValue(c.sub.meth, 3));

		var c:ASAny = new Cls(new Cls(null));
		equals(10, c["field"]);
		equals(15, c["field"] = 15);
		equals(15, c["field"]);

		equals(20, c["prop"]);
		equals(25, c["prop"] = 25);
		equals(25, c["prop"]);

		equals(28, c["meth"](3));
		equals(28, getValue(c["meth"], 3));

		equals(10, c["sub"]["field"]);
		equals(15, c["sub"]["field"] = 15);
		equals(15, c["sub"]["field"]);

		equals(20, c["sub"]["prop"]);
		equals(25, c["sub"]["prop"] = 25);
		equals(25, c["sub"]["prop"]);

		equals(28, c["sub"]["meth"](3));
		equals(28, getValue(c["sub"]["meth"], 3));
	}

	function getValue(f:Int->Int, v:Int):Int return f(v);

	function testHasOwnProperty() {
		var o:ASAny = {a: 10};
		isTrue(o.hasOwnProperty("a"));
		isFalse(o.hasOwnProperty("b"));

		var c:ASAny = new Cls(null);
		isTrue(c.hasOwnProperty("field"));
		isTrue(c.hasOwnProperty("prop"));
		isTrue(c.hasOwnProperty("sub"));
		isTrue(c.hasOwnProperty("meth"));
		isFalse(c.hasOwnProperty("wat"));
	}

	@:analyzer(no_optimize)
	function testArithmetics() {
		var a:ASAny = 1;
		var b:ASAny = 2;

		equals(3, a + b);
		equals(1, b - a);

		equals(3, a + 2);
		equals(3, 2 + a);
		equals(1, 2 - a);
		equals(1, b - 1);

		a = 0.5;
		equals(2.5, a + b);
		equals(2.5, a + 2);
		equals(2.5, 2 + a);
		equals(1.5, b - a);
		equals(1.5, 2 - a);
		equals(-0.5, a - 1);

		a = "a";
		b = "b";
		equals("ab", a + b);
		equals("ab", a + "b");
		equals("ba", "b" + a);
		equals("ba", b + a);
	}

	function testMixedArray() {
		var x:ASAny = [1, false, "hi"];
		same([1, false, "hi"], x);

		var x:ASObject = [1, false, "hi"];
		same([1, false, "hi"], x);
	}
}

private class Cls {
	public var sub:Null<Cls>;
	public var field:Int = 10;
	public var prop(get,set):Int;

	var _prop:Int = 20;
	function get_prop() return _prop;
	function set_prop(v) return _prop = v;

	public function new(sub) {
		this.sub = sub;
	}

	public function meth(x) return _prop + x;
}
