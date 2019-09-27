class ReverseIntIterator {
	/**
		Create a backwards int iterator from an `IntIterator`.
		This will iterate over the same numbers as the given `IntIterator`, but in reverse.
	**/
	@:access(IntIterator)
	public static inline function reverse(i:IntIterator) {
		return new ReverseIntIterator(i.max - 1, i.min);
	}

	var i:Int;
	var end:Int;

	inline function new(start:Int, end:Int) {
		this.i = start;
		this.end = end;
	}

	public inline function hasNext() {
		return i >= end;
	}

	public inline function next() {
		return i--;
	}
}
