package basicplayer {
	import flash.display.Sprite;
	import flash.events.*;
	import flash.media.SoundTransform;
	import flash.media.Video;
	import flash.net.NetConnection;
	import flash.net.NetStream;
	import flash.utils.Timer;

	import BasicPlayer;
	import basicplayer.Logger;
	import basicplayer.PlayerClass;

	public class PlayerVideo extends PlayerClass {
		private var _soundTransform:SoundTransform;
		private var _connection:NetConnection;
		private var _stream:NetStream;

		private var _timer:Timer;

		private var _isPaused:Boolean = true;
		private var _isEnded:Boolean = false;

		private var _seekPending:Number = -1;
		private var _bufferEmpty:Boolean = false;
		private var _seekOffset:Number = 0;

		private var _rtmpInfo:Object = null;
		private var _streamer:String = "";
		private var _pseudoStreamingEnabled:Boolean = false;
		private var _pseudoStreamingStartQueryParam:String = "start";

		private var _isConnected:Boolean = false;
		private var _isPreloading:Boolean = false;
		private var _isLoading:Boolean = false;
		private var _isResetting:Boolean = false;
		private var _playWhenConnected:Boolean = false;
		private var _hasStartedPlaying:Boolean = false;
		private var _encounteredError:Boolean = false;

		public function PlayerVideo(element:BasicPlayer, autoplay:Boolean, isLive:Boolean, preload:Boolean, volume:Number, muted:Boolean, timerRate:Number) {
			_element = element;
			_autoplay = autoplay;
			_isLive = isLive;
			_preload = preload;
			_volume = volume;
			_muted = muted;
			_timerRate = timerRate;

			_soundTransform = new SoundTransform(_muted ? 0 : _volume);

			_video = new Video();

			_connection = new NetConnection();
			_connection.client = { onBWDone: function():void {} };
			_connection.addEventListener(NetStatusEvent.NET_STATUS, netStatusHandler);
			_connection.addEventListener(SecurityErrorEvent.SECURITY_ERROR, securityErrorHandler);
			//_connection.connect(null);

			if (!_isLive) {
				_timer = new Timer(_timerRate);
				_timer.addEventListener("timer", timerHandler);
			}
		}

		public function setStreamer(streamer:String):void {
			_streamer = streamer;
		}

		public function setPseudoStreaming(enablePseudoStreaming:Boolean):void {
			_pseudoStreamingEnabled = enablePseudoStreaming;
		}

		public function setPseudoStreamingStartParam(pseudoStreamingStartQueryParam:String):void {
			_pseudoStreamingStartQueryParam = pseudoStreamingStartQueryParam;
		}

		private function getCurrentUrl(pos:Number):String {
			var url:String = _mediaUrl;
			if (_pseudoStreamingEnabled) {
				if (url.indexOf('?') > -1)
					url += '&' + _pseudoStreamingStartQueryParam + '=' + pos;
				else
					url += '?' + _pseudoStreamingStartQueryParam + '=' + pos;
			}
			return url;
		}

		private function timerHandler(e:TimerEvent):void {
			if (_stream == null)
				return;
			updateTime(getTime());
			// TODO: if _stream.bytesTotal is increasing, send something else as buffer percent
			if (_stream.bytesTotal > 0)
				updateBuffer(100 * _stream.bytesLoaded / _stream.bytesTotal, 0);
		}

		private function getTime():Number {
			var currentTime:Number = 0;
			if (_stream != null && !_isEnded) {
				currentTime = _stream.time;
				if (_pseudoStreamingEnabled)
					currentTime += _seekOffset;
			}
			return currentTime;
		}

		// internal events
		private function netStatusHandler(event:NetStatusEvent):void {
			Logger.debug("netStatus: "+event.info.code);

			switch (event.info.code) {

				case "NetConnection.Connect.Success":
					connectStream();
					break;

				case "NetStream.Buffer.Empty":
					_bufferEmpty = true;
					if (_isEnded) {
						_element.sendEvent("ended", null);
						updateTime(getTime());
					}
					break;

				case "NetStream.Buffer.Full":
					_bufferEmpty = false;
					if (_stream != null && _stream.bytesTotal > 0)
						updateBuffer(100 * _stream.bytesLoaded / _stream.bytesTotal, 0);
					if (_seekPending >= 0)
						seekMedia(_seekPending);
					break;

				case "NetStream.Play.Start":
					if (_isPreloading) {
						_isPreloading = false;
						_stream.pause();
						break;
					}
					_isResetting = false;
					_isPaused = false;
					if (_seekPending >= 0) {
						seekMedia(_seekPending);
						break;
					}
					_element.sendEvent("playing", null);
					if (_timer != null)
						_timer.start();
					break;

				case "NetStream.Seek.Notify":
					if (_isPaused)
						_element.sendEvent("paused", null);
					else
						_element.sendEvent("playing", null);
					break;

				case "NetStream.Pause.Notify":
					_isPaused = true;
					_element.sendEvent("paused", null);
					break;

				case "NetStream.Play.Stop":
					if (_isResetting)
						break;
					if (_timer != null)
						_timer.stop();
					_isPaused = true;
					_element.sendEvent("paused", null);
					if (!_isLive) {
						_isEnded = true;
						if (_bufferEmpty) {
							_element.sendEvent("ended", null);
							updateTime(getTime());
						}
					}
					break;

				case "NetStream.Failed":
					_element.sendEvent("error", {message: "Stream failure (NetStream.Failed)."});
					_encounteredError = true;
					break;

				case "NetStream.Play.FileStructureInvalid":
					_element.sendEvent("error", {message: "Invalid media file structure (NetStream.Play.FileStructureInvalid)."});
					_encounteredError = true;
					break;

				case "NetStream.Play.StreamNotFound":
					_element.sendEvent("error", {message: "Media not found."});
					_encounteredError = true;
					break;
			}
		}

		private function securityErrorHandler(event:SecurityErrorEvent):void {
			_element.sendEvent("error", {message: "securityErrorHandler: "+event+"."});
			_encounteredError = true;
		}

		private function asyncErrorHandler(event:AsyncErrorEvent):void {
			_element.sendEvent("error", {message: "asyncErrorHandler: "+event+"."});
			_encounteredError = true;
		}

		private function onMetaDataHandler(info:Object):void {
			// Only set the duration when we first load the video
			updateDuration(info.duration);
			//Logger.debug("Metadata:");
			//for (var id:String in info) { Logger.debug("    "+id+": "+info[id]); }

			// Set ratio
			if (!isNaN(info.width) && !isNaN(info.height) && info.width > 0 && info.height > 0)
				_element.setVideoRatio(info.width / info.height);
			else
				_element.setVideoRatio(0);
		}

		private function connectStream():void {
			_stream = new NetStream(_connection);

			// explicitly set the sound since it could have come before the connection was made
			_stream.soundTransform = _soundTransform;

			// set the buffer to ensure nice playback
			_stream.bufferTime = 1;
			_stream.bufferTimeMax = 3;

			_stream.addEventListener(NetStatusEvent.NET_STATUS, netStatusHandler); // same event as connection
			_stream.addEventListener(AsyncErrorEvent.ASYNC_ERROR, asyncErrorHandler);

			_stream.client = {onMetaData: onMetaDataHandler};

			_video.attachNetStream(_stream);

			// start downloading without playing (based on preload and play() hasn't been called)
			// I wish flash had a load() command to make this less akward
			if (_preload && !_playWhenConnected) {
				_isPaused = true;
				_isPreloading = true;
				//_stream.bufferTime = 20;
				if (_rtmpInfo != null)
					_stream.play(_rtmpInfo.stream);
				else
					_stream.play(getCurrentUrl(0));

				//_element.sendEvent("paused", null); // have to send this because the "playing" event gets sent via event handlers
			}

			_isConnected = true;

			if (_playWhenConnected && !_hasStartedPlaying) {
				playMedia();
				_playWhenConnected = false;
			}
			_isLoading = false;
		}

		// Overriden functions
		// -------------------------------------------------------------------
		public override function setSrc(url:String):void {
			if (_isConnected && _stream != null) {
				// stop and restart
				_stream.pause();
				_stream.close();
				_connection.close();
			}
			_isConnected = false;
			_isPreloading = false;
			_hasStartedPlaying = false;
			_isEnded = false;
			_bufferEmpty = false;
			_duration = 0;

			_mediaUrl = url;
			_rtmpInfo = null;
			if (_streamer != "") {
				_rtmpInfo = {
					server: _streamer,
					stream: _mediaUrl
				};
			} else if (_mediaUrl.match(/^rtmp(s|t|e|te)?\:\/\//)) {
				// Parse media url
				var match:Array = _mediaUrl.match(/(.*)\/((flv|mp4|mp3):.*)/);
				if (match) {
					_rtmpInfo = {
						server: match[1],
						stream: match[2]
					};
				}
				else {
					_rtmpInfo = {
						server: _mediaUrl.replace(/\/[^\/]+$/,"/"),
						stream: _mediaUrl.split("/").pop()
					};
				}
			}
			if (_rtmpInfo != null)
				Logger.debug("RTMP - server: " + _rtmpInfo.server + " stream: " + _rtmpInfo.stream);

			if (_preload)
				loadMedia();
		}

		public override function loadMedia():void {
			_isLoading = true;

			// start new connection
			if (_rtmpInfo != null)
				_connection.connect(_rtmpInfo.server);
			else
				_connection.connect(null);

			// in a few moments the "NetConnection.Connect.Success" event will fire
			// and call createConnection which finishes the "load" sequence
			_element.sendEvent("buffering", {playing: _playWhenConnected});
		}

		public override function playMedia():void {
			if (!_hasStartedPlaying && !_isConnected ) {
				_playWhenConnected = true;
				if (!_isLoading)
					loadMedia();
				return;
			}
			if (_hasStartedPlaying && !_isPaused)
				return;

			if (!_hasStartedPlaying || _isLive) {
				// resume is not working on live streams
				if (_hasStartedPlaying)
					_isResetting = true;
				if (_rtmpInfo != null)
					_stream.play(_rtmpInfo.stream);
				else
					_stream.play(getCurrentUrl(0));
			} else {
				if (_isEnded) {
					seekMedia(0);
					_isEnded = false;
				}
				_stream.resume();
			}

			if (_timer != null)
				_timer.start();
			_isPaused = false;
			_hasStartedPlaying = true;
			if (!_encounteredError)
				_element.sendEvent("buffering", {playing: true});
		}

		public override function pauseMedia():void {
			if (_stream == null)
				return;

			if (_timer != null && _stream.bytesLoaded == _stream.bytesTotal)
				_timer.stop();

			if (_isLive)
				_stream.close();
			else
				_stream.pause();
			_isPaused = true;
			if (!_encounteredError)
				_element.sendEvent("paused", null);
		}

		public override function stopMedia():void {
			if (_stream == null)
				return;
			_stream.seek(0);
			_stream.pause();
			if (!_encounteredError)
				_element.sendEvent("stopped", null);
		}

		public override function seekMedia(pos:Number):void {
			if (_stream == null || !_isConnected || !_hasStartedPlaying) {
				_seekPending = pos;
				return;
			}
			_seekPending = -1;
			if (!_encounteredError)
				_element.sendEvent("buffering", {playing: !_isPaused});

			// Calculate the position of the buffered video
			var bufferPosition:Number = _stream.bytesLoaded / _stream.bytesTotal * _duration;

			if (_pseudoStreamingEnabled) {
				// Normal seek if it is in buffer and this is the first seek
				if (pos < bufferPosition && _seekOffset == 0) {
					_stream.seek(pos);
				} else {
					// Uses server-side pseudo-streaming to seek
					_stream.play(getCurrentUrl(pos));
					_seekOffset = pos;
				}
			}
			else {
				_stream.seek(pos);
			}

			if (!_isEnded && _seekPending < 0)
				updateTime(getTime());
		}

		public override function setVolume(volume:Number):void {
			_volume = volume;
			_soundTransform.volume = _muted ? 0 : _volume;
			if (_stream != null)
				_stream.soundTransform = _soundTransform;
		}

		public override function setMuted(muted:Boolean):void {
			if (_muted == muted)
				return;
			_muted = muted;
			_soundTransform.volume = _muted ? 0 : _volume;
			if (_stream != null)
				_stream.soundTransform = _soundTransform;
		}
	}
}
