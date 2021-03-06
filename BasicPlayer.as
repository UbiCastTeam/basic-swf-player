package {
	import flash.display.*;
	import flash.events.*;
	import flash.media.*;
	import flash.net.*;
	import flash.system.*;
	import flash.text.*;
	import flash.ui.ContextMenu;
	import flash.ui.ContextMenuItem;

	import flash.media.Video;
	import flash.net.NetConnection;
	import flash.net.NetStream;
	import flash.net.navigateToURL;
	import flash.net.URLRequest;

	import flash.utils.Timer;
	import flash.external.ExternalInterface;

	import basicplayer.Utils;
	import basicplayer.Logger;
	import basicplayer.PlayerClass;
	import basicplayer.PlayerVideo;
	import basicplayer.PlayerAudio;
	import basicplayer.PlayerHLS;

	[SWF(backgroundColor="0x000000")] // Set SWF background color


	public class BasicPlayer extends MovieClip {
		private var _jsInitFct:String;
		private var _jsCallbackFunction:String;
		private var _thumb:Bitmap;
		private var _video:DisplayObject;
		private var _isFullScreen:Boolean = false;
		private var _defaultVideoRatio:Number = 0;
		private var _videoRatio:Number = 0;
		private var _thumbRatio:Number = 0;

		// player
		private var _playerElement:PlayerClass;

		// connection to fullscreen
		private var _connection:LocalConnection;
		private var _connectionName:String;

		// security checkes
		private var securityIssue:Boolean = false; // When SWF parameters contain illegal characters
		private var directAccess:Boolean = false; // When SWF visited directly with no parameters (or when security issue detected)


		public function BasicPlayer() {
			// check for security issues (borrowed from jPLayer)
			checkFlashVars(loaderInfo.parameters);

			// allows this player to be called from a different domain than the HTML page hosting the player
			CONFIG::allowCrossOrigin {
				Security.allowDomain("*");
				Security.allowInsecureDomain("*");
			}

			if (securityIssue)
				return;

			// setup stage and player sizes/scales
			stage.align = StageAlign.TOP_LEFT;
			stage.scaleMode = StageScaleMode.NO_SCALE;
			stage.addChild(this);

			// get parameters
			// Use only FlashVars, ignore QueryString
			var params:Object, pos:int, query:Object;

			params = LoaderInfo(this.root.loaderInfo).parameters;
			pos = root.loaderInfo.url.indexOf("?");
			if (pos !== -1) {
				query = Utils.parseStr(root.loaderInfo.url.substr(pos + 1));
				for (var key:String in params) {
					if (query.hasOwnProperty(Utils.trim(key)))
						delete params[key];
				}
			}

			// Setup logger
			var logger:Logger = Logger.get();
			if (params["jslogfunction"] != undefined)
				logger.jsFunction = String(params["jslogfunction"]);
			var debug:Boolean = (params["debug"] != undefined) ? (String(params["debug"]) == "true") : false;
			if (debug)
				enableLog();
			loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, errorHandler);

			// Add item to context menu
			var ctxtMenu:ContextMenu = new ContextMenu();
			//ctxtMenu.hideBuiltInItems();
			var bpItem:ContextMenuItem = new ContextMenuItem("Basic Player");
			ctxtMenu.customItems.push(bpItem);
			bpItem.addEventListener(ContextMenuEvent.MENU_ITEM_SELECT, goToGitHub);
			this.contextMenu = ctxtMenu;

			// Get settings
			_jsInitFct = (params["jsinitfunction"] != undefined) ? String(params["jsinitfunction"]) : null;
			_jsCallbackFunction = (params["jscallbackfunction"] != undefined) ? String(params["jscallbackfunction"]) : "";
			_defaultVideoRatio = (params["ratio"] != undefined) ? (parseFloat(params["ratio"])) : 0;
			var mediaUrl:String = (params["file"] != undefined) ? String(params["file"]) : "";
			var thumbUrl:String = (params["thumb"] != undefined) ? String(params["thumb"]) : "";
			var preload:Boolean = (params["preload"] != undefined) ? (String(params["preload"]) == "true") : false;
			var autoplay:Boolean = (params["autoplay"] != undefined) ? (String(params["autoplay"]) == "true") : false;
			var timerRate:Number = (params["timerrate"] != undefined) ? (parseInt(params["timerrate"], 10)) : 250;
			var enableSmoothing:Boolean = (params["smoothing"] != undefined) ? (String(params["smoothing"]) == "true") : true;
			var startVolume:Number = (params["volume"] != undefined) ? (parseFloat(params["volume"])) : 0.8;
			var startMuted:Boolean = (params["muted"] != undefined) ?  (String(params["muted"]) == "true") : false;
			var enablePseudoStreaming:Boolean = (params["pseudostreaming"] != undefined) ? (String(params["pseudostreaming"]) == "true") : false;
			var pseudoStreamingStart:String = (params["pseudostreamstart"] != undefined) ? (String(params["pseudostreamstart"])) : "start";
			var HLSMaxBufferLength:Number = (params["hlsmaxbuffer"] != undefined) ? (parseInt(params["hlsmaxbuffer"], 10)) : 30;
			var isLive:Boolean = (params["live"] != undefined) ?  (String(params["live"]) == "true") : false;
			var streamer:String = (params["flashstreamer"] != undefined) ? (String(params["flashstreamer"])) : "";

			if (isNaN(timerRate))
				timerRate = 250;
			if (startVolume > 1)
				startVolume = 1;

			if (debug && params["displayinfo"] != undefined && String(params["displayinfo"]) == "true") {
				Logger.debug("stage: " + stage.stageWidth + "x" + stage.stageHeight);
				Logger.debug("file: " + mediaUrl);
				Logger.debug("autoplay: " + autoplay.toString());
				Logger.debug("preload: " + preload.toString());
				Logger.debug("smoothing: " + enableSmoothing.toString());
				Logger.debug("timerrate: " + timerRate.toString());
				Logger.debug("displayState: " +(stage.hasOwnProperty("displayState")).toString());
			}

			// Attach javascript
			Logger.debug("ExternalInterface.available: " + ExternalInterface.available.toString());
			Logger.debug("ExternalInterface.objectID: " + (ExternalInterface.objectID != null ? ExternalInterface.objectID : "no_object_id"));

			// Create media player
			if (mediaUrl.search(/(https?|file)\:\/\/.*?\.m3u8(\?.*)?/i) !== -1) {
				_playerElement = new PlayerHLS(this, autoplay, isLive, preload, startVolume, startMuted, timerRate);
				if (isNaN(HLSMaxBufferLength))
					HLSMaxBufferLength = 30;
				(_playerElement as PlayerHLS).setMaxBufferLength(HLSMaxBufferLength);

			}
			else if (mediaUrl.search(/(https?|file)\:\/\/.*?\.(mp3|oga|wav)(\?.*)?/i) !== -1) {
				//var player2:AudioDecoder = new com.automatastudios.audio.audiodecoder.AudioDecoder();
				_playerElement = new PlayerAudio(this, autoplay, isLive, preload, startVolume, startMuted, timerRate);

			}
			else {
				_playerElement = new PlayerVideo(this, autoplay, isLive, preload, startVolume, startMuted, timerRate);
				(_playerElement as PlayerVideo).setStreamer(streamer);
				(_playerElement as PlayerVideo).setPseudoStreaming(enablePseudoStreaming);
				(_playerElement as PlayerVideo).setPseudoStreamingStartParam(pseudoStreamingStart);
			}
			// Display media texture
			_video = (_playerElement as PlayerClass).getElement();
			if (_video != null) {
				(_video as Video).smoothing = enableSmoothing;
				addChild(_video);
			}
			onSizeChange();
			// Load media
			if (mediaUrl != "")
				_playerElement.setSrc(mediaUrl);
			if (autoplay)
				_playerElement.playMedia();

			// Bind events
			stage.addEventListener(Event.RESIZE, resizeHandler);
			stage.addEventListener(FullScreenEvent.FULL_SCREEN, stageFullScreenChanged);
			stage.addEventListener(MouseEvent.CLICK, stageClicked);

			// Add JavaScript methods on object
			if (ExternalInterface.available) {
				try {
					ExternalInterface.addCallback("playMedia", playMedia);
					ExternalInterface.addCallback("pauseMedia", pauseMedia);
					ExternalInterface.addCallback("stopMedia", stopMedia);
					ExternalInterface.addCallback("seekMedia", seekMedia);
					ExternalInterface.addCallback("setVolume", setVolume);
					ExternalInterface.addCallback("getVolume", getVolume);
					ExternalInterface.addCallback("setMuted", setMuted);
					ExternalInterface.addCallback("getMuted", getMuted);
					ExternalInterface.addCallback("enableLog", enableLog);
					ExternalInterface.addCallback("disableLog", disableLog);
					ExternalInterface.addCallback("setVideoRatio", setVideoRatio);
					Logger.debug("JavaScript methods added.");
				} catch (error:SecurityError) {
					Logger.debug("A SecurityError occurred: " + error.message);
				} catch (error:Error) {
					Logger.debug("An Error occurred: " + error.message);
				}
			}
			else {
				Logger.debug(
					"No ExternalInterface available:\n"
					+ "    - Init function \"" + _jsInitFct + "\" will not be called.\n"
					+ "    - Callback function \"" + _jsCallbackFunction + "\" will not be called."
				);
			}

			// Display thumbnail
			if (thumbUrl != "") {
				var loader:Loader = new Loader();
				loader.contentLoaderInfo.addEventListener(Event.COMPLETE, onThumbLoad);
				loader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, onThumbError);
				loader.load(new URLRequest(thumbUrl));
			}
			else {
				onReady();
			}
		}

		private function onThumbLoad(event:Event):void {
			_thumb = Bitmap(LoaderInfo(event.target).content);
			_thumb.smoothing = true;
			if (LoaderInfo(event.target).width > 0 && LoaderInfo(event.target).height > 0)
				_thumbRatio = LoaderInfo(event.target).width / LoaderInfo(event.target).height;
			else
				_thumbRatio = 0;
			addChildAt(_thumb, 0);
			Logger.debug("Thumbnail loaded ("+LoaderInfo(event.target).width+"x"+LoaderInfo(event.target).height+").");
			onSizeChange();
			onReady();
		}

		private function onThumbError(event:IOErrorEvent):void {
			Logger.debug("Failed to load thumbnail: " + event);
			onReady();
		}

		private function onReady():void {
			if (!ExternalInterface.available)
				return;
			// Fire init method
			try {
				if (_jsInitFct) {
					ExternalInterface.call(_jsInitFct, (ExternalInterface.objectID != null ? ExternalInterface.objectID : "no_object_id"));
					Logger.debug("Init js function \"" + _jsInitFct + "\" successfully called.");
				}
			} catch (error:SecurityError) {
				Logger.debug("A SecurityError occurred: " + error.message);
			} catch (error:Error) {
				Logger.debug("An Error occurred: " + error.message);
			}
		}

		private function onSizeChange():void {
			var contWidth:Number;
			var contHeight:Number;
			if (_isFullScreen) {
				contWidth = stage.fullScreenWidth;
				contHeight = stage.fullScreenHeight;
			}
			else {
				contWidth = stage.stageWidth;
				contHeight = stage.stageHeight;
			}
			var stageRatio:Number = contWidth / contHeight;

			Logger.debug("Positioning elements ("+stage.displayState+"). Container size: "+contWidth+"x"+contHeight+".");
			Logger.setSize(contWidth, contHeight);

			if (_thumb) {
				_thumb.x = 0;
				_thumb.y = 0;
				if (_thumbRatio <= 0 || _thumbRatio == stageRatio) {
					_thumb.width = contWidth;
					_thumb.height = contHeight;
				}
				else if (_thumbRatio > stageRatio) {
					_thumb.width = contWidth;
					_thumb.height = Math.ceil(contWidth / _thumbRatio);
					_thumb.y = Math.round(contHeight / 2 - _thumb.height / 2);
				}
				else {
					_thumb.width = Math.ceil(contHeight * _thumbRatio);
					_thumb.height = contHeight;
					_thumb.x = Math.round(contWidth / 2 - _thumb.width / 2);
				}
				Logger.debug("Thumb position: "+_thumb.width+" x "+_thumb.height+" (x: "+_thumb.x+", y: "+_thumb.y+").");
			}

			if (_video && (_playerElement is PlayerVideo || _playerElement is PlayerHLS)) {
				var fill:Boolean = false;
				if (_defaultVideoRatio <= 0 && _videoRatio <= 0) {
					Logger.debug("Video position: video's ratio is unknown, using full stage size.");
					fill = true;
				}
				// adjust size and position
				var videoRatio:Number = (_videoRatio > 0 ? _videoRatio : _defaultVideoRatio);
				_video.x = 0;
				_video.y = 0;
				if (fill || videoRatio == stageRatio) {
					_playerElement.setSize(contWidth, contHeight);
				}
				else if (videoRatio > stageRatio) {
					_playerElement.setSize(contWidth, Math.ceil(contWidth / videoRatio));
					_video.y = Math.round(contHeight / 2 - _video.height / 2);
				}
				else {
					_playerElement.setSize(Math.ceil(contHeight * videoRatio), contHeight);
					_video.x = Math.round(contWidth / 2 - _video.width / 2);
				}
				Logger.debug("Video position: "+_video.width+" x "+_video.height+" (x: "+_video.x+", y: "+_video.y+").");
			}
		}

		// borrowed from jPLayer
		// https://github.com/happyworm/jPlayer/blob/e8ca190f7f972a6a421cb95f09e138720e40ed6d/actionscript/Jplayer.as#L228
		private function checkFlashVars(p:Object):void {
			var i:Number = 0;
			for (var s:String in p) {
				if (Utils.hasIllegalChar(p[s], s === "file")) {
					securityIssue = true; // Illegal char found
				}
				i++;
			}
			if (i === 0 || securityIssue) {
				directAccess = true;
			}
		}

		public function stageClicked(event:MouseEvent):void {
			//Logger.debug("click: " + event.stageX.toString() +","+event.stageY.toString() + "\n");
			if (event.target == stage)
				sendEvent("click", null);
		}

		public function resizeHandler(event:Event):void {
			onSizeChange();
		}

		public function goToGitHub(event:ContextMenuEvent):void {
			navigateToURL(new URLRequest("https://github.com/UbiCastTeam/basicswfplayer"), "_blank");
		}

		public function stageFullScreenChanged(event:FullScreenEvent):void {
			Logger.debug("Fullscreen event: " + event.fullScreen.toString());
			_isFullScreen = event.fullScreen;
			onSizeChange();
		}

		public function errorHandler(event:UncaughtErrorEvent):void {
			if (event.error is Error || event.error is ErrorEvent)
				sendEvent("error", {message: "Unhandled error: "+event.error+"."});
			// suppress error dialog
			event.preventDefault();
		}

		// SEND events to JavaScript
		public function sendEvent(eventName:String, eventData:Object):void {
			if (eventName == "error")
				Logger.error(eventData.message);
			if (!ExternalInterface.available)
				return;
			var jsfct:String = _jsCallbackFunction+"('"+(ExternalInterface.objectID != null ? ExternalInterface.objectID : "no_object_id")+"','"+eventName+"'";
			if (eventData != null)
				jsfct += ","+Utils.toJSON(eventData);
			jsfct += ")";
			// use set timeout for performance reasons
			ExternalInterface.call("setTimeout", jsfct, 0);
		}

		// START: external interface
		public function enableLog():void {
			var logger:Logger = Logger.get();
			logger.enabled = true;
			logger.outputToStage(stage);
		}
		public function disableLog():void {
			var logger:Logger = Logger.get();
			logger.enabled = false;
			logger.removeOutput();
		}
		public function loadMedia():void {
			Logger.debug("load");
			_playerElement.loadMedia();
		}
		public function playMedia():void {
			Logger.debug("play");
			_playerElement.playMedia();
		}
		public function pauseMedia():void {
			Logger.debug("pause");
			_playerElement.pauseMedia();
		}
		public function stopMedia():void {
			Logger.debug("stop");
			_playerElement.stopMedia();
		}
		public function seekMedia(time:Number):void {
			Logger.debug("seek: " + time);
			_playerElement.seekMedia(time);
		}
		public function setVolume(volume:Number):void {
			_playerElement.setVolume(volume);
		}
		public function getVolume():Number {
			return _playerElement.getVolume();
		}
		public function setMuted(muted:Boolean):void {
			_playerElement.setMuted(muted);
		}
		public function getMuted():Boolean {
			return _playerElement.getMuted();
		}
		public function setVideoRatio(ratio:Number):void {
			Logger.debug("setVideoRatio: " + ratio);
			if (isNaN(ratio) || ratio < 0 || ratio == _videoRatio)
				return;
			_videoRatio = ratio;
			onSizeChange();
			sendEvent("ratio", {ratio: ratio});
		}
		// END: external interface
	}
}
