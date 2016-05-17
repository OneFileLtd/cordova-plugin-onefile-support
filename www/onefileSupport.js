window.support = function(config, success, error) {
	if (!config.ticketDescription) {
		error('Missing ticket description');
	}
	if (!config.contactDetails) {
		error('Missing contact details');
	}
	if (!config.ticketNumber) {
		error('Missing ticket number');
	}
	if (!config.sessionToken) {
		error('Missing session token');
	}
	if (!config.endpoint) {
		error('Missing endpoint');
	}
	if (!config.files) {
		error('Missing files');
	}
	if (config.files && config.files.length === 0) {
		error('Missing files');
	}
    cordova.exec(success, error, "OnefileSupport", "onefileSupport", [config]);
};