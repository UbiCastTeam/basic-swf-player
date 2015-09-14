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

	//[SWF(backgroundColor="0x000000")] // Set SWF background color


	public class BasicPlayer extends MovieClip {
		private var _mediaUrl:String;
		private var _jsCallbackFunction:String;
		private var _autoplay:Boolean;
		private var _preload:Boolean;
		private var _video:DisplayObject;
		private var _timerRate:Number;
		private var _enableSmoothing:Boolean;
		private var _allowedPluginDomain:String;
		private var _isFullScreen:Boolean = false;
		private var _startVolume:Number;
		private var _startMuted:Boolean;
		private var _streamer:String = "";
		private var _enablePseudoStreaming:Boolean;
		private var _pseudoStreamingStartQueryParam:String;
		private var _defaultVideoRatio:Number = 0;
		private var _videoRatio:Number = 0;

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
			_jsCallbackFunction = (params["jscallbackfunction"] != undefined) ? String(params["jscallbackfunction"]) : "";
			_mediaUrl = (params["file"] != undefined) ? String(params["file"]) : "";
			_preload = (params["preload"] != undefined) ? (String(params["preload"]) == "true") : false;
			_autoplay = (params["autoplay"] != undefined) ? (String(params["autoplay"]) == "true") : false;
			_timerRate = (params["timerrate"] != undefined) ? (parseInt(params["timerrate"], 10)) : 250;
			_enableSmoothing = (params["smoothing"] != undefined) ? (String(params["smoothing"]) == "true") : false;
			_startVolume = (params["volume"] != undefined) ? (parseFloat(params["volume"])) : 0.8;
			_startMuted = (params["muted"] != undefined) ?  (String(params["muted"]) == "true") : false;
			_enablePseudoStreaming = (params["pseudostreaming"] != undefined) ? (String(params["pseudostreaming"]) == "true") : false;
			_pseudoStreamingStartQueryParam = (params["pseudostreamstart"] != undefined) ? (String(params["pseudostreamstart"])) : "start";
			_streamer = (params["flashstreamer"] != undefined) ? (String(params["flashstreamer"])) : "";
			_defaultVideoRatio = (params["ratio"] != undefined) ? (parseFloat(params["ratio"])) : 0;

			if (isNaN(_timerRate))
				_timerRate = 250;
			if (_startVolume > 1)
				_startVolume = 1;

			//_autoplay = true;
			//_mediaUrl  = "http://mediafiles.dts.edu/chapel/mp4/20100609.mp4";
			//_mediaUrl  = "../media/Parades-PastLives.mp3";
			//_mediaUrl  = "../media/echo-hereweare.mp4";

			//_mediaUrl = "http://video.ted.com/talks/podcast/AlGore_2006_480.mp4";
			//_mediaUrl = "rtmp://stream2.france24.yacast.net/france24_live/en/f24_liveen";

			Logger.debug("stage: " + stage.stageWidth + "x" + stage.stageHeight);
			Logger.debug("file: " + _mediaUrl);
			Logger.debug("autoplay: " + _autoplay.toString());
			Logger.debug("preload: " + _preload.toString());
			Logger.debug("smoothing: " + _enableSmoothing.toString());
			Logger.debug("timerrate: " + _timerRate.toString());
			Logger.debug("displayState: " +(stage.hasOwnProperty("displayState")).toString());

			// Attach javascript
			Logger.debug("ExternalInterface.available: " + ExternalInterface.available.toString());
			Logger.debug("ExternalInterface.objectID: " + (ExternalInterface.objectID != null ? ExternalInterface.objectID : "no_object_id"));

			var jsInitFct:String = (params["jsinitfunction"] != undefined) ? String(params["jsinitfunction"]) : null;
			if (ExternalInterface.available) {
				try {
					// Add JavaScript methods on object
					ExternalInterface.addCallback("playMedia", playMedia);
					ExternalInterface.addCallback("pauseMedia", pauseMedia);
					ExternalInterface.addCallback("stopMedia", stopMedia);
					ExternalInterface.addCallback("seekMedia", seek);
					ExternalInterface.addCallback("setVolume", setVolume);
					ExternalInterface.addCallback("getVolume", getVolume);
					ExternalInterface.addCallback("setMuted", setMuted);
					ExternalInterface.addCallback("getMuted", getMuted);
					ExternalInterface.addCallback("enableLog", enableLog);
					ExternalInterface.addCallback("disableLog", disableLog);
					ExternalInterface.addCallback("setVideoRatio", setVideoRatio);
					Logger.debug("JavaScript methods added.");
					// Fire init method
					if (jsInitFct) {
						ExternalInterface.call(jsInitFct, (ExternalInterface.objectID != null ? ExternalInterface.objectID : "no_object_id"));
						Logger.debug("Init js function \"" + jsInitFct + "\" successfully called.");
					}
				} catch (error:SecurityError) {
					Logger.debug("A SecurityError occurred: " + error.message);
				} catch (error:Error) {
					Logger.debug("An Error occurred: " + error.message);
				}
			}
			else {
				Logger.debug(
					"No ExternalInterface available:\n"
					+ "    - Init function \"" + jsInitFct + "\" will not be called.\n"
					+ "    - Callback function \"" + _jsCallbackFunction + "\" will not be called."
				);
			}

			// Create media player
			if (_mediaUrl.search(/(https?|file)\:\/\/.*?\.m3u8(\?.*)?/i) !== -1) {
				_playerElement = new PlayerHLS(this, _autoplay, _preload, _startVolume, _startMuted, _timerRate);

			} else if (_mediaUrl.search(/(https?|file)\:\/\/.*?\.(mp3|oga|wav)(\?.*)?/i) !== -1) {
				//var player2:AudioDecoder = new com.automatastudios.audio.audiodecoder.AudioDecoder();
				_playerElement = new PlayerAudio(this, _autoplay, _preload, _startVolume, _startMuted, _timerRate);

			} else {
				_playerElement = new PlayerVideo(this, _autoplay, _preload, _startVolume, _startMuted, _timerRate);
				(_playerElement as PlayerVideo).setStreamer(_streamer);
				(_playerElement as PlayerVideo).setPseudoStreaming(_enablePseudoStreaming);
				(_playerElement as PlayerVideo).setPseudoStreamingStartParam(_pseudoStreamingStartQueryParam);
			}
			// Display media texture
			_video = (_playerElement as PlayerClass).getElement();
			if (_video != null) {
				(_video as Video).smoothing = _enableSmoothing;
				addChild(_video);
			}
			repositionVideo();
			// Load media
			if (_mediaUrl != "")
				_playerElement.setSrc(_mediaUrl);
			if (_autoplay)
				_playerElement.playMedia();

			// Bind events
			stage.addEventListener(Event.RESIZE, resizeHandler);
			stage.addEventListener(FullScreenEvent.FULL_SCREEN, stageFullScreenChanged);
			stage.addEventListener(MouseEvent.CLICK, stageClicked);
		}

		private function repositionVideo():void {
			var contWidth:Number;
			var contHeight:Number;
			if (_isFullScreen) {
				contWidth = stage.fullScreenWidth;
				contHeight = stage.fullScreenHeight;
			} else {
				contWidth = stage.stageWidth;
				contHeight = stage.stageHeight;
			}

			Logger.debug("Positioning video ("+stage.displayState+"). Container size: "+contWidth+"x"+contHeight+".");
			Logger.setSize(contWidth, contHeight);

			if (_playerElement is PlayerVideo || _playerElement is PlayerHLS) {
				var fill:Boolean = false;
				if (_defaultVideoRatio <= 0 && _videoRatio <= 0) {
					Logger.debug("Positionning: video's ratio is unknown, using full stage size.");
					fill = true;
				}
				// calculate ratios
				_video.x = 0;
				_video.y = 0;
				if (fill || stageRatio == videoRatio) {
					_playerElement.setSize(contWidth, contHeight);
				} else {
					var stageRatio:Number = contWidth / contHeight;
					var videoRatio:Number = (_videoRatio > 0 ? _videoRatio : _defaultVideoRatio);
					// adjust size and position
					if (videoRatio > stageRatio) {
						_playerElement.setSize(contWidth, Math.ceil(contWidth / videoRatio));
						_video.y = Math.round(contHeight / 2 - _video.height / 2);
						Logger.debug("Positionning: video's size: "+contWidth+" x "+Math.ceil(contWidth / videoRatio)+" (x: "+_video.x+", y: "+_video.y+").");
					} else {
						_playerElement.setSize(Math.ceil(contHeight * videoRatio), contHeight);
						_video.x = Math.round(contWidth / 2 - _video.width / 2);
						Logger.debug("Positionning: video's size: "+Math.ceil(contHeight * videoRatio)+" x "+contHeight+" (x: "+_video.x+", y: "+_video.y+").");
					}
				}
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
			repositionVideo();
		}

		public function goToGitHub(event:ContextMenuEvent):void {
			navigateToURL(new URLRequest("https://github.com/UbiCastTeam/basicswfplayer"), "_blank");
		}

		public function stageFullScreenChanged(event:FullScreenEvent):void {
			Logger.debug("Fullscreen event: " + event.fullScreen.toString());
			_isFullScreen = event.fullScreen;
			repositionVideo();
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
		public function seek(time:Number):void {
			Logger.debug("seek: " + time);
			_playerElement.seek(time);
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
			repositionVideo();
		}
		// END: external interface
	}
}
