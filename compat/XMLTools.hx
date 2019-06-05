import flash.xml.XML;
import flash.xml.XMLList;

class XMLTools {
	public static function keys(xml:XML):Iterator<String> { return null; }
	public static function iterator(xml:XML):Iterator<XML> { return null; }
}

class XMLListTools {
	public static inline function keys(xml:XML) {
		#if flash
		return new NativePropertyIterator<String>(xml);
		#else
		return (null : Iterator<String>);
		#end
	}
	
	public static inline function iterator(xml:XMLList) {
		#if flash
		return new NativeValueIterator<XML>(xml);
		#else
		return (null : Iterator<XML>);
		#end
	}
	
}
