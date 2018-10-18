#pragma once

#include "ofMain.h"
#import <IOBluetooth/IOBluetooth.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import <Foundation/Foundation.h>

/*
 ofxBLEHeartRate.
 - connect to ble heart rate monitor that conforms to the bluetooth heart rate profile
 - https://developer.bluetooth.org/TechnologyOverview/Pages/HRP.aspx
 - osx only
 - tested with mio alpha, should work with all devices that conform to protocol
 */

#define PULSESCALE 1.2
#define PULSEDURATION 0.2

class ofxBLEHeartRate;

// OBJC DELEGATE
//--------------------------------------------------------------
@interface ofxBLEHeartRateDelegate : NSObject<CBCentralManagerDelegate, CBPeripheralDelegate>  {
    
    NSTimer *pulseTimer;
    //NSArrayController *arrayController;
    
    CBCentralManager *manager;
    CBPeripheral *peripheral;
    
    NSMutableArray *heartRateMonitors;
    
    NSString *manufacturer;
    
    int heartRate;
    
    BOOL isConnected;
    
    ofxBLEHeartRate* bleHeartRateCpp;
}


@property (assign) BOOL isConnected;
@property (assign) int heartRate;
@property (retain) NSTimer *pulseTimer;
@property (retain) NSMutableArray *heartRateMonitors;
@property (copy) NSString *manufacturer;
//@property (copy) NSString *connected;

- (id) init:(ofxBLEHeartRate *)bleCpp;
- (void) startScan;
- (void) stopScan;
- (void) connectDevice:(NSString*)peripheralId;
- (void) disconnectDevice:(NSString*)peripheralId;
- (BOOL) isLECapableHardware;

- (void) pulse;
- (void) updateWithHRMData:(NSData *)data;

@end



// adding custom event
class ofxBLEHeartRateEventArgs : public ofEventArgs {
public:
    
    ofxBLEHeartRateEventArgs() {};
    ofxBLEHeartRateEventArgs(string pId, string pName, int d, int r, string s) {
        peripheralId = pId;
        peripheralName = pName;
        data = d;
        rssi = r;
        status = s;
    };
    
    int data;
    int rssi;
    string peripheralName;
    string peripheralId;
    string status;
};

class ofxBLEHeartRate {

	public:
        ~ofxBLEHeartRate();
		void setup();
		//void update();
		//void draw();
    
        void startScan();
        void stopScan();
    
        void connectDevice(string peripheralId);
    
    ofEvent<ofxBLEHeartRateEventArgs> hrmEvent;
    ofEvent<ofxBLEHeartRateEventArgs> scanEvent;
    ofEvent<ofxBLEHeartRateEventArgs> statusEvent;
    ofEvent<ofxBLEHeartRateEventArgs> connectEvent;
    ofEvent<ofxBLEHeartRateEventArgs> disconnectEvent;
    
    // callbacks
    //void onPulse(int heartRate);
    
    ofxBLEHeartRateDelegate* bleHeartRateDelegate;
		
};


