package uk.co.onefile.nomadionic.support;

import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CallbackContext;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

public class OnefileSupport extends CordovaPlugin {
	@Override
	
	public boolean execute(String action, JSONArray args, CallbackContext callbackContext) throws JSONException {
		if (action.equals("SupportUpload")) {
			if (args.length != 3) {
				callbackContext.error("Expected 3 arguments")
			}
			this.uploadSupport(args.getString(0), args.getString(1), args.getString(2), callbackContext);
			return true;
		}
		return false;
	}
	
	private void uploadSupport(String ticketDescription, String ticketNumber, String contactDetails, CallbackContext callbackContext) {
		JSONObject retObj = new JSONObject();
		retObj.put("ticketDescription", ticketDescription);
		retObj.put("ticketNumber", ticketNumber);
		retObj.put("contactDetails", contactDetails);
		callbackContext.success(retObj);
		
	}
}