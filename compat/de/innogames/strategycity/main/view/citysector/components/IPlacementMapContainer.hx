package de.innogames.strategycity.main.view.citysector.components;

/**
 * Generic abstraction layer for a common API which has to be exposed by placement map containers.
 */
interface IPlacementMapContainer {
	var visible #if !flash (get, set) #end:Bool;

	/**
	 *  Redraws a specific area of the grid
	 */
	function redrawGridArea(tileX:Int, tileY:Int, tileWidth:Int, tileLength:Int):Void;

	/**
	 *  Redraws placement grid
	 */
	function redrawPlacementGrid():Void;

	/**
	 * Destroys Engine instance and frees up allocated memory.
	 */
	function destroy():Void;
}
