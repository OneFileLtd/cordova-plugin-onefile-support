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
import java.net.HttpURLConnection;
import java.net.MalformedURLException;
import java.net.URL;
import java.util.ArrayList;

import java.util.HashMap;
import java.util.List;
import java.util.zip.ZipEntry;
import java.util.zip.ZipOutputStream;

import static android.view.View.X;

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

	private String sessionToken;
	private String sessionGUID;
	private String startEndpoint;
	private String uploadEndpoint;
	private String ticketNumber;

	@Override
	public void initialize(CordovaInterface cordova, CordovaWebView webView) {
		super.initialize(cordova, webView);
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
		try {
			Log.i("OneFileSupportPlugin", config.toString(2));
			sessionToken = config.getString("sessionToken");
			startEndpoint = config.getString("endpoint");
			uploadEndpoint = config.getString("endpoint");
			ticketNumber = config.getString("ticketNumber");
			String serverPath = config.getString("selectedServer");
			if(serverPath != null) {
				rootPath = cordova.getActivity().getApplicationContext().getFilesDir().getPath() + "/" + serverPath;
				JSONObject jSONData = createEvidenceLog();
				createLogFile(jSONData);
				startRecovery(jSONData);
				zipFilesFromEvidenceLog(jSONData);
				deleteTempLogFile();
				JSONObject result = new JSONObject();
				result.put("status", STATUS_SUCCESSFUL);
				callbackContext.success(result);
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
				inFiles.add(file);
			}
		}
		return inFiles;
	}

	public void createLogFile(JSONObject jSON) {
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
				logFile.put("ExcludedFiles", excluded);
				logFile.put("TicketID", ticketNumber);
				return logFile;
			}
			return null;
		}
		catch (JSONException e) {
			e.printStackTrace();
			currentCallbackContext.error(e.getMessage());
		};
		return null;
	}

	public void zipFilesFromEvidenceLog(JSONObject jSON) {
		try {
			if(jSON != null) {
				JSONArray zipFiles = jSON.getJSONArray("ZipFiles");
				if (zipFiles.length() > 0) {
					BufferedInputStream origin = null;
					for (int i = 0; i < zipFiles.length(); i++) {
						JSONObject currentZip = zipFiles.getJSONObject(i);
						String zipPath = currentZip.get("Name").toString();
						File zipFile = new File(TEST_DIRECTORY, zipPath + ".zip");
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
							ZipEntry entry = new ZipEntry(evidenceFile.getAbsolutePath().substring(position));
							out.putNextEntry(entry);
							int count;
							while ((count = origin.read(data, 0, BUFFER)) != -1) {
								out.write(data, 0, count);
							}
							origin.close();
						}
						out.close();
						uploadEvidenceZip(zipFile);
					}
				}
			}
		}
		catch (JSONException e) {
			e.printStackTrace();
			currentCallbackContext.error(e.getMessage());
		}
		catch (FileNotFoundException e) {
			e.printStackTrace();
			currentCallbackContext.error(e.getMessage());
		}
		catch (IOException e) {
			e.printStackTrace();
			currentCallbackContext.error(e.getMessage());
		};
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
			e.printStackTrace();
			currentCallbackContext.error(e.getMessage());
		}
	}

	private void startRecovery(JSONObject jSON) {
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
		} catch (MalformedURLException e) {
			e.printStackTrace();
			currentCallbackContext.error(e.getMessage());
		} catch (IOException e) {
			e.printStackTrace();
			currentCallbackContext.error(e.getMessage());
		} catch (Exception e) {
			e.printStackTrace();
			currentCallbackContext.error(e.getMessage());
		}
		finally {
			if(client != null) {
				try {
					client.disconnect();
				} catch (Exception e) {
					e.printStackTrace();
					currentCallbackContext.error(e.getMessage());
				}
			}
		}
	}

	private void uploadEvidenceZip(File zipFile) {
		try {
			String url = uploadEndpoint + "/" + sessionGUID;
			HashMap<String, String> headers = new HashMap<String, String>();
			headers.put("X-SessionID", sessionToken);
			uk.co.onefile.nomadionic.support.MultipartUtility multipart = new uk.co.onefile.nomadionic.support.MultipartUtility(url, "UTF-8", headers);
			multipart.addFilePart("File", zipFile);
			List<String> finish = multipart.finish();
		} catch (IOException e) {
			e.printStackTrace();
			currentCallbackContext.error(e.getMessage());
		}
		finally {
			if (zipFile != null) {
				zipFile.delete();
			}
		}
	}
}