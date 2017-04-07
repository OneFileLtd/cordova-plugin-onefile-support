(function () {
	"use strict";
	var OnefileSupportProxy = {
		onefileSupport: function (win, fail, args, env) {
			try {
				if (!args[0]) {
					fail("Missing options");
				}
				var argConfig = args[0];
				zipFiles(win, fail, argConfig);
			} catch (e) {
				fail(e);
			}
		},
		onefileRecover: function (win, fail, args, env) {
			if (!args[0]) {
				fail("Missing options");
			}
			var argConfig = args[0];
			zipSizeLimit = argConfig.maxFileSize || zipSizeLimit;
			recoverFiles(win, fail, argConfig);
		}
	};
	var OptOpenWrite = Windows.Storage.FileAccessMode.readWrite;
	var OptOverwrite = Windows.Storage.CreationCollisionOption.replaceExisting;
	var fileIO = Windows.Storage.FileIO;
	var storageFile;
	var CommonFileQuery = Windows.Storage.Search.CommonFileQuery;
	var getAppData = function () {
		return Windows.Storage.ApplicationData.current;
	};
	var zipSizeLimit = 100 * 1024 * 1024;
	var zipper = new ZipUtil.Zipper();

	function zipFiles(successCallback, errorCallback, config) {
		var files = [];
		var storageFolder = getAppData().localFolder;
		var outputStream;
		var compressor;
		var storageFilePromises = {};

		zipper.zipFilesFromPath(config.files)
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

	function recoverFiles(success, error, config) {
		return getAppData().localFolder.getFolderAsync(config.selectedServer)
			.then(readAllFiles)
			.then(startDR.bind({ config: config }))
			.then(uploadDRZips.bind({ config: config }))
			.done(success, error);
	}

	function startDR(fLog) {
	    var config = this.config;
	    var uri = new Windows.Foundation.Uri(config.endpoint);
		var httpClient = new Windows.Web.Http.HttpClient();
		httpClient.defaultRequestHeaders.clear();
		httpClient.defaultRequestHeaders.insert('X-SessionID', config.sessionToken);
		httpClient.defaultRequestHeaders.accept.clear();
		httpClient.defaultRequestHeaders.accept.insertAt(0, new Windows.Web.Http.Headers.HttpMediaTypeWithQualityHeaderValue('application/json'));
		var fileLog = createServerFileLog.bind({ config: config })(fLog);
		return httpClient.postAsync(
			uri,
			new Windows.Web.Http.HttpStringContent(
				JSON.stringify(fileLog),
				Windows.Storage.Streams.UnicodeEncoding.utf8, 'application/json'
			)
		)
			.then(function returnLog(response) {
				return response.content.readAsStringAsync()
					.then(function readResponse(body) {
						return {
							fileLog: fLog,
							drCode: body
						};
					});
			});
	}

	function createServerFileLog(fileLog) {
		var config = this.config;
		var serverLog = {
			TicketID: config.ticketNumber,
			ZipFiles: [],
			ExcludedFiles: fileLog.ExcludedFiles
		};
		var zipFile;
		var currentSize = 0;
		var storageFile;
		var file;

		for (var i = 0; i < fileLog.ZipFiles.length; i++) {
			zipFile = {
				Name: "ZipFile" + i.toString(),
				Size: 0,
				Files: []
			};
			for (var j = 0; j < fileLog.ZipFiles[i].length; j++) {
				storageFile = fileLog.ZipFiles[i][j].storageFile;
				file = {
					Path: storageFile.path,
					Name: storageFile.name,
					InZipFile: false,
					Size: fileLog.ZipFiles[i][j].size
				};
				if (file.Size > 0) {
					file.InZipFile = true;
				}
				zipFile.Files.push(file);
			}
			serverLog.ZipFiles.push(zipFile);
		}
		return serverLog;
	}

	function uploadDRZips(drStart) {
		var fileLog = drStart.fileLog;
		var drCode = drStart.drCode;
		var storageFile;
		var storageFiles = [];
		var promises = [];
		for (var i = 0; i < fileLog.ZipFiles.length; i++) {
			storageFiles = [];
			for (var j = 0; j < fileLog.ZipFiles[i].length; j++) {
				storageFile = fileLog.ZipFiles[i][j].storageFile;
				if (fileLog.ZipFiles[i][j].size > 0) {
					storageFiles.push(storageFile);
				}
			}
			promises.push(
				zipper.zipFiles("ZipFile" + i.toString(), storageFiles)
					.then(uploadZip.bind({ drCode: drCode, config: this.config }))
					.then(deleteZip)
			);
		}
		return WinJS.Promise.join(promises);
	}

	function readAllFiles(folder) {
		return folder.getFilesAsync(CommonFileQuery.orderByName)
			.then(getAllFileInfo)
			.then(createFileLog);
	}

	function uploadZip(zipFile) {
		var drCode = this.drCode;
		var config = this.config;
		var uri = new Windows.Foundation.Uri(config.endpoint + '/' + drCode);
		var httpClient = new Windows.Web.Http.HttpClient();
		httpClient.defaultRequestHeaders.clear();
		httpClient.defaultRequestHeaders.insert('X-SessionID', config.sessionToken);
		return zipFile.openAsync(Windows.Storage.FileAccessMode.read)
			.then(function setFileStream(stream) {
				var formContent = new Windows.Web.Http.HttpMultipartFormDataContent('Upload----' + Date.now().toString())
				var content = new Windows.Web.Http.HttpMultipartContent();
				formContent.add(new Windows.Web.Http.HttpStreamContent(stream), 'File', zipFile.name);
				return httpClient.postAsync(uri, formContent);
			})
			.then(function returnZipFile(response) {
				if (response.isSuccessStatusCode) {
					return zipFile;
				}
				return response.content.readAsStringAsync()
					.then(function (body) {
						return WinJS.Promise.wrapError(body)
					});
			});
	}

	function deleteZip(zipFile) {
		return zipFile.deleteAsync();
	}

	function createFileLog(files) {
		var currentTotalSize = 0;
		var zipFileLists = [];
		var excludedFiles = [];
		var numZips = 0;
		var log = {
			ZipFiles: [],
			ExcludedFiles: []
		};
		var file;
		for (var i = 0; i < files.length; i++) {
			file = files[i];
			if (!zipFileLists[numZips]) {
				zipFileLists[numZips] = [];
			}
			if (file.size > zipSizeLimit) {
				excludedFiles.push({
					path: file.storageFile.path,
					name: file.storageFile.name,
					size: file.size
				});
			}
			if (currentTotalSize + file.size < zipSizeLimit) {
				currentTotalSize += file.size;
				zipFileLists[numZips].push(file);
			} else {
				numZips++;
				if (!zipFileLists[numZips]) {
					zipFileLists[numZips] = [];
				}
				currentTotalSize = file.size;
				zipFileLists[numZips].push(file);
			}
		}

		log.ZipFiles = zipFileLists;
		log.ExcludedFiles = excludedFiles;
		return log;
	}

	function getAllFileInfo(files) {
		var promises = [];
		var file;
		for (var i = 0; i < files.length; i++) {
			file = files[i];
			promises.push(file.getBasicPropertiesAsync()
				.then(getFileInfo.bind({ storageFile: file })));
		}
		return WinJS.Promise.join(promises);
	}

	function getFileInfo(basicProperties) {
		return {
			storageFile: this.storageFile,
			size: basicProperties.size
		};
	}

	// To run this from the solution, comment out the line below
	require("cordova/exec/proxy").add("OnefileSupport", OnefileSupportProxy);

    // Uncomment this to run locally
	//OnefileSupportProxy.onefileRecover(function s() {
	//    console.log('success');
	//}, function e(err) {
	//    console.log(err);
	//}, [{
	//    endpoint: "https://wsapiuat2.onefile.co.uk/api/v2/Mobile/DisasterRecovery",
	//    sessionToken: "sQcK6f18oqcakBHSzFhimmNhyP4/DBcxYL0ZvuouuCtNRyku+iZS13ZG5HCJoQOjooa9E3uN1Br+e/EKeRmDrKN7jU2bDCONzqo4SAjw5dVUPU/zrFW9ZYaZJ7y13Lke0JcLN0v87Yu//eau3zNLmIv79UFS4GJ3X2qpEawd/MwGcLGVFQEjyL4+2N1MH8LvqTXkhFl3XE6TJ01m4zJJA2HmRLI4YlemVWWt63O0oe3SqVFPKHl7YFyIFLG/fewH1XTDjdw+u2HSrxN07HBhjiqFSkeKoJv12Xzz2BEqRblPOZy0+j76LK2OxWO7ZgrIHva5RaTVC6KCilQ9pTuPnA==",
	//    maxFileSize: 104857600,
	//    maxZipFiles: 10,
	//    selectedServer: 6,
    //    ticketNumber: "123456789 d"
	//}]);
})();