#if flash
class NativePropertyValueIterator<K,V> {
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

	public inline function next():{key:K, value:V} {
		var result = untyped __forin__(collection, index);
		return {key: result, value: untyped collection[result]};
	}
}
#end