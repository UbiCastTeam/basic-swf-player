package basicplayer {
	import flash.media.Video;

	import BasicPlayer;

	public class PlayerClass {
		protected var _element:BasicPlayer;
		protected var _video:Video;
		protected var _timerRate:Number = 0;

		protected var _mediaUrl:String = "";
		protected var _preload:Boolean = false;
		protected var _isLive:Boolean = false;
		protected var _autoplay:Boolean = false;

		protected var _currentTime:Number = 0;
		protected var _duration:Number = 0;
		protected var _bufferPercent:Number = 0;
		protected var _bufferTime:Number = 0;

		protected var _volume:Number = 0.8;
		protected var _muted:Boolean = false;

		public function PlayerClass() {
		}

		protected function updateTime(currentTime:Number):void {
			if (_currentTime != currentTime) {
				_currentTime = currentTime;
				_element.sendEvent("time", {time: currentTime});
			}
		}

		protected function updateDuration(duration:Number):void {
			if (!isNaN(duration) && duration > 0 && duration != _duration) {
				_duration = duration;
				_element.sendEvent("duration", {duration: _duration});
			}
		}

		protected function updateBuffer(bufferPercent:Number, bufferTime:Number):void {
			var changed:Boolean = false;
			if (_bufferTime != bufferTime) {
				_bufferTime = bufferTime;
				changed = true;
				if ((isNaN(bufferPercent) || bufferPercent <= 0) && _duration > 0)
					bufferPercent = 100 * _bufferTime / _duration;
			}
			if (_bufferPercent != bufferPercent) {
				_bufferPercent = bufferPercent;
				changed = true;
			}
			if (changed)
				_element.sendEvent("buffer", {percent: _bufferPercent, time: _bufferTime});
		}

		public function getElement():Video {
			return _video;
		}

		public function setSize(width:Number, height:Number):void {
			if (_video == null)
				return;
			_video.width = width;
			_video.height = height;
		}

		public function duration():Number {
			return _duration;
		}

		public function currentTime():Number {
			return _currentTime;
		}

		public function currentBuffer():Number {
			return _bufferPercent;
		}

		public function getVolume():Number {
			return _volume;
		}

		public function getMuted():Boolean {
			return _muted;
		}

		// Functions to override
		public function loadMedia():void { }

		public function playMedia():void { }

		public function pauseMedia():void { }

		public function stopMedia():void { }

		public function seek(pos:Number):void { }

		public function setSrc(url:String):void { }

		public function setVolume(vol:Number):void { }

		public function setMuted(muted:Boolean):void { }
	}
}
