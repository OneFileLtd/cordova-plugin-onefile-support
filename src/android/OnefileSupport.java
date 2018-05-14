package uk.co.onefile.nomadionic.support;

import android.app.ActivityManager;
import android.content.Context;
import android.content.ContextWrapper;
import android.os.Build;
import android.os.Environment;
import android.util.Log;

import android.view.Surface;
import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaInterface;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CordovaWebView;
import org.apache.cordova.file.FileExistsException;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.*;
import java.net.HttpURLConnection;
import java.net.MalformedURLException;
import java.net.URL;
import java.util.ArrayList;

import java.util.HashMap;
import java.util.List;
import java.util.zip.ZipEntry;
import java.util.zip.ZipOutputStream;

import static android.app.ActivityManager.*;
import static android.content.Context.ACTIVITY_SERVICE;
import static android.view.View.X;

public class OnefileSupport extends CordovaPlugin {
	private static final String EVIDENCE_LOG_FILENAME = "evidence-log.json";
	private static final String TEST_DIRECTORY = "/storage/sdcard0/onefile-test-area";
	private static final int BUFFER = 2048;
	private static final String LINE_FEED = "\r\n";
	private static final int STATUS_ERROR = 0;
	private static final int STATUS_SUCCESSFUL = 1;

	private static Long maxFileSize;
	private static Long maxZipFiles;
	private static final String ZIP_FILENAME = "ZipFile";
	private static final String eFILE_DOESNT_EXIST = "file doesn't exist";
	private static final String eNO_FILES_EXIST = "no recoverable files exist";
	private static final String eNOT_ENOUGH_MEMORY = "Not enough memory to perform this task";
	private static final String eNOT_ENOUGH_RESOURCES = "Not enough resources to perform this task";
	private List<File> evidenceFiles;
	private static String rootPath;
	private CallbackContext currentCallbackContext;

	private String sessionToken;
	private String sessionGUID;
	private String startEndpoint;
	private String uploadEndpoint;
	private String ticketNumber;
	private Boolean errorOccurred;
	@Override
	public void initialize(CordovaInterface cordova, CordovaWebView webView) {
		super.initialize(cordova, webView);
		getFreeMemory();
		errorOccurred = false;
	}

	@Override
	public boolean execute(String action, JSONArray args, final CallbackContext callbackContext) throws JSONException {
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
		errorOccurred = false;
		try {
			sessionToken = config.getString("sessionToken");
			startEndpoint = config.getString("endpoint");
			uploadEndpoint = config.getString("endpoint");
			ticketNumber = config.getString("ticketNumber");
			String serverPath = config.getString("selectedServer");
			maxFileSize = Long.parseLong(config.getString("maxFileSize"));
			maxZipFiles = Long.parseLong(config.getString("maxZipFiles"));
			if (serverPath != null) {
				rootPath = cordova.getActivity().getApplicationContext().getFilesDir().getPath() + "/" + serverPath;
				JSONObject jSONData = createEvidenceLog();
				if (jSONData == null) {
					callbackContext.error(eNO_FILES_EXIST);
				} else {
					createLogFile(jSONData);
					int responseCode = startRecovery(jSONData);
					if (responseCode >= 200 && responseCode < 300)
					{
						zipFilesFromEvidenceLog(jSONData);
						deleteTempLogFile();
						JSONObject result = new JSONObject();
						result.put("status", STATUS_SUCCESSFUL);
						callbackContext.success(result);
					} else {
						callbackContext.error("Failed with error code: " + responseCode);
					}
				}
			}
		} catch (JSONException e) {
			e.printStackTrace();
			callbackContext.error(e.getMessage());
		}
	}

