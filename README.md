## About ##

HeartRateOSC connects to Bluetooth Low Energy Heart Rate Monitor devices. Data from the device is converted to OSC messages. Project was commisioned by George Khut (http://georgekhut.com), who kindly allowed this to be released Open Source. 

It's been tested with the Mio Alpha 2, and Mio Link. But should work with any compatible HRM device as long as it conforms to the Heart Rate Profile specified in Bluetooth Developer Portal- https://developer.bluetooth.org/TechnologyOverview/Pages/HRP.aspx. Note this application is OSX only. Exported app in /Application_osx folder.

## Instructions ##
- Activate your device
- App will automatically connect to the first item it discovers (can take a minute or 2 to connect)
- App will list all HRM devices it discovers in the dropdown (to change current device just select from list)

## OSC messages ##
    Address: "/hrm"
    Arg[0]: Peripheral id (string)
    Arg[1]: Peripheral name (string)
    Arg[2]: Heart rate value bpm (int)
    Arg[3]: RSSI / Bluetooth strength (int)

## Openframeworks addons ##
* 	ofxXmlSettings & ofxOsc (core addons)
*	ofxTouchGUI (https://github.com/trentbrooks/ofxTouchGUI)
