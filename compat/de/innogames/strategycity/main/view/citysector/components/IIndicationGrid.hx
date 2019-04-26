package de.innogames.strategycity.main.view.citysector.components;

import flash.geom.Rectangle;

/**
 * Generic abstraction layer for a common API which has to be exposed by indication grid container.
 *
 * @see IIsoTile
 */
interface IIndicationGrid {
	var visible #if !flash (get, set) #end:Bool;
	var snappingEnabled(never, set):Bool;
	var colorPlacementRectangleAutomatically(get, set):Bool;
	var placementRectangleUseColorValid(get, set):Bool;
	var placementRectangleUseColorValidOrSwap(never, set):Int;
	var color(get, never):UInt;

	/**
	 * Adds a new PlacementRect at given coordinates.
	 *
	 * @param tileX X coordinate in tiles
	 * @param tileY Y coordinate in tiles
	 * @param tileWidth Width of PlacementRect in tiles
	 * @param tileLength Length of PlacementRect in tiles
	 */
	function addPlacementRectangle(tileX:Int, tileY:Int, tileWidth:Int, tileLength:Int):Void;

	/**
	 * Removes PlacementRect.
	 */
	function removePlacementRectangle():Void;

	/**
	 * Sets dimensions of default Placement Rectangle.
	 *
	 * @param tileWidth Width of Placement Rect in tiles
	 * @param tileLength Length of Placement Rect in tiles
	 */
	function setPlacementRectangleSize(tileWidth:Int, tileLength:Int):Void;

	/**
	 * Draws a given placement rectangle in a given color
	 * @param placementRect Rectangle to be drawn
	 * @param color Color of the rectangle
	 */
	function drawPlacementRectangle(placementRect:Rectangle, color:UInt):Void;

	/**
	 * Draws a given rectangle path in a given color.
	 * @param path Path to be drawn
	 * @param color Color
	 */
	function drawPlacementPath(path:flash.Vector<Rectangle>, color:UInt):Void;

	/**
	 * Removes the drawn rectangle path
	 */
	function removePlacementPath():Void;

	/**
	 * Destroys Engine instance and frees up allocated memory.
	 */
	function destroy():Void;
}
