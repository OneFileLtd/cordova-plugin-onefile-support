window.support = function(ticketDescription, ticketNumber, contactDetails, callback) {
	var args = [
		ticketDescription,
		ticketNumber,
		contactDetails
	];
    cordova.exec(callback, function(err) {
        callback('Nothing to echo.');
    }, "SupportUpload", "uploadSupport", args);
};