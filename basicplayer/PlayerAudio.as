package basicplayer {
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.events.TimerEvent;
	import flash.media.ID3Info;
	import flash.media.Sound;
	import flash.media.SoundChannel;
	import flash.media.SoundLoaderContext;
	import flash.media.SoundTransform;
	import flash.net.URLRequest;
	import flash.utils.Timer;

	import basicplayer.PlayerClass;

	public class PlayerAudio extends PlayerClass {
		private var _soundTransform:SoundTransform;
		private var _sound:Sound;
		private var _soundChannel:SoundChannel;
		private var _soundLoaderContext:SoundLoaderContext;

		private var _timer:Timer;

		private var _isPaused:Boolean = true;
		private var _isEnded:Boolean = false;
		private var _isLoading:Boolean = false;
		private var _isLoaded:Boolean = false;

		private var _bytesLoaded:Number = 0;
		private var _bytesTotal:Number = 0;
		private var _bufferingChanged:Boolean = false;

		private var _playAfterLoading:Boolean = false;

		public function PlayerAudio(element:BasicPlayer, autoplay:Boolean, isLive:Boolean, preload:Boolean, volume:Number, muted:Boolean, timerRate:Number) {
			_element = element;
			_autoplay = autoplay;
			_isLive = isLive;
			_preload = preload;
			_volume = volume;
			_muted = muted;
			_timerRate = timerRate;

			_soundTransform = new SoundTransform(_muted ? 0 : _volume);
			_soundLoaderContext = new SoundLoaderContext();

			_timer = new Timer(_timerRate);
			_timer.addEventListener(TimerEvent.TIMER, timerEventHandler);
		}

		// events
		private function progressHandler(e:ProgressEvent):void {
			_bytesLoaded = e.bytesLoaded;
			_bytesTotal = e.bytesTotal;
			// this happens too much to send every time
			// so now we just trigger a flag and send with the timer
			_bufferingChanged = true;
		}

		private function id3Handler(e:Event):void {
			//sendEvent(MediaEvent.LOADEDMETADATA);
			try {
				var id3:ID3Info = _sound.id3;
				var obj:Object = {
					type:'id3',
					album:id3.album,
					artist:id3.artist,
					comment:id3.comment,
					genre:id3.genre,
					songName:id3.songName,
					track:id3.track,
					year:id3.year
				};
			} catch (err:Error) {}
		}

		private function errorHandler(event:IOErrorEvent):void {
			_element.sendEvent("error", {message: "IOError: "+event.text+".\nThe resource is unavailable or unreachable."});
		}

		private function timerEventHandler(e:TimerEvent):void {
			// calculate duration
			var duration:Number = Math.round(_sound.length * _sound.bytesTotal / _sound.bytesLoaded / 100) / 10;
			//Logger.debug("bt: "+_sound.bytesTotal+" bl: "+_sound.bytesLoaded);
			updateDuration(duration);

			updateTime(_soundChannel.position / 1000);

			// check for changes in buffer
			if (_bufferingChanged) {
				updateBuffer(100 * _bytesLoaded / _bytesTotal, 0);
				_bufferingChanged = false;
			}

			// sometimes the ended event doesn't fire, here's a fake one
			if (_duration > 0 && _currentTime >= _duration - 0.2)
				handleEnded();
		}

		private function soundCompleteHandler(e:Event):void {
			handleEnded();
		}

		private function handleEnded():void {
			_isEnded = true;
			pauseMedia();
			_element.sendEvent("ended", null);
			_isEnded = false;
			updateTime(0);
		}

		private function didStartPlaying():void {
			_isPaused = false;
			_element.sendEvent("playing", null);
		}

		// Overriden functions
		// -------------------------------------------------------------------
		public override function setSrc(url:String):void {
			_mediaUrl = url;
			_isLoaded = false;
			if (_preload)
				loadMedia();
		}

		public override function loadMedia():void {
			if (_mediaUrl == "")
				return;

			_isLoading = true;
			if (_sound) {
				if (_sound.hasEventListener(IOErrorEvent.IO_ERROR))
					_sound.removeEventListener(IOErrorEvent.IO_ERROR, errorHandler);
				if (_sound.hasEventListener(ProgressEvent.PROGRESS))
					_sound.removeEventListener(ProgressEvent.PROGRESS, progressHandler);
				if (_sound.hasEventListener(Event.ID3))
					_sound.removeEventListener(Event.ID3, id3Handler);
				try {
					_sound.close();
				} catch (err:Error) {}
			}

			_sound = new Sound();
			_sound.addEventListener(IOErrorEvent.IO_ERROR, errorHandler);
			_sound.addEventListener(ProgressEvent.PROGRESS, progressHandler);
			_sound.addEventListener(Event.ID3, id3Handler);
			_sound.load(new URLRequest(_mediaUrl));
			updateTime(0);

			_isLoaded = true;

			if (_playAfterLoading) {
				_playAfterLoading = false;
				playMedia();
			}
			_isLoading = false;
		}

		public override function playMedia():void {
			if (!_isLoaded) {
				_playAfterLoading = true;
				if (!_isLoading)
					loadMedia();
				return;
			}
			_timer.stop();
			_soundChannel = _sound.play(_currentTime*1000, 0, _soundTransform);
			_soundChannel.removeEventListener(Event.SOUND_COMPLETE, soundCompleteHandler);
			_soundChannel.addEventListener(Event.SOUND_COMPLETE, soundCompleteHandler);
			_timer.start();

			didStartPlaying();
		}

		public override function pauseMedia():void {
			_timer.stop();
			if (_soundChannel != null) {
				updateTime(_soundChannel.position / 1000);
				_soundChannel.stop();
			}

			_isPaused = true;
			_element.sendEvent("paused", null);
		}

		public override function stopMedia():void {
			if (_timer != null) {
				_timer.stop();
			}
			if (_soundChannel != null) {
				updateTime(0);
				_soundChannel.stop();
			}
			_element.sendEvent("stopped", null);
		}

		public override function seek(pos:Number):void {
			_timer.stop();
			_element.sendEvent("buffering", {playing: true});
			updateTime(pos);
			_soundChannel.stop();
			_soundChannel = _sound.play(_currentTime * 1000, 0, _soundTransform);
			_timer.start();

			didStartPlaying();
		}

		public override function setVolume(volume:Number):void {
			_volume = volume;
			_soundTransform.volume = _muted ? 0 : _volume;
			if (_soundChannel != null)
				_soundChannel.soundTransform = _soundTransform;
		}

		public override function setMuted(muted:Boolean):void {
			if (_muted == muted)
				return;
			_muted = muted;
			_soundTransform.volume = _muted ? 0 : _volume;
			if (_soundChannel != null)
				_soundChannel.soundTransform = _soundTransform;
		}
	}
}
