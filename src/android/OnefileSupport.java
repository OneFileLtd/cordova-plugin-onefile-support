package uk.co.onefile.nomadionic.support;

import android.os.Build;
import android.util.Log;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaInterface;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CordovaWebView;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.IOException;
import java.util.HashMap;

public class OnefileSupport extends CordovaPlugin {
	
	@Override
	public void initialize(CordovaInterface cordova, CordovaWebView webView) {
		super.initialize(cordova, webView);
		// your init code here
	}
	
	@Override
	public boolean execute(String action, JSONArray args, CallbackContext callbackContext) throws JSONException {
		Log.i("OneFileSupportPlugin", "Im in here!");
		if (action.equals("onefileSupport")) {
			JSONObject config = args.getJSONObject(0);
			uploadSupport(config, callbackContext);
			return true;
		}
		return false;
	}
	
	private void uploadSupport(JSONObject config, CallbackContext callbackContext) {
		try {
			String ticketDescription = config.getString("ticketDescription");
			String ticketNumber = "";
			if(!config.isNull("ticketNumber")) {
				ticketNumber = config.getString("ticketNumber");
			}
			String contactDetails = config.getString("contactDetails");
			JSONArray files = config.getJSONArray("files");
			String sessionToken = config.getString("sessionToken");
			String endpoint = config.getString("endpoint");
			String device = config.getString("device");
			HashMap<String, String> headers = new HashMap<String, String>();
			headers.put("X-SessionID", sessionToken);
			
			MultipartUtility multipart = new MultipartUtility(endpoint, "UTF-8", headers);

			device += "\nDevice: " + Build.DEVICE;
			device += "\nManufacturer: " + Build.MANUFACTURER;
			device += "\nModel: " + Build.MODEL;
			device += "\nAndroid OS Version: " + Build.VERSION.RELEASE + ", Codename: " + Build.VERSION.CODENAME;

			multipart.addFormField("Device", device);
			multipart.addFormField("TicketDescription", ticketDescription);
			multipart.addFormField("TicketID", ticketNumber);
			multipart.addFormField("ContactDetails", contactDetails);
			multipart.addFilePart("File", this.cordova.getActivity().getDatabasePath(files.getString(0)));

			multipart.finish();
			callbackContext.success("success");

		} catch (JSONException e) {
			callbackContext.error(e.getMessage());
		} catch (IOException e) {
			callbackContext.error(e.getMessage());
		}
	}
}