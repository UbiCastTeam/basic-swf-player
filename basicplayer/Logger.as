package basicplayer {
	import flash.text.TextField;
	import flash.text.TextFormat;
	import flash.display.Stage;

	import flash.external.ExternalInterface;
	import flash.filters.DropShadowFilter;

	public class Logger {
		public var enabled:Boolean = false;
		public var output:TextField = null;
		public var jsFunction:String = "console.log";
		private var _quotePattern:RegExp = /'/g; //'
		private static var _instance:Logger;

		public function Logger() {
		}

		public function log(level:String, txt:String):void {
			if (!enabled)
				return;
			if (output != null)
				output.appendText(level + " " + txt + "\n");
			if (ExternalInterface.available) {
				ExternalInterface.call("setTimeout", jsFunction + "('" + (ExternalInterface.objectID ? ExternalInterface.objectID : "no_object_id") + "','" + level + "','" + txt.replace(_quotePattern, "’") + "')", 0);
			}
		}

		public function outputToStage(stage:Stage):void {
			if (!enabled || output != null)
				return;
			var outputFormat:TextFormat = new TextFormat();
			outputFormat.size = 16;
			outputFormat.bold = true;
			output = new TextField();
			output.defaultTextFormat = outputFormat;
			output.textColor = 0xeeeeee;
			output.width = stage.stageWidth;
			output.height = stage.stageHeight;
			output.multiline = true;
			output.wordWrap = true;
			output.border = false;
			output.filters = [new DropShadowFilter(1, 0x000000, 45, 1, 2, 2, 1)];
			output.text = "Log ready.\n";
			stage.addChild(output);
		}
		public function removeOutput():void {
			if (!output)
				return;
			output.parent.removeChild(output);
			output = null;
		}

		public static function get():Logger {
			if (!_instance)
				_instance = new Logger();
			return _instance;
		}

		public static function debug(txt:String):void {
			if (!_instance)
				_instance = new Logger();
			_instance.log("DEBUG", txt);
		}

		public static function error(txt:String):void {
			if (!_instance)
				_instance = new Logger();
			_instance.log("ERROR", txt);
		}

		public static function setSize(width:Number, height:Number):void {
			if (!_instance)
				_instance = new Logger();
			if (!_instance.output)
				return;
			_instance.output.width = width;
			_instance.output.height = height;
		}
	}
}
