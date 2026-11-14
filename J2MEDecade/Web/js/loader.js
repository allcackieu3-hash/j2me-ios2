/**
 * Loads classes and resources from a given JAR file.
 */
js2me.loadJAR = function (file, callback) {
	function loadReader(reader) {
		zip.useWebWorkers = false;
		zip.workerScriptsPath = 'js/zip/';
		zip.createReader(reader, function (zipReader) {
			zipReader.getEntries(function (entries) {
				js2me.addResources(entries);
				js2me.loadResource('META-INF/MANIFEST.MF', function (data) {
					var content = data ? js2me.UTF8ToString(data) : '';
					js2me.manifest = js2me.parseManifest(content);
					var vendor = js2me.manifest['midlet-vendor'] || 'Decade';
					var name = js2me.manifest['midlet-name'] || 'Game';
					js2me.storageName = vendor + '/' + name + '//' + file.size + '/';
					callback();
				});
			});
		}, function (message) {
			console.error('ZIP Reader Error:', message);
			alert('Lỗi đọc file JAR: ' + message);
		});
	}

	js2me.setupJVM(function () {
		loadReader(new zip.BlobReader(file));
	});
};

js2me.loadScript = function (filename, successCallback, errorCallback) {
	var element = document.createElement('script');
	element.src = filename;
	element.onload = function () {
		if (element.parentNode) element.parentNode.removeChild(element);
		if (successCallback) successCallback();
	};
	element.onerror = function () {
		if (element.parentNode) element.parentNode.removeChild(element);
		if (errorCallback) errorCallback();
	};
	document.head.appendChild(element);
};
