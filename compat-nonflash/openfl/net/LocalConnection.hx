package openfl.net;

extern class LocalConnection extends openfl.events.EventDispatcher {
	public var client:ASObject;
	public function allowDomain(domain:String):Void;
	public function connect(connectionName:String):Void;
	public function send(connectionName:String, methodName:String, args:haxe.extern.Rest<Dynamic>):Void;
}