cordova.define("cordova-plugin-onefile-support.onefileSupport", function(require, exports, module) {
var exec = require('cordova/exec');
var Support = function () {};

Support.prototype.sendSupport = function (config, success, error) {
	if (!config.ticketDescription) {
		error('Missing ticket description');
		return;
	}
	if (!config.contactDetails) {
		error('Missing contact details');
		return;
	}
	if (!config.sessionToken) {
		error('Missing session token');
		return;
	}
	if (!config.endpoint) {
		error('Missing endpoint');
		return;
	}
	if (!config.device) {
		error('Missing device info');
		return;
	}
	if (!config.files) {
		error('Missing files');
		return;
	}
	if (config.files && config.files.length === 0) {
		error('Missing files');
		return;
	}
	exec(success, error, "OnefileSupport", "onefileSupport", [config]);
};

module.exports = new Support();
});