	private void uploadSupport(JSONObject config, CallbackContext callbackContext) {
		File zipFile = null;
		currentCallbackContext = callbackContext;
		try {
			String ticketDescription = config.getString("ticketDescription");
			String ticketNumber = "";
			String contactDetails = config.getString("contactDetails");
			String sessionToken = config.getString("sessionToken");
			String endpoint = config.getString("endpoint");
			String device = config.getString("device");
			Context context = this.cordova.getActivity().getApplicationContext();

			JSONArray files = config.getJSONArray("files");
			zipFile = File.createTempFile("tmpSupportUpload", "zip", context.getCacheDir());
			createDatabaseZipFile(files, zipFile);

			HashMap<String, String> headers = new HashMap<String, String>();
			headers.put("X-SessionID", sessionToken);

			uk.co.onefile.nomadionic.support.MultipartUtility multipart = new uk.co.onefile.nomadionic.support.MultipartUtility(endpoint, "UTF-8", headers);
			if (!config.isNull("ticketNumber")) {
				ticketNumber = config.getString("ticketNumber");
			}
			device += "\nDevice: " + Build.DEVICE;
			device += "\nManufacturer: " + Build.MANUFACTURER;
			device += "\nModel: " + Build.MODEL;
			device += "\nAndroid OS Version: " + Build.VERSION.RELEASE;
			if(files.length() > 0){
				device += "\n\n[Database Files Attached]";
			} else {
				device += "\n\n[Database Files NOT Attached]";
			}
			multipart.addFormField("Device", device);
			multipart.addFormField("TicketDescription", ticketDescription);
			multipart.addFormField("TicketID", ticketNumber);
			multipart.addFormField("ContactDetails", contactDetails);
			multipart.addFilePart("File", zipFile);
			List<String> finish = multipart.finish();
			callbackContext.success(new JSONArray(finish));
		} catch (JSONException e) {
			callbackContext.error(e.getMessage());
		} catch (IOException e) {
			callbackContext.error(e.getMessage());
		} catch (OutOfMemoryError e) {
			callbackContext.error(eNOT_ENOUGH_MEMORY);
		} catch (Surface.OutOfResourcesException e) {
			callbackContext.error(eNOT_ENOUGH_RESOURCES);
		} catch (Exception e) {
			callbackContext.error(e.getMessage());
		} finally {
			if (zipFile != null && zipFile.exists()) {
				zipFile.delete();
			}
		}
	}

	private void createDatabaseZipFile(JSONArray files, File zipFile) throws Exception {
		BufferedInputStream origin = null;
		FileOutputStream dest = new FileOutputStream(zipFile);
		ZipOutputStream out = new ZipOutputStream(new BufferedOutputStream(dest));
		byte data[] = new byte[BUFFER];
		for (int i = 0; i < files.length(); i++) {
			FileInputStream fi = new FileInputStream(this.cordova.getActivity().getDatabasePath(files.getString(i)));
			origin = new BufferedInputStream(fi, BUFFER);
			ZipEntry entry = new ZipEntry(files.getString(i).substring(files.getString(i).lastIndexOf("/") + 1));
			out.putNextEntry(entry);
			int count;
			while ((count = origin.read(data, 0, BUFFER)) != -1) {
				out.write(data, 0, count);
			}
			origin.close();
		}
		if(files.length() == 0) {
			ZipEntry entry = new ZipEntry("Nothing_Uploaded.txt");
			out.putNextEntry(entry);
			StringBuilder sb = new StringBuilder();
			sb.append("No databases were uploaded");
			byte[] fileContent = sb.toString().getBytes();
			out.write(fileContent, 0, fileContent.length);
		}
		out.close();
		dest.close();
	}

	/* Disaster recovery methods */
	private void getEvidenceFiles() {
		ArrayList<Long> inSizes = new ArrayList<Long>();
		ArrayList<String> inPaths = new ArrayList<String>();
		File directory = new File(rootPath);
		evidenceFiles = getListFiles(directory);
	}

	private List<File> getListFiles(File parentDir) {
		if(errorOccurred) {
			return null;
		}
		try {
			ArrayList<File> inFiles = new ArrayList<File>();
			File[] files = parentDir.listFiles();
			if (files != null && files.length > 0) {
				for (File file : files) {
					if (file.isDirectory()) {
						inFiles.addAll(getListFiles(file));
					} else {
						inFiles.add(file);
					}
				}
			}
			return inFiles;
		} catch (NullPointerException e) {
			errorOccurred = true;
			return null;
		}
	}

	public void createLogFile(JSONObject jSON) {
		if(!errorOccurred) {
			try {
				String sBody = jSON.toString();
				String dataPath = cordova.getActivity().getApplicationContext().getFilesDir().getPath();
				File logFile = new File(dataPath);
				File gpxfile = new File(logFile, EVIDENCE_LOG_FILENAME);
				FileWriter writer = new FileWriter(gpxfile);
				writer.append(sBody);
				writer.flush();
				writer.close();
			} catch (IOException e) {
				e.printStackTrace();
			} catch (OutOfMemoryError e) {
				errorOccurred = true;
				currentCallbackContext.error(eNOT_ENOUGH_MEMORY);
			} catch (Surface.OutOfResourcesException e) {
				errorOccurred = true;
				currentCallbackContext.error(eNOT_ENOUGH_RESOURCES);
			}
		}
	}

