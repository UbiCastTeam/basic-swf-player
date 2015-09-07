package basicplayer {
	public class Utils {
		public static function parseStr (str:String):Object {
			var hash:Object = {},
				arr1:Array, arr2:Array;

			str = unescape(str).replace(/\+/g, " ");

			arr1 = str.split('&');
			if (!arr1.length)
				return {};

			for (var i:uint = 0, length:uint = arr1.length; i < length; i++) {
				arr2 = arr1[i].split('=');
				if (!arr2.length)
					continue;
				hash[trim(arr2[0])] = trim(arr2[1]);
			}
			return hash;
		}

		public static function trim(str:String):String {
			if (!str)
				return str;
			return str.toString().replace(/^\s*/, '').replace(/\s*$/, '');
		}

		public static function hasIllegalChar(s:String, isUrl:Boolean):Boolean {
			var illegals:String = "' \" ( ) { } * + \\ < >";
			if (isUrl)
				illegals = "\" { } \\ < >";
			if (Boolean(s)) { // Otherwise exception if parameter null.
				for each (var illegal:String in illegals.split(' ')) {
					if (s.indexOf(illegal) >= 0)
						return true; // Illegal char found
				}
			}
			return false;
		}

		public static function toJSON(obj:Object):String {
			var result:String = "";
			if (obj is String) {
				result = "'"+obj.toString().replace(/'/g, "’")+"'"; //"
			} else if (obj is Boolean) {
				result = obj.toString();
			} else if (obj is Number) {
				result = obj.toString();
			} else {
				for (var key:String in obj) {
					if (result != "")
						result += ",";
					result += "'"+key+"':"+toJSON(obj[key]);
				}
				if (result != "")
					result = "{"+result+"}";
			}
			if (result == "")
				return "null";
			return result;
		}
	}
}
