#if flash
class NativeValueIterator<V> {
	var collection:Dynamic;
	var index:Int;

	public inline function new(collection:Dynamic) {
		this.collection = collection;
		this.index = 0;
	}

	public inline function hasNext():Bool {
		var c = collection;
		var i = index;
		var result = untyped __has_next__(c, i);
		collection = c;
		index = i;
		return result;
	}

	public inline function next():V {
		return untyped __foreach__(collection, index);
	}
}
#end