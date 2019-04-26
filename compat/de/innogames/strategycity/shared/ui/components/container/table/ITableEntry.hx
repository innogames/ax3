package de.innogames.strategycity.shared.ui.components.container.table;

/**
 *  Table Entry interface. Every entity that implements this interface can be added to the table.
 */
interface ITableEntry {
	var x #if !flash (get, set) #end:Float;
	var y #if !flash (get, set) #end:Float;
	var right(get, never):Float;
	var bottom(get, never):Float;

	/**
	 * Returns the width of the table entry
	 */
	function getWidth():Float;

	/**
	 * Returns the height of the table entry
	 */
	function getHeight():Float;

	/**
	 * Draws the table entry
	 */
	function draw():Void;
}
