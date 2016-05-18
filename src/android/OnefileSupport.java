package uk.co.onefile.nomadionic.support;

import android.util.Log;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaInterface;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CordovaWebView;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.IOException;

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
			String ticketNumber = config.getString("ticketNumber");
			String contactDetails = config.getString("contactDetails");
			JSONArray files = config.getJSONArray("files");
			String sessionToken = config.getString("sessionToken");
			String endpoint = config.getString("endpoint");
			
			
			MultipartUtility multipart = new MultipartUtility(endpoint, "UTF-8");

			multipart.addFormField("TicketDescription", ticketDescription);
			multipart.addFormField("TicketNumber", ticketNumber);
			multipart.addFormField("ContactDetails", contactDetails);
			multipart.addFormField("TicketDescription", ticketDescription);
			multipart.addHeaderField("X-SessionID", sessionToken);

			multipart.addFilePart("File", this.cordova.getActivity().getDatabasePath(files.getString(0)));

			multipart.finish();
			callbackContext.success("success");

		} catch (JSONException e) {
			callbackContext.error("error");
		} catch (IOException e) {
			callbackContext.error("error");
		}
	}
}