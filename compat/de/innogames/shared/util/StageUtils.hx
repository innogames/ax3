package de.innogames.shared.util;

import flash.display.Stage;
import flash.display.StageQuality;

class StageUtils {
	public static inline function getQuality(stage: Stage): StageQuality {
		// There's a bug in Flash because of which Stage.quality returns an UPPERCASE value
		// instead of one of the values defined in StageQuality constants, so this method
		// takes care of this
		#if flash
		return cast (cast stage.quality : String).toLowerCase();
		#else
		return stage.quality;
		#end
	}
}
