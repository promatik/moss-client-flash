package pt.promatik
{
	import pt.promatik.utils.StringUtils;
	import pt.promatik.vo.UserVO;
	
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.TimerEvent;
	import flash.net.Socket;
	import flash.system.Security;
	import flash.utils.Dictionary;
	import flash.utils.Timer;
	import idv.cjcat.signals.Signal;
	
	/**
	 * MOSS v1.1.2
	 * @author Toni Almeida
	 */
	public class MOSS
	{
		private var _request:uint = 1;
		private var _reqCallback:Dictionary = new Dictionary();
		
		private var _port:int;
		private var _host:String;
		private var _id:String = "";
		private var _room:String = "default";
		private var _status:String = "1";
		private var _availability:Boolean = true;
		
		private var _retryConnection:int;
		private var _retryDelay:uint;
		private var _attempts:int = 0;
		private var _socketConnected:Boolean = false;
		private var _connected:Boolean = false;
		private var _socket:Socket;
		private var _socketResponde:String = "";
		private var _cleanPattern:RegExp = /\|/g;
		private var _pingTimer:Timer;
		
		private var _connectSignal:Signal = new Signal();
		private var _loggedInSignal:Signal = new Signal();
		private var _loggedOutSignal:Signal = new Signal();
		private var _closeSignal:Signal = new Signal();
		private var _errorSignal:Signal = new Signal();
		private var _doubleLoginSignal:Signal = new Signal();
		private var _messageSignal:Signal = new Signal(Object, String, UserVO);
		
		private var _statusUpdatedSignal:Signal = new Signal(String);
		private var _availabilityUpdatedSignal:Signal = new Signal(String);
		private var _userSignal:Signal = new Signal(UserVO);
		private var _usersSignal:Signal = new Signal(Vector.<UserVO>);
		private var _usersCountSignal:Signal = new Signal(int);
		private var _invokeSignal:Signal = new Signal(Boolean);
		private var _invokeOnRoomSignal:Signal = new Signal(Boolean);
		private var _invokeOnAllSignal:Signal = new Signal(Boolean);
		
		public function get id():String { return _id; }
		public function get room():String { return _room; }
		public function get status():String { return _status; }
		public function get isConnected():Boolean { return _connected; }
		public function get hasServerConnection():Boolean { return _socketConnected; }
		public function get connectSignal():Signal { return _connectSignal; }
		public function get loggedInSignal():Signal { return _loggedInSignal; }
		public function get loggedOutSignal():Signal { return _loggedOutSignal; }
		public function get closeSignal():Signal { return _closeSignal; }
		public function get errorSignal():Signal { return _errorSignal; }
		public function get doubleLoginSignal():Signal { return _doubleLoginSignal; }
		public function get statusUpdatedSignal():Signal { return _statusUpdatedSignal; }
		public function get availabilityUpdatedSignal():Signal { return _availabilityUpdatedSignal; }
		public function get userSignal():Signal { return _userSignal; }
		public function get usersSignal():Signal { return _usersSignal; }
		public function get usersCountSignal():Signal { return _usersCountSignal; }
		public function get invokeSignal():Signal { return _invokeSignal; }
		public function get invokeOnRoomSignal():Signal { return _invokeOnRoomSignal; }
		public function get invokeOnAllSignal():Signal { return _invokeOnAllSignal; }
		public function get messageSignal():Signal { return _messageSignal; }
		
		public static const MESSAGE_DELIMITER:String = "&!";
		public static const SOCKET_TIMEOUT_DISABLED:int = 0;
		public static const SOCKET_TIMEOUT_DEFAULT:int = 12200;
		
		public static const GET_USERS_ALL:int = 0;
		public static const GET_USERS_AVAILABLE:int = 1;
		public static const GET_USERS_BUSY:int = 2;
		
		// --------------------
		// Constructor
		// --------------------
		
		public function MOSS(host:String = "localhost", port:int = 30480, retryConnection:uint = 0, retryDelay:uint = 1500)
		{
			_port = port;
			_host = host;
			_retryConnection = retryConnection;
			_retryDelay = retryDelay;
			
			initSocket();
			init();
		}
		
		public function resetHost(host:String = null, port:int = 0):void 
		{
			destroySocket();
			
			if(port > 0) _port = port;
			if(host) _host = host;
			
			initSocket();
			init();
		}
		
		public function set socketTimeOutTimer(pingDelay:uint):void
		{
			if (!_pingTimer)
			{
				_pingTimer = new Timer(pingDelay, 0);
				_pingTimer.addEventListener(TimerEvent.TIMER, ping_timer);
				_pingTimer.start();
			}
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
		
		private function initSocket():void
		{
			_socket = new Socket();
			_socket.addEventListener(Event.CONNECT, onConnect);
			_socket.addEventListener(Event.CLOSE, onClose);
			_socket.addEventListener(IOErrorEvent.IO_ERROR, onError);
			_socket.addEventListener(ProgressEvent.SOCKET_DATA, onResponse);
			_socket.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecError);
			_socket.timeout = _retryDelay;
		}
		
		private function destroySocket():void
		{
			_socketConnected = _connected = false;
			if(_socket) {
				if (_socket.connected) _socket.close();
				_socket.removeEventListener(Event.CONNECT, onConnect);
				_socket.removeEventListener(Event.CLOSE, onClose);
				_socket.removeEventListener(IOErrorEvent.IO_ERROR, onError);
				_socket.removeEventListener(ProgressEvent.SOCKET_DATA, onResponse);
				_socket.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecError);
				_socket = null;
			}
		}
		
		private function ping_timer(e:TimerEvent):void
		{
			if (_socketConnected)
			{
				ping();
			}
		}
		
		private function sendMessage(command:String = "", callback:Function = null, ... args):void
		{
			if (!_socketConnected)
			{
				errorSignal.dispatch();
				closeSignal.dispatch();
				return;
			}
			
			_request++;
			if (callback != null)
				_reqCallback[_request] = callback;
			
			var message:String = "|#MOSS#<!" + command + "!>#<!" + args.join(MESSAGE_DELIMITER) + "!>#<!" + _request.toString() + "!>#|";
			_socket.writeUTFBytes(message);
			_socket.flush();
		}
		
		private function ping():void
		{
			sendMessage();
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
		
		public function updateAvailability(status:Boolean, callback:Function = null):void
		{
			sendMessage("updateAvailability", callback, status ? "1" : "0");
		}
		
		public function getUser(id:String, room:String = null, callback:Function = null):void
		{
			if (!room)
				room = _room;
			sendMessage("getUser", callback, id, room);
		}
		
		public function getUsers(room:String, limit:int, page:int, available:int, search:Object, callback:Function = null):void
		{
			if (!room)
				room = _room;
			
			var searchTerms:String = "";
			for (var key:String in search) {
				searchTerms += key + "," + StringUtils.b8encode(search[key]);
			}
			
			sendMessage("getUsers", callback, room, limit, page, available, searchTerms);
		}
		
		public function setData(key:String, value:String, callback:Function = null):void
		{
			sendMessage("setData", callback, key, StringUtils.b8encode(value));
		}
		
		public function setDataMulti(args:Object):void
		{
			for(var i:String in args)
			{
				setData(i, args[i]);
			}
		}
		
		public function removeData(key:String, callback:Function = null):void
		{
			sendMessage("setData", callback, key, "");
		}
		
		public function getUsersCount(room:String = null, callback:Function = null):void
		{
			if (!room)
				room = _room;
			sendMessage("getUsersCount", callback, room);
		}
		
		public function randomPlayer(room:String = null, callback:Function = null):void
		{
			if (!room)
				room = _room;
			sendMessage("randomPlayer", callback, room);
		}
		
		public function pingUser(id:String, room:String = null, callback:Function = null):void
		{
			if (!room)
				room = _room;
			sendMessage("invoke", callback, id, room, "ping");
		}
		
		public function invoke(id:String, command:String, values:* = null, room:String = null, callback:Function = null):void
		{
			if (!room)
				room = _room;
			sendMessage("invoke", callback, id, room, command, values ? StringUtils.stringify(values) : "");
		}
		
		public function invokeOnRoom(command:String, values:* = null, room:String = null, callback:Function = null):void
		{
			if (!room)
				room = _room;
			sendMessage("invokeOnRoom", callback, room, command, values ? StringUtils.stringify(values) : "");
		}
		
		public function invokeOnAll(command:String, values:* = null, callback:Function = null):void
		{
			sendMessage("invokeOnAll", callback, command, values ? StringUtils.stringify(values) : "");
		}
		
		public function setSocketTimeOut(milliseconds:int, callback:Function = null):void
		{
			sendMessage("setTimeOut", callback, milliseconds);
		}
		
		public function log(values:*):void
		{
			sendMessage("log", null, (typeof(values) == "string" ? values : StringUtils.stringify(values)));
		}
		
		public function call(command:String, values:* = null, callback:Function = null):void
		{
			if (command.match("connect|disconnect|updateStatus|getUser|getUsers|getUsersCount|invoke|invokeOnRoom|invokeOnAll|setTimeOut|ping|pong|randomPlayer|setData|log"))
				throw new Error("The command '" + command + "' is reserved.");
			
			sendMessage(command, callback, StringUtils.stringify(values));
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
			
			if (_attempts == _retryConnection)
				closeSignal.dispatch();
			
			_attempts++;
		}
		
		private function onError(e:IOErrorEvent):void
		{
			destroySocket();
			initSocket();
			
			errorSignal.dispatch();
			onClose(e);
		}
		
		private function onSecError(e:SecurityErrorEvent):void
		{
			destroySocket();
			initSocket();
			
			errorSignal.dispatch();
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
				var user:UserVO = new UserVO();
				switch (action)
				{
					case "connected": 
						_connected = true;
						loggedInSignal.dispatch();
						if (callback != null)
							callback();
						break;
					case "disconnected": 
						_connected = _socketConnected = false;
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
					case "availabilityUpdated": 
						_availability = message == "1";
						availabilityUpdatedSignal.dispatch(message);
						if (callback != null)
							callback(_availability);
						break;
					case "user": 
						user.parse(message);
						userSignal.dispatch(user);
						if (callback != null)
							callback(user);
						break;
					case "users": 
						var resultUsers:Vector.<UserVO> = new Vector.<UserVO>();
						var users:Array = message.split(MESSAGE_DELIMITER);
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
						reqStatus = message == "ok";
						invokeOnRoomSignal.dispatch(reqStatus);
						if (callback != null)
							callback(reqStatus);
						break;
					case "invokeOnAll": 
						reqStatus = message == "ok";
						invokeOnAllSignal.dispatch(reqStatus);
						if (callback != null)
							callback(reqStatus);
						break;
					case "setTimeOut": 
						if (callback != null)
							callback();
						break;
					case "randomPlayer": 
						user = null;
						if(message != "null") {
							user = new UserVO();
							user.parse(message);
						}
						
						if (callback != null)
							callback(user);
						break;
					case "setData": 
						if (callback != null)
							callback();
						break;
					case "doublelogin": 
						_connected = false;
						_socketConnected = false;
						doubleLoginSignal.dispatch();
						loggedOutSignal.dispatch();
						break;
					case "log": 
						reqStatus = message == "ok";
						if (callback != null)
							callback(reqStatus);
						break;
					case "ping": 
						sendMessage("pong", null);
						break;
					case "pong": 
						break;
					default: 
						messageSignal.dispatch(message && message != "null" ? StringUtils.parse(message) : {}, action, from);
				}
				
				delete _reqCallback[request];
			}
		}
	}
}