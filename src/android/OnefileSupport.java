package uk.co.onefile.nomadionic.support;

import android.content.Context;
import android.content.ContextWrapper;
import android.os.Build;
import android.os.Environment;
import android.util.Log;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaInterface;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CordovaWebView;
import org.apache.cordova.file.FileExistsException;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.*;
import java.util.ArrayList;

import java.util.HashMap;
import java.util.List;
import java.util.zip.ZipEntry;
import java.util.zip.ZipOutputStream;

public class OnefileSupport extends CordovaPlugin {
	private static final String EVIDENCE_LOG_FILENAME = "evidence-log.json";
	private static final String TEST_DIRECTORY = "/storage/sdcard0/onefile-test-area";
	private static final int BUFFER = 2048;
	private static final String LINE_FEED = "\r\n";
	private static final int STATUS_ERROR = 0;
	private static final int STATUS_SUCCESSFUL = 1;

	private static final Long MAX_ZIP_SIZE = 285000L;
	private static final Long MAX_SINGLE_FILE_SIZE = MAX_ZIP_SIZE;
	private static final String ZIP_FILENAME = "ZipFile";
	private static final String eFILE_DOESNT_EXIST = "file doesn't exist";

	private List<File> evidenceFiles;
	private static String rootPath;
	private CallbackContext currentCallbackContext;

	@Override
	public void initialize(CordovaInterface cordova, CordovaWebView webView) {
		super.initialize(cordova, webView);
		// your init code here
	}

	@Override
	public boolean execute(String action, JSONArray args, final CallbackContext callbackContext) throws JSONException {
		Log.i("OneFileSupportPlugin", "Im in here!");
		if (action.equals("onefileSupport")) {
			final JSONObject config = args.getJSONObject(0);
			cordova.getThreadPool().execute(new Runnable() {
				public void run() {
					uploadSupport(config, callbackContext);
				}
			});
			return true;
		}
		if (action.equals("onefileRecover")) {
			final JSONObject config = args.getJSONObject(0);
			cordova.getThreadPool().execute(new Runnable() {
				public void run() {
					recover(config, callbackContext);
				}
			});
			return true;
		}
		return false;
	}

	private void recover(JSONObject config, CallbackContext callbackContext) {
		currentCallbackContext = callbackContext;
		try {
			Log.i("OneFileSupportPlugin", config.toString(2));

			String serverPath = config.getString("selectedServerId");
			if(serverPath != null) {
				rootPath = cordova.getActivity().getApplicationContext().getFilesDir().getPath() + "/" + serverPath;
				Log.i("OneFileSupportPlugin", "rootPath" + rootPath);

				JSONObject jSONData = createEvidenceLog();
				createLogFile(jSONData);
				zipFilesFromEvidenceLog(jSONData);

				JSONObject result = new JSONObject();
				result.put("status", STATUS_SUCCESSFUL);
				callbackContext.success(result);
			}
		} catch (JSONException e) {
			callbackContext.error(e.getMessage());
		} finally {
		}
	}

	private void uploadSupport(JSONObject config, CallbackContext callbackContext) {
		File zipFile = null;
		currentCallbackContext = callbackContext;
		try {
			String ticketDescription = config.getString("ticketDescription");
			String ticketNumber = "";
			String contactDetails = config.getString("contactDetails");
			JSONArray files = config.getJSONArray("files");
			String sessionToken = config.getString("sessionToken");
			String endpoint = config.getString("endpoint");
			String device = config.getString("device");
			HashMap<String, String> headers = new HashMap<String, String>();
			Context context = this.cordova.getActivity().getApplicationContext();
			headers.put("X-SessionID", sessionToken);

			uk.co.onefile.nomadionic.support.MultipartUtility multipart = new uk.co.onefile.nomadionic.support.MultipartUtility(endpoint, "UTF-8", headers);

			if(!config.isNull("ticketNumber")) {
				ticketNumber = config.getString("ticketNumber");
			}


			device += "\nDevice: " + Build.DEVICE;
			device += "\nManufacturer: " + Build.MANUFACTURER;
			device += "\nModel: " + Build.MODEL;
			device += "\nAndroid OS Version: " + Build.VERSION.RELEASE;

			multipart.addFormField("Device", device);
			multipart.addFormField("TicketDescription", ticketDescription);
			multipart.addFormField("TicketID", ticketNumber);
			multipart.addFormField("ContactDetails", contactDetails);

			zipFile = File.createTempFile("tmpSupportUpload", "zip", context.getCacheDir());

			try {
				createDatabaseZipFile(files, zipFile);
			} catch (Exception e) {
				callbackContext.error(e.getMessage());
			}
			multipart.addFilePart("File", zipFile);

			List<String> finish = multipart.finish();

			callbackContext.success(new JSONArray(finish));

		} catch (JSONException e) {
			callbackContext.error(e.getMessage());
		} catch (IOException e) {
			callbackContext.error(e.getMessage());
		}
		finally {
			if (zipFile != null) {
				zipFile.delete();
			}
		}
	}

