class Main {
	static function main() {
		utest.UTest.run([
			new TestASAny(),
			new TestXML(),
			new TestASCompat(),
			new TestASDictionary(),
		]);
	}
}
