#pragma once

#include "ofMain.h"
#include "ofxTouchGUI.h"
#include "ofxBLEHeartRate.h"

#define _VER 0.2

class ofApp : public ofBaseApp{

	public:
		void setup();
		void update();
		void draw();
        void exit();

		void keyPressed(int key);
		void keyReleased(int key);
		void mouseMoved(int x, int y );
		void mouseDragged(int x, int y, int button);
		void mousePressed(int x, int y, int button);
		void mouseReleased(int x, int y, int button);
		void windowResized(int w, int h);
		void dragEvent(ofDragInfo dragInfo);
		void gotMessage(ofMessage msg);
    
    // gui
    void setupGUI();
    ofxTouchGUI settings;
    void onGUIChanged(ofxTouchGUIEventArgs& args);
    ofxTouchGUIDataGraph* bpmGraph;
    ofxTouchGUIText* deviceLabel;
    ofxTouchGUIDropDown* devicesList;
    ofxTouchGUIText* statusLabel;
    
    // osc
    string host;
    int port;
    
    // device
    ofxBLEHeartRate bleHeartRate;
    //ofxBLEHeartRateDelegate* bleHeartRate;//Delegate
    void onScanEvent(ofxBLEHeartRateEventArgs& args);
    void onStatusEvent(ofxBLEHeartRateEventArgs& args);
    void onHRMEvent(ofxBLEHeartRateEventArgs& args);
    void onConnectEvent(ofxBLEHeartRateEventArgs& args);
    void onDisconnectEvent(ofxBLEHeartRateEventArgs& args);
    
    string deviceName;
    vector<string> devices;
    vector<string> devicesIds;
    string statusMessages;
    int selectedDeviceIndex;// = 1;
    int heartRate;
    int rssi;
		
};