	private void createDatabaseZipFile(JSONArray files, File zipFile) throws Exception {
		BufferedInputStream origin = null;
		FileOutputStream dest = new FileOutputStream(zipFile);

		ZipOutputStream out = new ZipOutputStream(new BufferedOutputStream(dest));

		byte data[] = new byte[BUFFER];

		for(int i=0; i < files.length(); i++) {
			FileInputStream fi = new FileInputStream(this.cordova.getActivity().getDatabasePath(files.getString(i)));
			origin = new BufferedInputStream(fi, BUFFER);
			Log.i("createDatabaseZipFile", files.getString(i));
			Log.i("createDatabaseZipFile", files.getString(i).substring(files.getString(i).lastIndexOf("/") + 1));
			ZipEntry entry = new ZipEntry(files.getString(i).substring(files.getString(i).lastIndexOf("/") + 1));
			out.putNextEntry(entry);
			int count;
			while ((count = origin.read(data, 0, BUFFER)) != -1) {
				out.write(data, 0, count);
			}
			origin.close();
		}

		out.close();
	}

	/* Disaster recovery methods */
	private void getEvidenceFiles() {
		ArrayList<Long> inSizes = new ArrayList<Long>();
		ArrayList<String> inPaths = new ArrayList<String>();
		// Log.d("debug", "-" + rootPath);
		File directory = new File(rootPath);
		evidenceFiles = getListFiles(directory);
	}

	private List<File> getListFiles(File parentDir) {
		ArrayList<File> inFiles = new ArrayList<File>();
		File[] files = parentDir.listFiles();
		for (File file : files) {
			if (file.isDirectory()) {
				inFiles.addAll(getListFiles(file));
			} else {
				// Log.d("getListFiles", "File: " + file);
				// Log.d("getListFiles", "Size: " + file.length());
				// Log.d("getListFiles", "Path: " + file.getAbsolutePath());
				inFiles.add(file);
			}
		}
		return inFiles;
	}

	public void createLogFile(JSONObject jSON) {
		try {
			String sBody = jSON.toString();
			String dataPath = TEST_DIRECTORY; // cordova.getActivity().getApplicationContext().getFilesDir().getPath();
			Log.d("debug", "-" + dataPath);
			File logFile = new File(dataPath);
			File gpxfile = new File(logFile, EVIDENCE_LOG_FILENAME);
			FileWriter writer = new FileWriter(gpxfile);
			writer.append(sBody);
			writer.flush();
			writer.close();
			Log.d("CreatelogFile", "Saved: ");
		} catch (IOException e) {
			e.printStackTrace();
		}
	}

