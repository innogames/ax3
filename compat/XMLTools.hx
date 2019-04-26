import flash.xml.XML;
import flash.xml.XMLList;

class XMLTools {
	public static function keys(xml:XML):Iterator<String> { return null; }
	public static function iterator(xml:XML):Iterator<XML> { return null; }
}

class XMLListTools {
	public static inline function keys(xml:XML) return new NativePropertyIterator<String>(xml);
	public static inline function iterator(xml:XMLList) return new NativeValueIterator<XML>(xml);
}
