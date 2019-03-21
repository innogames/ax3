
abstract ASDictionary<K,V>(flash.utils.Dictionary) from flash.utils.Dictionary {
	@:op([]) inline function get(key:K):Null<V> {
		return this[cast key];
	}

	@:op([]) inline function set(key:K, v:V):V {
		return this[cast key] = v;
	}

	public inline function iterator():Iterator<K> {
		return null;
	}

	public inline function remove(key:K):Bool {
		return untyped __delete__(this, key);
	}
}
