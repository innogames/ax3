package openfl.xml;

abstract XMLList(Array<XML>) to Array<XML> {
	public var length(get,never):Int; inline function get_length() return this.length;
	
	public function new(array:Array<XML>) {
		this = array;
	}

	public function child(name:String):XMLList return null;
	public function attribute(name:String):XMLList return null;
	public function toString():String return null;

	@:op([]) function get(i:Int):XML return this[i];
	@:op([]) function set(i:Int, value:XML):XML return this[i] = value;

	public inline function keys() {
		return (null : Iterator<String>);
	}
	
	public inline function iterator() {
		return this.iterator();
	}

}
