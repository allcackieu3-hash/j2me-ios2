/**
 * Launches a midlet with given id or main class.
 */
js2me.launchMidlet = function (id) {
	var rawClassName = null;

	// 1. Check MIDlet-N
	var mainMidlet = js2me.manifest['midlet-' + id] || js2me.manifest['midlet-1'];
	if (mainMidlet) {
		var parts = mainMidlet.split(',');
		rawClassName = parts.length >= 3 ? parts[2].trim() : parts[parts.length - 1].trim();
	}

	// 2. Check Main-Class (Standard for Ninja School Online / NSO jars)
	if (!rawClassName && js2me.manifest['main-class']) {
		rawClassName = js2me.manifest['main-class'].trim();
	}

	// 3. Fallback: Search resources for known NSO classes
	if (!rawClassName) {
		if (js2me.resources['main/Midlet.class']) {
			rawClassName = 'main.Midlet';
		} else if (js2me.resources['GameMidlet.class']) {
			rawClassName = 'GameMidlet';
		} else {
			for (var rName in js2me.resources) {
				if (rName.indexOf('.class') !== -1 && (rName.toLowerCase().indexOf('midlet') !== -1 || rName.toLowerCase().indexOf('main') !== -1)) {
					rawClassName = rName.replace(/\.class$/, '').replace(/\//g, '.');
					break;
				}
			}
		}
	}

	if (!rawClassName) {
		rawClassName = 'main.Midlet';
	}

	console.log('[Decade] Launching main class:', rawClassName);
	js2me['statics' + id] = {};
	var mainClassName = 'javaRoot.$' + rawClassName.replace(/\./g, '.$');
	js2me.currentVM = id;

	var mainThread = new javaRoot.$java.$lang.$Thread(function () {
		js2me.loadClass(mainClassName, function (mainClass) {
			console.log('[Decade] Main class loaded, initializing MIDlet...');
			var midlet = new mainClass();
			midlet._init$$V(function () {
				console.log('[Decade] MIDlet initialized, calling startApp()...');
				midlet.$startApp$$V();
			});
		}, function (err) {
			console.error('[Decade] Error loading main class:', err);
			alert('Không thể nạp class: ' + rawClassName);
		});
	});

	setTimeout(function () {
		js2me.currentVM = id;
		mainThread.$start$$V();
	}, 100);
};

js2me.launchJAR = function (blob) {
	function run() {
		js2me.loadJAR(blob, function () {
			console.log('[Decade] JAR parsed successfully, launching MIDlet...');
			js2me.launchMidlet(js2me.config.midlet || 1);
		});
	}

	if (typeof js2me.execute === 'undefined') {
		js2me.loadScript('js/program_zazu.js', function () {
			run();
		}, function () {
			run();
		});
	} else {
		run();
	}
};
