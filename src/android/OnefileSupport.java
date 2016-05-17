package uk.co.onefile.nomadionic.support;

import org.apache.cordova.CordovaWebView;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaInterface;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;
import android.util.Log;

import java.net.HttpURLConnection;

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
			String ticketDescription = config.getString("ticketDescription");
			String ticketNumber = config.getString("ticketNumber");
			String contactDetails = config.getString("contactDetails");
			JSONArray files = config.getJSONArray("files");
			String sessionToken = config.getString("sessionToken");
			String endpoint = config.getString("endpoint");
			callbackContext.success(config);
			//this.uploadSupport(args.getString(0), args.getString(1), args.getString(2), callbackContext);
			return true;
		}
		return false;
	}
	
	private void uploadSupport(String requestURL, , CallbackContext callbackContext) {
		JSONObject retObj = new JSONObject();
		try {
			retObj.put("ticketDescription", ticketDescription);
			retObj.put("ticketNumber", ticketNumber);
			retObj.put("contactDetails", contactDetails);
			callbackContext.success(retObj);
			
			
			/*MultipartUtility multipart = new MultipartUtility(requestURL, "UTF-8");

			for (int i = 0; i < myFormDataArray.size(); i++) {
				multipart.addFormField(myFormDataArray.get(i).getParamName(),
						myFormDataArray.get(i).getParamValue());
			}

			
			for (int i = 0; i < myFileArray.size(); i++) {
				multipart.addFilePart(myFileArray.getParamName(),
						new File(myFileArray.getFileName()));
			}

			List<String> response = multipart.finish();
			Debug.e(TAG, "SERVER REPLIED:");
			for (String line : response) {
				responseString = line;
			}*/
			
		} catch (JSONException e) {
			callbackContext.error("error");
		} 
	}
}