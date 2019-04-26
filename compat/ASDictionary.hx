
abstract ASDictionary<K,V>(flash.utils.Dictionary) from flash.utils.Dictionary {
	@:op([]) inline function get(key:K):Null<V> {
		return this[cast key];
	}

	@:op([]) inline function set(key:K, v:V):V {
		return this[cast key] = v;
	}

	public inline function keys():NativePropertyIterator<K> {
		return new NativePropertyIterator(this);
	}

	public inline function iterator():NativeValueIterator<V> {
		return new NativeValueIterator(this);
	}

	public inline function remove(key:K):Bool {
		return untyped __delete__(this, key);
	}

	public inline function exists(key:K):Bool {
		return untyped __in__(key, this);
	}
}

private class NativePropertyIterator<K> {
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

	public inline function next():K {
		var i = index;
		var result = untyped __forin__(collection, i);
		index = i;
		return result;
	}
}

private class NativeValueIterator<V> {
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
		var i = index;
		var result = untyped __foreach__(collection, i);
		index = i;
		return result;
	}
}
