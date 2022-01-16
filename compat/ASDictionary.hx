#if openfl
private typedef Dictionary<K,V> = openfl.utils.Dictionary<K,V>;
#else
private typedef Dictionary<K,V> = flash.utils.Dictionary;
#end

abstract ASDictionary<K,V>(Dictionary<K,V>) from Dictionary<K,V> to Dictionary<K,V> { //TODO: remove implicit cast?
	public extern inline function new(weakKeys : Bool = false) {
		this = new Dictionary<K,V>(weakKeys);
	}

	@:op([]) public inline function get(key:K):Null<V> {
		#if flash
		return untyped this[key];
		#else
		return this.get(key);
		#end
	}

	@:op([]) public inline function set(key:K, value:V):Null<V> {
		#if flash
		return untyped this[key] = value;
		#else
		return this.set(key, value);
		#end
	}

	public inline function exists(key:K):Bool {
		#if flash
		return untyped __in__(key, this);
		#else
		return this.exists(key);
		#end
	}

	public inline function remove(key:K):Bool {
		#if flash
		return untyped __delete__(this, key);
		#else
		return this.remove(key);
		#end
	}

	public inline function keys() {
		#if flash
		return new NativePropertyIterator<K>(this);
		#else
		return this.iterator();
		#end
	}

	public inline function iterator() {
		#if flash
		return new NativeValueIterator<V>(this);
		#else
		return this.each();
		#end
	}

	public inline function keyValueIterator() {
		#if flash
		return new NativePropertyValueIterator<K,V>(this);
		#else
		return this.keyValueIterator();
		#end
	}

	public static inline function asDictionary<K,V>(v:Any):Null<Dictionary<K,V>> {
		#if flash
		return flash.Lib.as(v, flash.utils.Dictionary);
		#else
		return if (Std.isOfType(v, haxe.Constraints.IMap)) v else null;
		#end
	}

	public static final type = #if flash flash.utils.Dictionary #else haxe.Constraints.IMap #end;
}
