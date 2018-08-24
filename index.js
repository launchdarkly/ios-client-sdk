import {
  Platform,
  NativeModules,
  NativeEventEmitter,
} from 'react-native';

const { RNLaunchDarkly } = NativeModules;

class LaunchDarkly {
  constructor () {
    this.emitter = new NativeEventEmitter(RNLaunchDarkly);
    this.listeners = {};
  }

  configure (apiKey, options) {
    RNLaunchDarkly.configure(apiKey, options);
  }

  boolVariation (featureName, callback) {
    RNLaunchDarkly.boolVariation(featureName, callback);
  }

  stringVariation (featureName, fallback, callback) {
    RNLaunchDarkly.stringVariation(featureName, fallback, callback);
  }

  addFeatureFlagChangeListener (featureName, callback) {
    if (Platform.OS === 'android') {
      RNLaunchDarkly.addFeatureFlagChangeListener(featureName);
    }

    if (this.listeners[featureName]) {
      return;
    }

    this.listeners[featureName] = this.emitter.addListener(
      'FeatureFlagChanged',
      ({ flagName }) => {
        if (flagName === featureName) {
          callback(flagName);
        }
      },
    );
  }

  unsubscribe () {
    Object.keys(this.listeners).forEach((featureName) => {
      this.listeners[featureName].remove();
    });

    this.listeners = {};
  }
}

export default new LaunchDarkly();
