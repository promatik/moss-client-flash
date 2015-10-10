package pt.promatik
{
	import pt.promatik.vo.UserVO;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.events.SecurityErrorEvent;
	import flash.net.Socket;
	import flash.system.Security;
	import flash.utils.Dictionary;
	import idv.cjcat.signals.Signal;
	
	/**
	 * MOSS v0.1
	 * @author Toni Almeida
	 */
	public class MOSS
	{
		private var _request:uint = 1;
		private var _reqCallback:Dictionary = new Dictionary();
		
		private var _port:int = 30480;
		private var _host:String = "localhost";
		private var _id:String = "";
		private var _room:String = "default";
		private var _status:String = "1";
		
		private var _retryConnection:int = 3;
		private var _retryDelay:uint = 1800;
		private var _attempts:int = 0;
		private var _socketConnected:Boolean = false;
		private var _connected:Boolean = false;
		private var _socket:Socket;
		private var _socketResponde:String = "";
		private var _cleanPattern:RegExp = /\|/g;
		
		private var _connectSignal:Signal = new Signal();
		private var _loggedInSignal:Signal = new Signal();
		private var _loggedOutSignal:Signal = new Signal();
		private var _closeSignal:Signal = new Signal(Event);
		private var _errorSignal:Signal = new Signal(Event);
		private var _doubleLoginSignal:Signal = new Signal();
		private var _statusUpdatedSignal:Signal = new Signal(String);
		private var _userSignal:Signal = new Signal(UserVO);
		private var _usersSignal:Signal = new Signal(Vector.<UserVO>);
		private var _usersCountSignal:Signal = new Signal(int);
		private var _invokeSignal:Signal = new Signal(Boolean);
		private var _invokeOnRoomSignal:Signal = new Signal(Boolean);
		private var _invokeOnAllSignal:Signal = new Signal(Boolean);
		private var _messageSignal:Signal = new Signal(Object, String, UserVO);
		
		public function get id():String { return _id; }
		public function get room():String { return _room; }
		public function get status():String { return _status; }
		public function get connected():Boolean { return _connected; }
		public function get serverConnection():Boolean { return _socketConnected; }
		
		public function get connectSignal():Signal { return _connectSignal; }
		public function get loggedInSignal():Signal { return _loggedInSignal; }
		public function get loggedOutSignal():Signal { return _loggedOutSignal; }
		public function get closeSignal():Signal { return _closeSignal; }
		public function get errorSignal():Signal { return _errorSignal; }
		public function get doubleLoginSignal():Signal { return _doubleLoginSignal; }
		public function get statusUpdatedSignal():Signal { return _statusUpdatedSignal; }
		public function get userSignal():Signal { return _userSignal; }
		public function get usersSignal():Signal { return _usersSignal; }
		public function get usersCountSignal():Signal { return _usersCountSignal; }
		public function get invokeSignal():Signal { return _invokeSignal; }
		public function get invokeOnRoomSignal():Signal { return _invokeOnRoomSignal; }
		public function get invokeOnAllSignal():Signal { return _invokeOnAllSignal; }
		public function get messageSignal():Signal { return _messageSignal; }
		
		// --------------------
		// Constructor
		// --------------------
		
		public function MOSS(host:String = "localhost", port:int = 30480, retryConnection:uint = 3, retryDelay:uint = 1500)
		{
			_port = port;
			_host = host;
			_retryConnection = retryConnection;
			_retryDelay = retryDelay;
			
			Security.allowDomain(host);
			
			_socket = new Socket();
			_socket.addEventListener(Event.CONNECT, onConnect);
			_socket.addEventListener(Event.CLOSE, onClose);
			_socket.addEventListener(IOErrorEvent.IO_ERROR, onError);
			_socket.addEventListener(ProgressEvent.SOCKET_DATA, onResponse);
			_socket.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecError);
			
			_socket.timeout = _retryDelay;
			init();
		}
		
		// --------------------
		// Private
		// --------------------
		
		private function init():void
		{
			trace("MOSS :: Trying to connect" + (_attempts ? ": " + _attempts + " attempt" : ""));
			_connected = _socketConnected = false;
			_socket.connect(_host, _port);
		}
		
		private function destroy():void
		{
			_socket.close();
			_socket.removeEventListener(Event.CONNECT, onConnect);
			_socket.removeEventListener(Event.CLOSE, onClose);
			_socket.removeEventListener(IOErrorEvent.IO_ERROR, onError);
			_socket.removeEventListener(ProgressEvent.SOCKET_DATA, onResponse);
			_socket.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecError);
			_socket = null;
		}
		
		private function sendMessage(command:String, callback:Function = null, ... args):void
		{
			if (!_socketConnected) {
				errorSignal.dispatch(new Event(Event.CLOSE));
				closeSignal.dispatch(new Event(Event.CLOSE));
				return;
			}
			
			_request++;
			if(callback != null)
				_reqCallback[_request] = callback;
			
			var message:String = "|#MOSS#<!" + command + "!>#<!" + args.join("&!") + "!>#<!" + _request.toString() + "!>#|";
			_socket.writeUTFBytes(message);
			_socket.flush();
		}
		
		// --------------------
		// Public
		// --------------------
		
		public function connect(id:String, room:String, status:String = "", callback:Function = null):void
		{
			_id = id;
			_room = room;
			_status = status;
			sendMessage("connect", callback, id, room, status);
		}
		
		public function disconnect():void
		{
			sendMessage("disconnect");
		}
		
		public function updateStatus(status:String, callback:Function = null):void
		{
			sendMessage("updateStatus", callback, status);
		}
		
		public function getUser(id:String, room:String = null, callback:Function = null):void
		{
			if (!room)
				room = _room;
			sendMessage("getUser", callback, id, room);
		}
		
		public function getUsers(room:String = null, callback:Function = null):void
		{
			if (!room)
				room = _room;
			sendMessage("getUsers", callback, room);
		}
		
		public function getUsersCount(room:String = null, callback:Function = null):void
		{
			if (!room)
				room = _room;
			sendMessage("getUsersCount", callback, room);
		}
		
		public function invoke(id:String, command:String, values:* = null, room:String = null, callback:Function = null):void
		{
			if (!room)
				room = _room;
			sendMessage("invoke", callback, id, room, command, values ? stringify(values) : "");
		}
		
		public function invokeOnRoom(command:String, values:* = null, room:String = null, callback:Function = null):void
		{
			if (!room)
				room = _room;
			sendMessage("invokeOnRoom", callback, room, command, values ? stringify(values) : "");
		}
		
		public function invokeOnAll(command:String, values:* = null, callback:Function = null):void
		{
			sendMessage("invokeOnAll", callback, command, values ? stringify(values) : "");
		}
		
		public function call(command:String, values:* = null, callback:Function = null):void
		{
			if (command.match("connect|disconnect|updateStatus|getUser|getUsers|getUsersCount|invoke|invokeOnRoom|invokeOnAll|ping|pong"))
				throw new Error("The command '" + command + "' is reserved.");
			
			sendMessage(command, callback, stringify(values));
		}
		
		// --------------------
		// Internal Events
		// --------------------
		
		private function onConnect(e:Event):void
		{
			_socketConnected = true;
			_attempts = 0;
			
			connectSignal.dispatch();
		}
		
		private function onClose(e:Event):void
		{
			init();
			
			_attempts++;
			if (_attempts == _retryConnection)
				closeSignal.dispatch(e);
		}
		
		private function onError(e:Event):void
		{
			errorSignal.dispatch(e);
			onClose(e);
		}
		
		private function onSecError(e:SecurityErrorEvent):void
		{
			errorSignal.dispatch(e);
			onClose(e);
		}
		
		private function onResponse(e:ProgressEvent):void
		{
			while (_socket.bytesAvailable)
			{
				_socketResponde += (_socket.readUTFBytes(1)).toString();
				
				if (_socketResponde.indexOf("|") >= 0)
				{
					processMessage(_socketResponde.replace(_cleanPattern, ""));
					_socketResponde = "";
				}
			}
		}
		
		private function processMessage(message:String):void
		{
			var pattern:RegExp = new RegExp("^#MOSS#<!(.+)!>#<!(.+)?!>#<!(.+)?!>#<!(.+)?!>#$");
			var result:Array = pattern.exec(message);
			
			if (message.match(pattern))
			{
				var action:String = result[1] || "";
				var message:String = result[3] || "";
				var request:String = result[4] || "";
				var from:UserVO = new UserVO();
				from.parse(result[2] || "");
				
				var callback:Function = _reqCallback[request];
				
				var reqStatus:Boolean;
				switch (action)
				{
					case "connected": 
						_connected = true;
						loggedInSignal.dispatch();
						if (callback != null)
							callback();
						break;
					case "disconnected": 
						_connected = false;
						loggedOutSignal.dispatch();
						if (callback != null)
							callback();
						break;
					case "statusUpdated": 
						_status = message;
						statusUpdatedSignal.dispatch(message);
						if (callback != null)
							callback(message);
						break;
					case "user": 
						var user:UserVO = new UserVO();
						user.parse(message);
						userSignal.dispatch(user);
						if (callback != null)
							callback(user);
						break;
					case "users": 
						var resultUsers:Vector.<UserVO> = new Vector.<UserVO>();
						var users:Array = message.split("&!");
						for each (var userS:String in users)
						{
							var userR:UserVO = new UserVO();
							userR.parse(userS);
							resultUsers.push(userR);
						}
						usersSignal.dispatch(resultUsers);
						if (callback != null)
							callback(resultUsers);
						break;
					case "usersCount": 
						usersCountSignal.dispatch(parseInt(message));
						if (callback != null)
							callback(parseInt(message));
						break;
					case "invoke": 
						reqStatus = message == "ok";
						invokeSignal.dispatch(reqStatus);
						if (callback != null)
							callback(reqStatus);
						break;
					case "invokeOnRoom": 
						invokeOnRoomSignal.dispatch(reqStatus);
						if (callback != null)
							callback(reqStatus);
						break;
					case "invokeOnAll": 
						invokeOnAllSignal.dispatch(reqStatus);
						if (callback != null)
							callback(reqStatus);
						break;
					case "doublelogin": 
						_connected = false;
						doubleLoginSignal.dispatch();
						loggedOutSignal.dispatch();
						break;
					default: 
						messageSignal.dispatch(message ? parse(message) : "", action, from);
				}
				
				delete _reqCallback[request];
			}
		}
		
		private function stringify(values:*):String {
			return JSON.stringify(values);
		}
		
		private function parse(values:String):Object {
			return JSON.parse(values);
		}
	}
}