	public JSONObject createEvidenceLog() {
		if (!errorOccurred) {
			try {
				JSONArray zipFiles = new JSONArray();
				JSONArray files = new JSONArray();
				JSONArray excluded = new JSONArray();

				Long currentZipSize = 0L;
				Long zipFileIndex = 0L;
				Long numberOfFilesInZip = 0L;
				int currentFile = 0;
				getEvidenceFiles();
				if (evidenceFiles != null) {
					int numberOfFiles = evidenceFiles.size();
					if (numberOfFiles > 0) {
						do {
							File fileObj = evidenceFiles.get(currentFile);
							Long fileSize = fileObj.length();
							boolean inzipfile = (fileSize > 0L && fileSize <= maxFileSize && zipFileIndex <= maxZipFiles);
							if (fileObj.exists()) {
								int position = fileObj.getAbsolutePath().indexOf("/files/") + 7;
								JSONObject file = new JSONObject();
								file.put("FullPath", fileObj.getAbsolutePath());
								file.put("Path", fileObj.getAbsolutePath().substring(position));
								file.put("Name", fileObj.getName());
								file.put("Size", fileSize);
								if (inzipfile)
									file.put("InZipFile", inzipfile);

								if (inzipfile) {
									if ((currentZipSize + fileSize) > maxFileSize) {
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
						logFile.put("ExcludedFiles", excluded);
						logFile.put("TicketID", ticketNumber);
						return logFile;
					}
				}
			} catch (JSONException e) {
				errorOccurred = true;
				currentCallbackContext.error(e.getMessage());
			} catch (OutOfMemoryError e) {
				errorOccurred = true;
				currentCallbackContext.error(eNOT_ENOUGH_MEMORY);
			} catch (Surface.OutOfResourcesException e) {
				errorOccurred = true;
				currentCallbackContext.error(eNOT_ENOUGH_RESOURCES);
			}
		}
		return null;
	}

	public void zipFilesFromEvidenceLog(JSONObject jSON) {
		if (!errorOccurred) {
			try {
				if (jSON != null) {
					JSONArray zipFiles = jSON.getJSONArray("ZipFiles");
					if (zipFiles.length() > 0) {
						File cacheDir = this.cordova.getActivity().getApplicationContext().getCacheDir();
						int length = zipFiles.length();
						for (int i = 0; i < length; i++) {
							JSONObject currentZip = zipFiles.getJSONObject(i);
							String zipPath = currentZip.get("Name").toString();
							File zipFile = new File(cacheDir, zipPath + ".zip");
							filesToZip(currentZip.getJSONArray("Files"), zipFile);
							uploadEvidenceZip(zipFile);
						}
					}
				}
			} catch (JSONException e) {
				errorOccurred = true;
				currentCallbackContext.error(e.getMessage());
			} catch (OutOfMemoryError e) {
				errorOccurred = true;
				currentCallbackContext.error("Not enough memory to perform this task");
			} catch (Surface.OutOfResourcesException e) {
				errorOccurred = true;
				currentCallbackContext.error("Not enough memory to perform this task");
			}
		}
	}
	private void filesToZip(JSONArray files, File zipFile) {
		if (!errorOccurred) {
			try {
				int length = files.length();
				FileOutputStream dest = new FileOutputStream(zipFile);
				ZipOutputStream out = new ZipOutputStream(new BufferedOutputStream(dest));
				byte data[] = new byte[BUFFER];
				for (int f = 0; f < length; f++) {
					File evidenceFile = new File(files.getJSONObject(f).get("FullPath").toString());
					FileInputStream evidenceStream = new FileInputStream(evidenceFile);
					BufferedInputStream origin = new BufferedInputStream(evidenceStream, BUFFER);
					ZipEntry entry = new ZipEntry(evidenceFile.getAbsolutePath().substring(evidenceFile.getAbsolutePath().indexOf("/files/") + 7));
					out.putNextEntry(entry);
					int count;
					while ((count = origin.read(data, 0, BUFFER)) != -1) {
						out.write(data, 0, count);
					}
					origin.close();
				}
				out.close();
				dest.close();
			} catch (JSONException e) {
				errorOccurred = true;
				currentCallbackContext.error(e.getMessage());
			} catch (FileNotFoundException e) {
				errorOccurred = true;
				currentCallbackContext.error(e.getMessage());
			} catch (IOException e) {
				errorOccurred = true;
				currentCallbackContext.error(e.getMessage());
			}
		}
	}

	public void deleteTempLogFile() {
		try {
			String dataPath = cordova.getActivity().getApplicationContext().getFilesDir().getPath();
			File logFile = new File(dataPath);
			File tempZipFile = new File(logFile, EVIDENCE_LOG_FILENAME);
			if (tempZipFile.exists()) {
				boolean result = tempZipFile.delete();
			}
		} catch (SecurityException e) {
			errorOccurred = true;
			currentCallbackContext.error(e.getMessage());
		}
	}

	private int startRecovery(JSONObject jSON) {
		if (!errorOccurred) {
			HttpURLConnection client = null;
			String jSONString = jSON.toString();
			String SessionTokenString = sessionToken.toString();
			try {
				URL url = new URL(startEndpoint);
				client = (HttpURLConnection) url.openConnection();
				client.setDoOutput(true);
				client.setDoInput(true);
				client.setRequestMethod("POST");
				client.setRequestProperty("Content-Type", "application/json; charset=UTF-8");
				client.setRequestProperty("Accept", "application/json");
				client.setRequestProperty("X-SessionID", SessionTokenString);
				client.setUseCaches(false);

				DataOutputStream os = new DataOutputStream(client.getOutputStream());
				os.write(jSONString.getBytes("UTF-8"));
				os.flush();
				os.close();

				int responseCode = client.getResponseCode();
				switch (responseCode) {
					case 200:
					case 201:
						BufferedReader bufferedReader = new BufferedReader(new InputStreamReader(client.getInputStream()));
						StringBuilder sb = new StringBuilder();
						String line;
						while ((line = bufferedReader.readLine()) != null) {
							sb.append(line + "\n");
						}
						bufferedReader.close();
						sessionGUID = sb.toString();
				}
				return responseCode;
			} catch (MalformedURLException e) {
				errorOccurred = true;
				currentCallbackContext.error(e.getMessage());
			} catch (IOException e) {
				errorOccurred = true;
				currentCallbackContext.error(e.getMessage());
			} catch (Exception e) {
				errorOccurred = true;
				currentCallbackContext.error(e.getMessage());
			} catch (OutOfMemoryError e) {
				errorOccurred = true;
				currentCallbackContext.error(eNOT_ENOUGH_MEMORY);
			} finally {
				if (client != null) {
					try {
						client.disconnect();
					} catch (Exception e) {
						errorOccurred = true;
						currentCallbackContext.error(e.getMessage());
					}
				}
			}
		}
		return 0;
	}

	private void uploadEvidenceZip(File zipFile) {
		if (!errorOccurred) {
			try {
				String url = uploadEndpoint + "/" + sessionGUID;
				HashMap<String, String> headers = new HashMap<String, String>();
				headers.put("X-SessionID", sessionToken);
				uk.co.onefile.nomadionic.support.MultipartUtility multipart = new uk.co.onefile.nomadionic.support.MultipartUtility(url, "UTF-8", headers);
				multipart.addFilePart("File", zipFile);
				List<String> finish = multipart.finish();
			} catch (IOException e) {
				errorOccurred = true;
				currentCallbackContext.error(e.getMessage());
			} catch (OutOfMemoryError e) {
				errorOccurred = true;
				currentCallbackContext.error(eNOT_ENOUGH_MEMORY);
			} catch (Surface.OutOfResourcesException e) {
				errorOccurred = true;
				currentCallbackContext.error(eNOT_ENOUGH_RESOURCES);
			} finally {
				if (zipFile.exists()) {
					zipFile.delete();
				}
			}
		}
	}

	private long getFreeMemory() {
		ActivityManager activityManager = (ActivityManager) cordova.getActivity().getApplicationContext().getSystemService(ACTIVITY_SERVICE);
		MemoryInfo memoryInfo = new ActivityManager.MemoryInfo();
		activityManager.getMemoryInfo(memoryInfo);
		Log.i("OnefileSupport", "memoryInfo.availMem " + memoryInfo.availMem + "\n" );
		Log.i("OnefileSupport", "memoryInfo.lowMemory " + memoryInfo.lowMemory + "\n" );
		Log.i("OnefileSupport", "memoryInfo.threshold " + memoryInfo.threshold + "\n" );

		final Runtime runtime = Runtime.getRuntime();
		final long usedMemInB=(runtime.totalMemory() - runtime.freeMemory());
		final long maxHeapSizeInB=runtime.maxMemory();
		final long availHeapSizeInMB = maxHeapSizeInB - usedMemInB;
		Log.i("OnefileSupport", "availableHeapSize:" + String.valueOf(availHeapSizeInMB));
		return availHeapSizeInMB;
	}
}
