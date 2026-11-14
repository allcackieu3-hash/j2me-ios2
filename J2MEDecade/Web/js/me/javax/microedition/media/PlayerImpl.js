js2me.createClass({
	construct: function (stream, mime) {
		this.listeners = [];
		this.state = this.$UNREALIZEDI;
		this.countLoop = 1;
		this.repeated = 0;
		// Audio is completely disabled per user configuration:
		// No audio element creation, zero audio decoding overhead
		this.control = new javaRoot.$javax.$microedition.$media.$control.$VolumeControlImpl(this);
	},
	$CLOSEDI: 0,
	$UNREALIZEDI: 100,
	$REALIZEDI: 100,
	$PREFETCHEDI: 300,
	$STARTEDI: 400,
	/*
	 * public void addPlayerListener(PlayerListener playerListener)
	 */
	$addPlayerListener$Ljavax_microedition_media_PlayerListener_$V: function (listener) {
		this.listeners.push(listener);
	},
	/*
	 * public void prefetch()
	 */
	$prefetch$$V: function () {
		if (this.state == this.$CLOSEDI) {
			throw new javaRoot.$java.$lang.$IllegalStateException();
		}
		this.state = this.$PREFETCHEDI;
	},
	/*
	 * public void realize()
	 */
	$realize$$V: function () {
		if (this.state == this.$CLOSEDI) {
			throw new javaRoot.$java.$lang.$IllegalStateException();
		}
		if (this.state == this.$UNREALIZEDI) {
			this.state = this.$PREFETCHEDI;
		}
	},
	/*
	 * public void setLoopCount(int count)
	 */
	$setLoopCount$I$V: function (countLoop) {
		if (this.state == this.$CLOSEDI || this.state == this.$STARTEDI) {
			throw new javaRoot.$java.$lang.$IllegalStateException();
		}
		if (countLoop == 0) {
			throw new javaRoot.$java.$lang.$IllegalArgumentException();
		}
		this.countLoop = countLoop;
	},
	/*
	 * public Control getControl(String controlType)
	 */
	$getControl$Ljava_lang_String_$Ljavax_microedition_media_Control_: function () {
		return this.control;
	},
	/*
	 * public void start()
	 */
	$start$$V: function () {
		if (this.state == this.$CLOSEDI) {
			throw new javaRoot.$java.$lang.$IllegalStateException();
		}
		this.state = this.$STARTEDI;
		this.repeated = 0;
		// Silent playback
	},
	/*
	 * public int getState()
	 */
	$getState$$I: function () {
		return this.state;
	},
	/*
	 * public void stop()
	 */
	$stop$$V: function () {
		if (this.state == this.$CLOSEDI) {
			throw new javaRoot.$java.$lang.$IllegalStateException();
		}
		this.state = this.$PREFETCHEDI;
	},
	sendEvent: function () {
	},
	/*
	 * public long setMediaTime(long now)
	 */
	$setMediaTime$J$J: function (time) {
		return time;
	},
	/*
	 * public void close()
	 */
	$close$$V: function () {
		this.state = this.$CLOSEDI;
	},
	/*
	 * public void deallocate()
	 */
	$deallocate$$V: function () {
		if (this.state == this.$CLOSEDI) {
			throw new javaRoot.$java.$lang.$IllegalStateException();
		}
	},
	interfaces: ['javaRoot.$javax.$microedition.$media.$Player'],
	require: ['javaRoot.$javax.$microedition.$media.$control.$VolumeControlImpl']
});
