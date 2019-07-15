import utest.Assert.*;

class TestASCompat extends utest.Test {
	function testProcessNull() {
		equals(0, ASCompat.processNull((null : Null<Int>)));
		equals(0, ASCompat.processNull((null : Null<UInt>)));

		equals(false, ASCompat.processNull((null : Null<Bool>)));

		floatEquals(0, ASCompat.processNull((null : Null<Float>)));

		var undefined = new ASDictionary<Int,Float>()[10];
		floatEquals(Math.NaN, ASCompat.processNull((undefined : Null<Float>)));
	}

	function testIsAnyVector() {
		isTrue(ASCompat.isVector(new flash.Vector<String>(), (_:ASAny)));
	}
}