	public JSONObject createEvidenceLog() {
		try {
			JSONArray zipFiles = new JSONArray();
			JSONArray files = new JSONArray();
			JSONArray excluded = new JSONArray();

			Long currentZipSize = 0L;
			Long zipFileIndex = 0L;
			Long numberOfFilesInZip = 0L;
			int currentFile = 0;
			getEvidenceFiles();

			int numberOfFiles = evidenceFiles.size();
			if(numberOfFiles > 0) {
				do {
					File fileObj = evidenceFiles.get(currentFile);
					Long fileSize = fileObj.length();
					boolean inzipfile = (fileSize > 0 && fileSize <= MAX_SINGLE_FILE_SIZE);
					if (fileObj.exists()) {

						int position = fileObj.getAbsolutePath().indexOf("/files/") + 7;
						JSONObject file = new JSONObject();
						file.put("FullPath", fileObj.getAbsolutePath());
						file.put("Path", fileObj.getAbsolutePath().substring(position));
						file.put("Name", fileObj.getName());
						file.put("Size", fileSize);
						if(inzipfile)
							file.put("InZipFile", inzipfile);

						if (inzipfile) {
							if ((currentZipSize + fileSize) > MAX_ZIP_SIZE) {
								JSONObject zipFile = new JSONObject();
								zipFile.put("Name", ZIP_FILENAME + zipFileIndex);
								zipFile.put("Size", currentZipSize);
								zipFile.put("Files", files);
								zipFile.put("Count", numberOfFilesInZip);

								zipFiles.put(zipFile);
								zipFileIndex++;
								currentZipSize = 0L;
								numberOfFilesInZip = 0L;
								files = new JSONArray();
							}
							files.put(file);
							numberOfFilesInZip++;
							currentZipSize += fileSize;
						} else {
							excluded.put(file);
						}
					} else {
						currentCallbackContext.error(eFILE_DOESNT_EXIST);
					}
					currentFile++;
				} while (currentFile < numberOfFiles);
				if (files.length() > 0) {
					JSONObject zipFile = new JSONObject();
					zipFile.put("Name", ZIP_FILENAME + zipFileIndex);
					zipFile.put("Size", currentZipSize);
					zipFile.put("Files", files);
					zipFile.put("Count", numberOfFilesInZip);
					zipFiles.put(zipFile);
				}
				JSONObject logFile = new JSONObject();
				logFile.put("ZipFiles", zipFiles);
				logFile.put("Excluded", excluded);
				logFile.put("TicketNumber", 0);
				Log.i("OnefileSupport-logFile", logFile.toString(2));
				return logFile;
			}
			return null;
		}
		catch (JSONException e) {
			e.printStackTrace();
		};
		return null;
	}

	public void zipFilesFromEvidenceLog(JSONObject jSON) {
		try {
			if(jSON != null) {
				JSONArray zipFiles = jSON.getJSONArray("ZipFiles");
				if (zipFiles.length() > 0) {
					BufferedInputStream origin = null;
					// Each zip file --
					for (int i = 0; i < zipFiles.length(); i++) {
						JSONObject currentZip = zipFiles.getJSONObject(i);
						// Create zip file
						String zipPath = currentZip.get("Name").toString();
						File zipFile = new File(TEST_DIRECTORY, zipPath + ".zip");
						Log.i("zipFilesFromJSON", zipFile.getAbsolutePath());
						FileOutputStream dest = new FileOutputStream(zipFile);
						ZipOutputStream out = new ZipOutputStream(new BufferedOutputStream(dest));

						JSONArray files = currentZip.getJSONArray("Files");
						for (int f = 0; f < files.length(); f++) {

							JSONObject file = files.getJSONObject(f);
							String path = file.get("FullPath").toString();
							File evidenceFile = new File(path);
							FileInputStream evidenceStream = new FileInputStream(evidenceFile);

							byte data[] = new byte[BUFFER];
							origin = new BufferedInputStream(evidenceStream, BUFFER);
							int position = evidenceFile.getAbsolutePath().indexOf("/files/") + 7;
							Log.i("zipFilesFromJSON", evidenceFile.getAbsolutePath().substring(position));
							ZipEntry entry = new ZipEntry(evidenceFile.getAbsolutePath().substring(position));
							out.putNextEntry(entry);
							int count;
							while ((count = origin.read(data, 0, BUFFER)) != -1) {
								out.write(data, 0, count);
							}
							origin.close();
						}
						out.close();
					}
				}
			}
		}
		catch (JSONException e) {
			e.printStackTrace();
		}
		catch (FileNotFoundException e) {
			e.printStackTrace();
		}
		catch (IOException e) {
			e.printStackTrace();
		};
	}

	public void deleteTempFiles() {
		try {
			File tempZipFile = new File(TEST_DIRECTORY);
			if (tempZipFile.exists()) {
				boolean result = tempZipFile.delete();
			}
		} catch (SecurityException e) {
			e.printStackTrace();
		}
	}

	public void createTestDirectory() {
		try {
			File folder = new File(TEST_DIRECTORY);
			if (!folder.exists()) {
				boolean success = folder.mkdirs();
			}
		} catch (SecurityException e) {
			e.printStackTrace();
		}
	}

	// ~/Library/Android/sdk/platform-tools/adb pull /storage/sdcard0/onefile-test-area/ DATA
}