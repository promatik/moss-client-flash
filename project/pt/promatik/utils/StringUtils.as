package pt.promatik.utils
{
	/**
	 * MOSS String Utils
	 * @author Toni Almeida
	 */
	public class StringUtils
	{
		public function StringUtils()
		{
		
		}
		
		public static function stringify(values:*):String
		{
			return JSON.stringify(values);
		}
		
		public static function parse(values:String):Object
		{
			return JSON.parse(values);
		}
		
		public static function b8encode(src:String):String
		{
			var result:String = "";
			for (var i:int = 0; i < src.length; i++)
				result += src.charCodeAt(i).toString(16);
			return result;
		}
		
		public static function b8decode(src:String):String
		{
			var result:String = "";
			for (var i:int = 0; i < src.length; i += 2)
				result += String.fromCharCode(parseInt(src.substr(i, 2), 16));
			return result;
		}
	}
}