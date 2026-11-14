js2me.lastSocketId = js2me.lastSocketId || 0;

js2me.createClass({
	construct: function (host, port) {
		var parent = this;
		this.socketId = ++js2me.lastSocketId;
		this.connected = false;
		
		this.inputStream = new javaRoot.$java.$io.$InputStream();
		this.inputStream.buffer = [];
		this.inputStream.position = 0;
		this.inputStream.$read$$I = function () {
			if (this.buffer.length === 0) {
				return -1;
			}
			if (this.position >= this.buffer[0].length) {
				this.buffer.shift();
				this.position = 0;
			}
			if (this.buffer.length === 0) {
				return -1;
			}
			return this.buffer[0][this.position++];
		};

		this.outputStream = new javaRoot.$java.$io.$OutputStream();
		this.outputStream.buffer = new Uint8Array(1);
		this.outputStream.$write$I$V = function (byte) {
			this.buffer[0] = byte;
			if (window.DecadeSocket) {
				window.DecadeSocket.send(parent.socketId, this.buffer);
			}
		};

		if (window.DecadeSocket) {
			window.DecadeSocket.open(this.socketId, host, port, function (data) {
				parent.inputStream.buffer.push(data);
			});
		}
	},
	/*
	 * public InputStream openInputStream() throws IOException
	 */
	$openInputStream$$Ljava_io_InputStream_: function () {
		return this.inputStream;
	},
	/*
	 * public OutputStream openOutputStream() throws IOException
	 */
	$openOutputStream$$Ljava_io_OutputStream_: function () {
		return this.outputStream;
	},
	/*
	 * public void close() throws IOException
	 */
	$close$$V: function () {
		if (window.DecadeSocket) {
			window.DecadeSocket.close(this.socketId);
		}
	},
	interfaces: ['javaRoot.$javax.$microedition.$io.$SocketConnection']
});
