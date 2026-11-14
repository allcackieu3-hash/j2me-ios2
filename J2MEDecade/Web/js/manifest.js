/**
 * Parses manifest compliant with Java JAR specification.
 */
js2me.parseManifest = function (content) {
	var manifest = {};
	if (!content) return manifest;
	var lines = content.replace(/\r\n/g, '\n').replace(/\r/g, '\n').split('\n');
	var lastSection = '';
	for (var i = 0; i < lines.length; i++) {
		var line = lines[i];
		if (!line) continue;
		if (line.charAt(0) === ' ' && lastSection) {
			manifest[lastSection] += line.trim();
		} else {
			var colonIdx = line.indexOf(':');
			if (colonIdx !== -1) {
				lastSection = line.substring(0, colonIdx).trim().toLowerCase();
				manifest[lastSection] = line.substring(colonIdx + 1).trim();
			}
		}
	}
	return manifest;
};
