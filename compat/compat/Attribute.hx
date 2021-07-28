package compat;

@:transitive abstract Attribute(String) from String to String {

	@:op(a == b) private inline function equal(b: Any): Bool return this == b || (this == '' && b == null);
	@:op(a != b) private inline function notEqual(b: Any): Bool return !equal(b);
	@:op(a + b) private inline function add(b: String): String return this + b;

}