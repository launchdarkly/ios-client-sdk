
# launch-darkly-react-native

React Native wrapper over LaunchDarkly SDK's for iOS and Android.

[LaunchDarkly](https://launchdarkly.com)

[Native iOS SDK](https://github.com/launchdarkly/ios-client)

[Native Android SDK](https://github.com/launchdarkly/android-client)

## Getting started

`$ npm install launch-darkly-react-native --save`

or

``$ yarn add launch-darkly-react-native --save``

#### iOS:

Add the following line to your podfile:
```
pod 'LaunchDarkly'
pod 'launch-darkly-react-native', path: '../node_modules/launch-darkly-react-native'
```
and run
```
pod install
```

#### Android:

See manual directions.

### Manual installation


#### iOS

1. In XCode, in the project navigator, right click `Libraries` ➜ `Add Files to [your project's name]`
2. Go to `node_modules` ➜ `launch-darkly-react-native` and add `RNLaunchDarkly.xcodeproj`
3. In XCode, in the project navigator, select your project. Add `libRNLaunchDarkly.a` to your project's `Build Phases` ➜ `Link Binary With Libraries`

#### Android

1. Open up `android/app/src/main/java/[...]/MainActivity.java`
  - Add `import com.reactlibrary.RNLaunchDarklyPackage;` to the imports at the top of the file
  - Add `new RNLaunchDarklyPackage()` to the list returned by the `getPackages()` method
2. Append the following lines to `android/settings.gradle`:
  	```
  	include ':launch-darkly-react-native'
  	project(':launch-darkly-react-native').projectDir = new File(rootProject.projectDir, 	'../node_modules/launch-darkly-react-native/android')
  	```
3. Insert the following lines inside the dependencies block in `android/app/build.gradle`:
  	```
      compile project(':launch-darkly-react-native')
  	```


## Usage
```javascript
import LaunchDarkly from 'launch-darkly-react-native';

const user = {
  key: 'key',
  email: 'email@example.com', // optional
  firstName: 'firstname', // optional
  lastName: 'lastname', // optional
  isAnonymous: false, // optional
};

// init native SDK with api key and user object
LaunchDarkly.configure('apiKey', user);

// get boolean feature flag value
LaunchDarkly.boolVariation('featureFlagName', (showFeature) => {
  console.log('Show feature:', showFeature);
});

// get string feature flag value
LaunchDarkly.stringVariation('featureFlagName', 'fallback', (value) => {
  console.log('String value:', value);
});

// adds listener which is called every time given feature flag value is changed
// callback is called with flagName string, so you will have to call LaunchDarkly.boolVariation()
// to get new feature flag value
LaunchDarkly.addFeatureFlagChangeListener('flagName', () => {
  console.log('callback');
});

// removes all onFeatureFlagChange listeners
LaunchDarkly.unsubscribe();
```
