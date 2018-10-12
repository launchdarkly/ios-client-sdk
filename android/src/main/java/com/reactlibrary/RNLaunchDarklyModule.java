
package com.reactlibrary;

import android.app.Application;
import android.util.Log;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.Callback;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.modules.core.DeviceEventManagerModule;
import com.launchdarkly.android.FeatureFlagChangeListener;
import com.launchdarkly.android.LDClient;
import com.launchdarkly.android.LDConfig;
import com.launchdarkly.android.LDUser;
import com.launchdarkly.android.LaunchDarklyException;

import java.util.Collections;

public class RNLaunchDarklyModule extends ReactContextBaseJavaModule {

  private LDClient ldClient;
  private LDUser user;

  public RNLaunchDarklyModule(ReactApplicationContext reactContext) {
    super(reactContext);
  }

  @Override
  public String getName() {
    return "RNLaunchDarkly";
  }

  @ReactMethod
  public void configure(String apiKey, ReadableMap options) {
    LDConfig ldConfig = new LDConfig.Builder()
            .setMobileKey(apiKey)
            .build();

    LDUser.Builder userBuilder = new LDUser.Builder(options.getString("key"));

    if (options.hasKey("email")) {
      userBuilder = userBuilder.email(options.getString("email"));
    }

    if (options.hasKey("firstName")) {
      userBuilder = userBuilder.firstName(options.getString("firstName"));
    }

    if (options.hasKey("lastName")) {
      userBuilder = userBuilder.lastName(options.getString("lastName"));
    }

    if (options.hasKey("isAnonymous")) {
      userBuilder = userBuilder.anonymous(options.getBoolean("isAnonymous"));
    }

    if (options.hasKey("organization")) {
      userBuilder = userBuilder.custom("organization", options.getString("organization"));
    }

    if (user != null && ldClient != null) {
      user = userBuilder.build();
      ldClient.identify(user);

      return;
    }

    user = userBuilder.build();

    Activity currentActivity = getCurrentActivity();
    if (currentActivity == null) {
      Log.d("RNLaunchDarklyModule", "Couldn't init RNLaunchDarklyModule - currentActivity was null");
      return;
    }

    Application application = currentActivity.getApplication();

    if (application != null) {
      ldClient = LDClient.init(application, ldConfig, user, 5);
    } else {
      Log.d("RNLaunchDarklyModule", "Couldn't init RNLaunchDarklyModule cause application was null");
    }
  }

  @ReactMethod
  public void addFeatureFlagChangeListener (String flagName) {
    FeatureFlagChangeListener listener = new FeatureFlagChangeListener() {
      @Override
      public void onFeatureFlagChange(String flagKey) {
        WritableMap result = Arguments.createMap();
        result.putString("flagName", flagKey);

        getReactApplicationContext()
                .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
                .emit("FeatureFlagChanged", result);
      }
    };

    try {
      LDClient.get().registerFeatureFlagListener(flagName, listener);
    } catch (LaunchDarklyException e) {
      Log.d("RNLaunchDarklyModule", e.getMessage());
      e.printStackTrace();
    }
  }

  @ReactMethod
  public void boolVariation(String flagName, Callback callback) {
    Boolean variationResult = ldClient.boolVariation(flagName, false);
    callback.invoke(variationResult);
  }

  @ReactMethod
  public void stringVariation(String flagName, String fallback, Callback callback) {
    String variationResult = ldClient.stringVariation(flagName, fallback);
    callback.invoke(variationResult);
  }
}
