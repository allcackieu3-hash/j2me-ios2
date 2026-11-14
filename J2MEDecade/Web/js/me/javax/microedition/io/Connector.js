js2me.createClass({
	/*
	 * public static Connection open(String name) throws IOException
	 */
	$open$Ljava_lang_String_$Ljavax_microedition_io_Connection_: function (url) {
		var text = url.text;
		if (text.indexOf('socket://') === 0) {
			var addr = text.substring(9);
			var colonIdx = addr.indexOf(':');
			var host = colonIdx !== -1 ? addr.substring(0, colonIdx) : addr;
			var port = colonIdx !== -1 ? parseInt(addr.substring(colonIdx + 1), 10) : 80;
			return new javaRoot.$javax.$microedition.$io.$SocketConnectionImpl(host, port);
		}
		if (text.indexOf('file://') === 0) {
			var parts = text.split(':');
			return new javaRoot.$javax.$microedition.$io.$file.$FileConnectionImpl(parts[1], parts[2]);
		}
		if (text.indexOf('localmsg:') === 0) {
			return new javaRoot.$com.$nokia.$mid.$s40.$io.$LocalMessageProtocolConnection(text.substring(9));
		}
		throw new Error('Unsupported protocol: ' + text);
	},
	$open$Ljava_lang_String_I$Ljavax_microedition_io_Connection_: function (url, mode) {
		return this.$open$Ljava_lang_String_$Ljavax_microedition_io_Connection_(url);
	},
	$open$Ljava_lang_String_IZ$Ljavax_microedition_io_Connection_: function (url, mode, timeouts) {
		return this.$open$Ljava_lang_String_$Ljavax_microedition_io_Connection_(url);
	},
	require: [
		'javaRoot.$javax.$microedition.$io.$SocketConnectionImpl',
		'javaRoot.$javax.$microedition.$io.$file.$FileConnectionImpl',
		'javaRoot.$com.$nokia.$mid.$s40.$io.$LocalMessageProtocolConnection'
	]
});
