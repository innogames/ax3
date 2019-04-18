package flash.display3D;

enum abstract Context3DTextureFormat(String) from String to String {
	var BGRA = "bgra";
	var BGRA_PACKED = "bgraPacked4444";
	var BGR_PACKED = "bgrPacked565";
	var COMPRESSED = "compressed";
	var COMPRESSED_ALPHA = "compressedAlpha";
	var RGBA_HALF_FLOAT = "rgbaHalfFloat";
}
