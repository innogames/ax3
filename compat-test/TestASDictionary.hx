import utest.Assert.*;

class TestASDictionary extends utest.Test {
	function testAsDictionary() {
		var dict = new ASDictionary<Int, String>();
		equals(dict, ASDictionary.asDictionary(dict));
	}
}
