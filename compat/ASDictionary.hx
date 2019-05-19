#if openfl
private typedef Dictionary<K,V> = openfl.utils.Dictionary<K,V>;
#else
private typedef Dictionary<K,V> = flash.utils.Dictionary;
#end

abstract ASDictionary<K,V>(Dictionary<K,V>) from Dictionary<K,V> { //TODO: remove implicit cast?
	public inline function new(weakKeys : Bool = false) {
		this = new Dictionary<K,V>(weakKeys);
	}

	@:op([]) public inline function get(key:K):Null<V> {
		return untyped this[key];
	}

	@:op([]) public inline function set(key:K, value:V):Null<V> {
		return untyped this[key] = value;
	}

	public inline function exists(key:K):Bool {
		return untyped __in__(key, this);
	}

	public inline function remove(key:K):Bool {
		return untyped __delete__(this, key);
	}

	public inline function keys():NativePropertyIterator<K> {
		return new NativePropertyIterator(this);
	}

	public inline function iterator():NativeValueIterator<V> {
		return new NativeValueIterator(this);
	}

	public inline function keyValueIterator():NativePropertyValueIterator<K, V> {
		return new NativePropertyValueIterator(this);
	}
}
