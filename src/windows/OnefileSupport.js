(function () {
    "use strict";
	var OnefileSupportProxy = {
		raiseSupport: function (win, fail, args, env) {
			try {
				if (!args[0]) {
					fail("Missing options");
				}
				var argConfig = args[0];
				zipFiles(win, fail, argConfig);
			} catch (e) {
				fail(e);
			}
		}
	};
	var OptOpenWrite = Windows.Storage.FileAccessMode.readWrite;
	var OptOverwrite = Windows.Storage.CreationCollisionOption.replaceExisting;
	var fileIO = Windows.Storage.FileIO;
	var storageFile;
	var getAppData = function () {
		return Windows.Storage.ApplicationData.current;
	};

	function zipFiles(successCallback, errorCallback, config) {
		var files = [];
		var storageFolder = getAppData().localFolder;
		var outputStream;
		var compressor;
		var storageFilePromises = {};

		ZipHelper.ZipUtil.zipFiles(config.files)
			.then(function (zipFile) {
				return uploadSupportZip(config, zipFile);
			})
			.done(function success(result) {
				successCallback()
			}, function error(err) {
				errorCallback(err);
			});
	}

	function uploadSupportZip(config, zipFile) {
		var dataToSend = new FormData();
		var deviceInfo = (config.device) ? config.device : '';
		var deviceData = new Windows.Security.ExchangeActiveSyncProvisioning.EasClientDeviceInformation();

		deviceInfo += '\nWindows OS: ' + deviceData.operatingSystem;
		deviceInfo += '\nSystemProductName: ' + deviceData.systemProductName;
		deviceInfo += '\nManufacturer: ' + deviceData.systemManufacturer;
		deviceInfo += '\nSystemFirmwareVersion: ' + deviceData.systemFirmwareVersion;
		deviceInfo += '\nSystemHardwareVersion: ' + deviceData.systemHardwareVersion;
		deviceInfo += '\nSystemSKU: ' + deviceData.systemSku;
		deviceInfo += '\nUserAgent: ' + navigator.userAgent;

		dataToSend.append("Device", deviceInfo);
		dataToSend.append("TicketDescription", config.ticketDescription);
		if (config.ticketNumber) {
			dataToSend.append("TicketID", config.ticketNumber);
		}
		dataToSend.append("ContactDetails", config.contactDetails);

		return zipFile.openAsync(Windows.Storage.FileAccessMode.read)
			.then(function (stream) {
				var blob = MSApp.createBlobFromRandomAccessStream("application/zip", stream);
				dataToSend.append("File", blob);
				var options = {
					url: config.endpoint,
					type: 'POST', data: dataToSend,
					headers: {
						"X-SessionID": config.sessionToken
					}
				}
				return WinJS.xhr(options);
			});
	}
    require("cordova/exec/proxy").add("OnefileSupport", OnefileSupportProxy);
})();