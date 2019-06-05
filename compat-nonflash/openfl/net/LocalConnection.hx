package openfl.net;

class LocalConnection extends openfl.events.EventDispatcher {
	public var client:ASObject;
	public function allowDomain(domain:String):Void {}
	public function connect(connectionName:String):Void {}
	public final send:Dynamic = Reflect.makeVarArgs(function(args) {});
}