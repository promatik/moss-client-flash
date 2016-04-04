package pt.promatik.vo 
{
	/**
	 * @author Toni Almeida
	 */
	public class UserVO 
	{
		public static const MESSAGE_DELIMITER:String = "&;";
		
		public var id:String;
		public var room:String;
		public var status:String;
		public var online:Boolean = true;
		public var available:Boolean = true;
		public var data:Object = null;
		
		public function UserVO(id:String="", room:String="", status:String="") 
		{
			this.id = id;
			this.room = room;
			this.status = status;
		}
		
		public function parse(msg:String):void 
		{
			var result:Array = msg.split(MESSAGE_DELIMITER);
			if (result.length > 0) id = result[0];
			if (result.length > 1) room = result[1];
			if (result.length > 2) status = result[2];
			if (result.length > 3) online = result[3] == "on";
			if (result.length > 4) available = result[4] == "1";
			if (result.length > 5) data = JSON.parse(result[5]);
		}
	}
}