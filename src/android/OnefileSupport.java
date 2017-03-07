package uk.co.onefile.nomadionic.support;

import android.content.Context;
import android.os.Build;
import android.util.Log;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaInterface;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CordovaWebView;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.BufferedInputStream;
import java.io.BufferedOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.util.HashMap;
import java.util.List;
import java.util.zip.ZipEntry;
import java.util.zip.ZipOutputStream;

public class OnefileSupport extends CordovaPlugin {
	private static final int BUFFER = 2048;

	private static final int STATUS_ERROR = 0;
	private static final int STATUS_SUCCESSFUL = 1;

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
		try {
			Log.i("OneFileSupportPlugin - Recovery", config.toString(2));
			JSONObject result = new JSONObject();
			result.put("status", STATUS_SUCCESSFUL);
			callbackContext.success(result);
		} catch (JSONException e) {
			callbackContext.error(e.getMessage());
		} finally {
		}
	}

	private void uploadSupport(JSONObject config, CallbackContext callbackContext) {
		File zipFile = null;
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

			MultipartUtility multipart = new MultipartUtility(endpoint, "UTF-8", headers);

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
}