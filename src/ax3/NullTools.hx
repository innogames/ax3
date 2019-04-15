package ax3;

@:nullSafety
class NullTools {
	public static inline function sure<T>(n:Null<T>):T {
		return if (n == null) throw "unexpected null value!" else n;
	}
}
