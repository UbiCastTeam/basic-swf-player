package basicplayer {
	import flash.display.Sprite;
	import flash.media.SoundTransform;
	import flash.media.Video;

	import org.mangui.hls.HLS;
	import org.mangui.hls.HLSSettings;
	import org.mangui.hls.event.HLSEvent;
	import org.mangui.hls.constant.HLSSeekMode;
	import org.mangui.hls.constant.HLSPlayStates;
	import org.mangui.hls.utils.Log;

	import basicplayer.PlayerClass;

	public class PlayerHLS extends PlayerClass {
		private var _playqueued:Boolean = false;
		private var _hls:HLS;
		private var _hlsState:String = HLSPlayStates.IDLE;
		private var _soundTransform:SoundTransform;

		private var _isSeekingTo:Number = -1;
		private var _isManifestLoaded:Boolean = false;
		private var _isPaused:Boolean = true;
		private var _isEnded:Boolean = false;

		private var _encounteredError:Boolean = false;

		public function PlayerHLS(element:BasicPlayer, autoplay:Boolean, isLive:Boolean, preload:Boolean, volume:Number, muted:Boolean, timerRate:Number) {
			_element = element;
			_autoplay = autoplay;
			_isLive = isLive;
			_preload = preload;
			_volume = volume;
			_muted = muted;
			_timerRate = timerRate;

			_soundTransform = new SoundTransform(_muted ? 0 : _volume);

			//HLSSettings.logDebug = true;
			//HLSSettings.logDebug2 = true;
			HLSSettings.seekMode = HLSSeekMode.ACCURATE_SEEK;
			_hls = new HLS();
			_hls.addEventListener(HLSEvent.PLAYBACK_COMPLETE, _completeHandler);
			_hls.addEventListener(HLSEvent.ERROR, _errorHandler);
			_hls.addEventListener(HLSEvent.MANIFEST_LOADED, _manifestHandler);
			_hls.addEventListener(HLSEvent.MEDIA_TIME, _mediaTimeHandler);
			_hls.addEventListener(HLSEvent.PLAYBACK_STATE, _stateHandler);
			_hls.stream.soundTransform = _soundTransform;

			_video = new Video();
			_video.attachNetStream(_hls.stream);
		}

		private function _completeHandler(event:HLSEvent):void {
			_isEnded = true;
			_isPaused = true;
			_element.sendEvent("paused", null);
			_element.sendEvent("ended", null);
		}

		private function _errorHandler(event:HLSEvent):void {
			var msg:String = event.error.msg.toString();
			if (msg.indexOf("Cannot load M3U8") != -1)
				msg += "\nThe resource is unavailable or unreachable.";
			else
				msg = "Playback error: "+msg;
			_element.sendEvent("error", {message: msg});
			_encounteredError = true;
		}

		private function _manifestHandler(event:HLSEvent):void {
			var vWidth:Number = event.levels[0].width;
			var vHeight:Number = event.levels[0].height;
			_isManifestLoaded = true;
			_hls.stage = _video.stage;
			updateDuration(event.levels[0].duration);
			// Set ratio
			if (!isNaN(vWidth) && !isNaN(vHeight) && vWidth > 0 && vHeight > 0)
				_element.setVideoRatio(vWidth / vHeight);
			else
				_element.setVideoRatio(0);
			if (_autoplay || _playqueued) {
				_playqueued = false;
				_hls.stream.play();
			}
		}

		private function _mediaTimeHandler(event:HLSEvent):void {
			if (_isSeekingTo < 0 || event.mediatime.position > _isSeekingTo) {
				_isSeekingTo = -1;
				updateTime(event.mediatime.position);
			}
			if (!_isLive) {
				updateDuration(event.mediatime.duration);
				updateBuffer(0, event.mediatime.position + event.mediatime.buffer);
			}
		}

		private function _stateHandler(event:HLSEvent):void {
			_hlsState = event.state;
			//Log.txt("state:"+ _hlsState);
			switch (event.state) {
				case HLSPlayStates.IDLE:
					_isPaused = true;
					_element.sendEvent("paused", null);
					break;
				case HLSPlayStates.PAUSED_BUFFERING:
					_isPaused = true;
					_element.sendEvent("buffering", {playing: false});
					break;
				case HLSPlayStates.PLAYING_BUFFERING:
					_isPaused = false;
					_element.sendEvent("buffering", {playing: true});
					break;
				case HLSPlayStates.PLAYING:
					_isPaused = false;
					_isEnded = false;
					_video.visible = true;
					_element.sendEvent("playing", null);
					break;
				case HLSPlayStates.PAUSED:
					_isPaused = true;
					_isEnded = false;
					_element.sendEvent("paused", null);
					break;
			}
		}

		// Overriden functions
		// -------------------------------------------------------------------
		public override function setSrc(url:String):void{
			stopMedia();
			_mediaUrl = url;
			loadMedia();
		}

		public override function loadMedia():void{
			if (_mediaUrl == "")
				return;
			if (!_encounteredError)
				_element.sendEvent("buffering", {playing: !_isPaused});
			_hls.load(_mediaUrl);
		}

		public override function playMedia():void {
			if (!_isManifestLoaded) {
				_playqueued = true;
				if (!_encounteredError)
					_element.sendEvent("buffering", {playing: true});
				return;
			}
			if (_hlsState == HLSPlayStates.PAUSED || _hlsState == HLSPlayStates.PAUSED_BUFFERING)
				_hls.stream.resume();
			else
				_hls.stream.play();
		}

		public override function pauseMedia():void {
			if (!_isManifestLoaded)
				return;
			_hls.stream.pause();
		}

		public override function stopMedia():void{
			_isSeekingTo = -1;
			_hls.stream.seek(0);
			_hls.stream.pause();
			updateTime(0);
			_element.sendEvent("stopped", null);
		}

		public override function seekMedia(pos:Number):void{
			if (!_isManifestLoaded)
				return;
			if (_isLive && pos < 0) {
				// Reset buffer
				_isSeekingTo = -1;
				_hls.stream.close();
				_hls.load(_mediaUrl);
			}
			else {
				_isSeekingTo = pos;
				updateTime(pos);
				_hls.stream.seek(pos);
			}
		}

		public override function setVolume(volume:Number):void {
			_volume = volume;
			_soundTransform.volume = _muted ? 0 : _volume;
			if (_hls.stream != null)
				_hls.stream.soundTransform = _soundTransform;
		}

		public override function setMuted(muted:Boolean):void {
			if (_muted == muted)
				return;
			_muted = muted;
			_soundTransform.volume = _muted ? 0 : _volume;
			if (_hls.stream != null)
				_hls.stream.soundTransform = _soundTransform;
		}
	}
}
