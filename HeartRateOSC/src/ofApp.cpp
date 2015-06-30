#include "ofApp.h"

void ofApp::exit() {
    ofLog() << "exited";
}

//--------------------------------------------------------------
void ofApp::setup(){

    ofSetFrameRate(30);
    ofEnableAlphaBlending();
    ofBackground(143,183,187);
    
    ofLogToFile("log.txt");
    
    bleHeartRate.setup();
    ofAddListener(bleHeartRate.hrmEvent, this, &ofApp::onHRMEvent);
    ofAddListener(bleHeartRate.scanEvent, this, &ofApp::onScanEvent);
    ofAddListener(bleHeartRate.statusEvent, this, &ofApp::onStatusEvent);
    ofAddListener(bleHeartRate.connectEvent, this, &ofApp::onConnectEvent);
    ofAddListener(bleHeartRate.disconnectEvent, this, &ofApp::onDisconnectEvent);
    
    deviceName = "";
    heartRate = 0;
    rssi = 0;
    statusMessages = "Scanning...";
    
    // osc settings
    host = "127.0.0.1"; // change via xml
    port = 7761; // change via xml
    
    setupGUI();
}



void ofApp::setupGUI() {
    
    settings.loadSettings("settings.xml", false, true);
    settings.loadFonts("fonts/stan0755.ttf", "fonts/abel.ttf", 6, 20);
    
    settings.setConstant("host", &host);
    settings.setConstant("port", &port);
    
    settings.setupSendOSC(host, port);
    
    
    int smallHeight = 20;
    int bigHeight = 35;
    int bigWidth = 512 - 40;
    int smallWidth = 200;
    
    // add items
    settings.setItemSize(bigWidth, bigHeight);
    settings.addTitleText("HEARTRATE OSC " + ofToString(_VER), 18, 18);
    deviceLabel = settings.addText("Device - " + deviceName, 20, 65);
    settings.addText("OSC - " + host + ":" + ofToString(port), 20, 85);
    
    settings.addText("---------------------------------------------------------------------------------------------", 20, 100);
    //settings.addButton("SCAN", 25, 125, 230);
    //settings.addButton("CONNECT", 260, 125, 230);
    //string ddOptions[] = {"Oranges", "Bananas", "Apples", "Kiwis", "Mangoes"};
    //devices.insert(devices.begin(), &ddOptions[0], &ddOptions[4]);
    devices.clear();
    selectedDeviceIndex = -1;
    devicesList = settings.addDropDown("DEVICES LIST", 0, &selectedDeviceIndex, devices, 25, 125, 464);
    devicesList->resetDefaultValue();
    settings.addText("---------------------------------------------------------------------------------------------", 20, 165);
    
    int graphWidth = 470-6;
    int graphHeight = 200;
    int graphItemHeight = graphHeight + 25;
    int graphOffsetX = 20+6;
    int graphOffsetY = 210;//240;//120;
    int valuesToSave = 512;//graphWidth; // 1 for each pixel
    bpmGraph = settings.addDataGraph("HEART RATE (BPM) 0-200", valuesToSave, graphOffsetX, graphOffsetY, graphWidth, graphHeight);
    bpmGraph->setBackgroundClrs(ofColor(255,90));
    bpmGraph->setTextOffsets(0, -5);
    bpmGraph->setOSCAddress("/hr");
    bpmGraph->setCustomRange(0, 200);
    
    settings.addVarText("RSSI", &rssi, 20, 420);
    settings.addText("---------------------------------------------------------------------------------------------", 20, 440);
    statusLabel = settings.addText(statusMessages, 20, 460);
    
    settings.addEventListenerAllItems(this);
}

void ofApp::onGUIChanged(ofxTouchGUIEventArgs& args) {
    string buttonLabel = args.target->getLabel();
    ofLog() << buttonLabel;
    // or just use the label as the identifier
    if(buttonLabel == "SAVE") {
        settings.saveSettings();
    }
    else if(buttonLabel == "RESET") {
        settings.resetDefaultValues();
    }
    else if(ofIsStringInString(buttonLabel, "DEVICES LIST")) {
        
        ofLog() << "Connect to: " << devicesIds[selectedDeviceIndex];
        deviceLabel->setDisplay("Device - " + devices[selectedDeviceIndex], deviceLabel->getItemPosX(), deviceLabel->getItemPosY(), deviceLabel->getItemWidth());// = settings.addText("Device - " + deviceName, 20, 65);
        
        statusMessages = "Connecting...";
        
        // connect to device?
        bleHeartRate.connectDevice(devicesIds[selectedDeviceIndex]);//args.peripheralId);
        
        // disconnect current hrm, then connect to selected
        
    }
}


