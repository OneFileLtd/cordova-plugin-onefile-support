package uk.co.onefile.nomadionic.support;

import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CordovaInterface;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;
import android.util.Log;

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
			if (args.length() != 3) {
				callbackContext.error("Expected 3 arguments");
			}
			this.uploadSupport(args.getString(0), args.getString(1), args.getString(2), callbackContext);
			return true;
		}
		return false;
	}
	
	private void uploadSupport(String ticketDescription, String ticketNumber, String contactDetails, CallbackContext callbackContext) {
		JSONObject retObj = new JSONObject();
		try {
			retObj.put("ticketDescription", ticketDescription);
			retObj.put("ticketNumber", ticketNumber);
			retObj.put("contactDetails", contactDetails);
			callbackContext.success(retObj);
		} catch (JSONException e) {
			callbackContext.error("error");
		} 
	}
}