//--------------------------------------------------------------
void ofApp::onHRMEvent(ofxBLEHeartRateEventArgs& args) {
    
    //bpmGraph->insertValue(heartRate);
    //ofLog() << "hrm data: " << args.data << ", " << args.rssi << ", " << args.peripheralName;
    
    rssi = args.rssi;
    this->heartRate = args.data;
    ofxOscMessage msg;
    msg.setAddress("/hrm");
    msg.addStringArg(args.peripheralId);
    msg.addStringArg(args.peripheralName);
    msg.addIntArg(args.data);
    msg.addIntArg(args.rssi);
    //settings.sendOSC("/hr", heartRate);
    //settings.sendOSC("/rssi", rssi);
    settings.sendOSC(msg);
}

void ofApp::onScanEvent(ofxBLEHeartRateEventArgs& args) {
    
    //ofLog() << "name: " << args.peripheralName;
    //ofLog() << "rssi: " << args.rssi;
    
    deviceName = args.peripheralName + " (" + args.peripheralId + ")";
    //deviceLabel->setDisplay("Device - " + deviceName, deviceLabel->getItemPosX(), deviceLabel->getItemPosY(), deviceLabel->getItemWidth());
    
    rssi = args.rssi;
    
    devices.push_back(deviceName);
    devicesIds.push_back(args.peripheralId);
    devicesList->setDisplay("DEVICES LIST ("+ofToString(devices.size())+")", devicesList->getItemPosX(), devicesList->getItemPosY(), devicesList->getItemWidth());
    devicesList->setValues(devices.size(), devices, &selectedDeviceIndex);
    
    deviceLabel->setDisplay("Device - " + deviceName, deviceLabel->getItemPosX(), deviceLabel->getItemPosY(), deviceLabel->getItemWidth());// = settings.addText("Device - " + deviceName, 20, 65);
    
    // connect to device?
    if(selectedDeviceIndex == -1) {
        selectedDeviceIndex = 0;
        bleHeartRate.connectDevice(args.peripheralId);
    }
    
    
}

void ofApp::onConnectEvent(ofxBLEHeartRateEventArgs& args) {
    
    deviceName = args.peripheralName + " (" + args.peripheralId + ")";
    deviceLabel->setDisplay("Device - " + deviceName, deviceLabel->getItemPosX(), deviceLabel->getItemPosY(), deviceLabel->getItemWidth());
    
}

void ofApp::onDisconnectEvent(ofxBLEHeartRateEventArgs& args) {
    
    deviceName = "";
    deviceLabel->setDisplay("Device - " + deviceName, deviceLabel->getItemPosX(), deviceLabel->getItemPosY(), deviceLabel->getItemWidth());
}


void ofApp::onStatusEvent(ofxBLEHeartRateEventArgs& args) {
    
    statusMessages = statusMessages + "\n" + args.status + " (" + args.peripheralId + ")";
    /*if(args.status == "Retrieved device") {
        statusMessages = statusMessages + "\nConnecting...";
    }*/
    statusLabel->setDisplay(statusMessages, statusLabel->getItemPosX(), statusLabel->getItemPosY(), statusLabel->getItemWidth());
}
//--------------------------------------------------------------
void ofApp::update(){

    bpmGraph->insertValue(heartRate);
}

//--------------------------------------------------------------
void ofApp::draw(){

    settings.draw();
}

//--------------------------------------------------------------
void ofApp::keyPressed(int key){

}

//--------------------------------------------------------------
void ofApp::keyReleased(int key){

}

//--------------------------------------------------------------
void ofApp::mouseMoved(int x, int y ){

}

//--------------------------------------------------------------
void ofApp::mouseDragged(int x, int y, int button){

}

//--------------------------------------------------------------
void ofApp::mousePressed(int x, int y, int button){

}

//--------------------------------------------------------------
void ofApp::mouseReleased(int x, int y, int button){

}

//--------------------------------------------------------------
void ofApp::windowResized(int w, int h){

}

//--------------------------------------------------------------
void ofApp::gotMessage(ofMessage msg){

}

//--------------------------------------------------------------
void ofApp::dragEvent(ofDragInfo dragInfo){ 

}
