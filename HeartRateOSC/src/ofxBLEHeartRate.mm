#include "ofxBLEHeartRate.h"

//--------------------------------------------------------------
void ofxBLEHeartRate::setup(){
    
    // setup delegate + start scanning
    bleHeartRateDelegate = [[ofxBLEHeartRateDelegate alloc] init:this ];
    //startScan();
}

ofxBLEHeartRate::~ofxBLEHeartRate(){
    if(bleHeartRateDelegate) {
        [bleHeartRateDelegate dealloc];
        bleHeartRateDelegate = nil;
    }
    
}

/*void ofxBLEHeartRate::onPulse(int heartRate) {
    
    ofLog() << "Heart rate: " << heartRate;
    ofNotifyEvent(pulseEvent, heartRate, this);
}*/

//--------------------------------------------------------------
void ofxBLEHeartRate::startScan(){
    [bleHeartRateDelegate startScan];
}

void ofxBLEHeartRate::stopScan(){
    [bleHeartRateDelegate stopScan];
}

void ofxBLEHeartRate::connectDevice(string peripheralId) {
    [bleHeartRateDelegate connectDevice:[NSString stringWithUTF8String:peripheralId.c_str()]];
}

/*void ofxBLEHeartRate::update(){

}

//--------------------------------------------------------------
void ofxBLEHeartRate::draw(){

}*/



//--------------------------------------------------------------
@implementation ofxBLEHeartRateDelegate

@synthesize isConnected;
@synthesize isPoweredOn;
@synthesize heartRate;
@synthesize r2r;
@synthesize pulseTimer;
@synthesize heartRateMonitors;
@synthesize manufacturer;
//@synthesize connected;

- (id) init :(ofxBLEHeartRate *)bleCpp {
    if(self = [super init])	{
        //NSLog(@"ofxBLEHeartRate initiated");
        ofLog() << "ofxBLEHeartRate initiated";
        bleHeartRateCpp = bleCpp; // ref to OF instance
        isConnected = FALSE;
        isPoweredOn = FALSE;
        
        self.heartRateMonitors = [NSMutableArray array];
        manager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
        
        //[self startScan];
    }
    return self;
}

- (void) dealloc {
    //NSLog(@"ofxBLEHeartRateDelegate dealloc");
    ofLog() << "ofxBLEHeartRateDelegate dealloc";
    bleHeartRateCpp = nil;
    [self stopScan];
    [manager release];
    manager = nil;
    [super dealloc];
}

#pragma mark - Heart Rate Data

/*
 Update UI with heart rate data received from device
 */
- (void) updateWithHRMData:(NSData *)data
{
    const uint8_t *reportData = (uint8_t*)[data bytes];
    const uint8_t *reportDataEnd = reportData + [data length];
    //const void *reportData = [data bytes];
    uint8_t flags = *reportData++;
    
    uint16_t bpm = 0;
    
//    if ((reportData[0] & 0x01) == 0)
//    {
//        /* uint8 bpm */
//        bpm = reportData[1];
//    }
//    else
//    {
//        /* uint16 bpm */
//        bpm = CFSwapInt16LittleToHost(*(uint16_t *)(&reportData[1]));
//    }
    
    if (flags & 0x01) {
        /* uint16 bpm */
        bpm = CFSwapInt16LittleToHost(*(uint16_t *)reportData);
        
        reportData += 2;
    } else {
        /* uint8 bpm */
        bpm = *reportData++;
    }
    
    NSMutableArray *r2rsMutableArray = [[NSMutableArray alloc] init];
    if (flags & 0x10) {
        // interbeat interval
        int count = 0;
        double totalDuration = 0;
        while (reportData < reportDataEnd) {
            
            double an_r2r = CFSwapInt16LittleToHost(*(uint16_t*) reportData)/1024.0;
            [r2rsMutableArray addObject:[NSNumber numberWithDouble:an_r2r]];
            //            NSString *log = [NSString stringWithFormat:@"ibi is: %f and this is item no. %d",an_r2r, count];
            //            [self sendMessageToUIConsole:log];
            count++;
            totalDuration += an_r2r;
            reportData += 2;
        }
    }
    
    uint16_t oldBpm = self.heartRate;
    self.heartRate = bpm;
    
    if([r2rsMutableArray count] > 0) {
        
        self.r2r = [[r2rsMutableArray objectAtIndex:[r2rsMutableArray count]-1]doubleValue];
        //ofLog() << "R2R: " << self.r2r;
        //        self.r2r = r2rs[r2rs.size() - 1];
        //NSLog(@"r2r beat: %f", self.r2r);
        
        /*NSMutableDictionary* userInfo = [NSMutableDictionary dictionary];
        [userInfo setObject:[NSNumber numberWithFloat:self.r2r] forKey:RR_VALUE];
        [nc postNotificationName:BT_RR_NOTIFICATION object:self userInfo:userInfo];
        */
        
        ofxBLEHeartRateEventArgs args(string([peripheral.identifier.UUIDString UTF8String]), string([peripheral.name UTF8String]), r2r, "R2R");
        ofNotifyEvent(bleHeartRateCpp->r2rEvent, args);
        
    } else if (bpm == 0) {
        self.r2r = 0;
    }
    
    //NSLog(@"Pulse: %d", heartRate );
    if (oldBpm == 0)
    {
        [self pulse];
        //self.pulseTimer = [NSTimer scheduledTimerWithTimeInterval:(60. / heartRate) target:self selector:@selector(pulse) userInfo:nil repeats:NO];
    }
}

/*
 Update pulse UI
 */
- (void) pulse
{
    /*CABasicAnimation *pulseAnimation = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    
    pulseAnimation.toValue = [NSNumber numberWithFloat:PULSESCALE];
    pulseAnimation.fromValue = [NSNumber numberWithFloat:1.0];
    
    pulseAnimation.duration = PULSEDURATION;
    pulseAnimation.repeatCount = 1;
    pulseAnimation.autoreverses = YES;
    pulseAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];
    
    [[heartView layer] addAnimation:pulseAnimation forKey:@"scale"];*/
    
    //NSLog(@"Pulse: %d", heartRate );
    //bleHeartRateCpp->onPulse(heartRate);
    if(peripheral) {
        
        // update the rssi value - not sure if this is required so often?
        // if don't do this, then the rssi is always 0
        [peripheral readRSSI];
        
        ofxBLEHeartRateEventArgs args(string([peripheral.identifier.UUIDString UTF8String]), string([peripheral.name UTF8String]), heartRate, peripheral.RSSI.intValue, "Pulse");
        ofNotifyEvent(bleHeartRateCpp->hrmEvent, args);//, bleHeartRateCpp);
        
    }
    
    
    // IBI: http://www.researchgate.net/post/How_to_measure_the_interbeat_interval_in_human_patients
    self.pulseTimer = [NSTimer scheduledTimerWithTimeInterval:(60. / heartRate) target:self selector:@selector(pulse) userInfo:nil repeats:NO];
}



#pragma mark - Start/Stop Scan methods

/*
 Uses CBCentralManager to check whether the current platform/hardware supports Bluetooth LE. An alert is raised if Bluetooth LE is not enabled or is not supported.
 */
- (BOOL) isLECapableHardware
{
    NSString * state = nil;
    
    
    switch ([manager state])
    {
        case CBCentralManagerStateUnsupported:
            state = @"The platform/hardware doesn't support Bluetooth Low Energy.";
            break;
        case CBCentralManagerStateUnauthorized:
            state = @"The app is not authorized to use Bluetooth Low Energy.";
            break;
        case CBCentralManagerStatePoweredOff:
            state = @"Bluetooth is currently powered off.";
            break;
        case CBCentralManagerStatePoweredOn:
            ofLog() << "ok isLECapableHardware";
            state = @"Bluetooth is currently powered ON.";
            return TRUE;
        case CBCentralManagerStateUnknown:
        default:
            ofLog() << "Unknown state: " << string([state UTF8String]);
            return FALSE;
            
    }
    
    ofLog() << "Central manager state: " << string([state UTF8String]);
    //NSLog(@"Central manager state: %@", state);
    return FALSE;
}

/*
 Request CBCentralManager to scan for heart rate peripherals using service UUID 0x180D
 */
- (void) startScan
{
    //NSLog(@"Begin scanning for BLE peripherals...");
    ofLog() << "Begin scanning for BLE peripherals...";
    if (isPoweredOn) {
        NSArray *serviceTypes = @[[CBUUID UUIDWithString:@"FEE8"], [CBUUID UUIDWithString:@"180D"]];
        [manager scanForPeripheralsWithServices:serviceTypes options:nil];
//        [manager scanForPeripheralsWithServices:[NSArray arrayWithObject:[CBUUID UUIDWithString:@"FEE8"]] options:nil];
    } else {
        ofLog() << "Must wait till centralManagerDidUpdateState callback"; //https://stackoverflow.com/questions/23338767/ios-core-bluetooth-getting-api-misuse-warning
    }
    
}

/*
 Request CBCentralManager to stop scanning for heart rate peripherals
 */
- (void) stopScan
{
    ofLog() << "Stopped scanning for BLE peripherals";
    //NSLog(@"Stopped scanning for BLE peripherals");
    [manager stopScan];
}

- (void) connectDevice:(NSString*)peripheralId {
    
    if(isConnected) {
        [self disconnectDevice:peripheralId];
    }
    
    ofLog() << "CONNECT!";
    for (CBPeripheral *aPeripheral in self.heartRateMonitors) {
        // do something with object
        //NSLog(@"obj %@, ", peripheral.UUID);
        if([[[aPeripheral identifier] UUIDString] isEqualToString:peripheralId]) {
            //[manager retrievePeripherals:[NSArray arrayWithObject:(id)aPeripheral.UUID]];
            ofLog() << "Connecting... to peripheral: " << string([aPeripheral.name UTF8String]);
            isConnected = TRUE;
            [manager connectPeripheral:aPeripheral options:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:CBConnectPeripheralOptionNotifyOnDisconnectionKey]];
            return;
        }
    }
}

- (void) disconnectDevice:(NSString*)peripheralId {
    
    ofLog() << "DISCONNECT!";
    for (CBPeripheral *aPeripheral in self.heartRateMonitors) {
        // do something with object
        //NSLog(@"obj %@, ", peripheral.UUID);
        if([[[aPeripheral identifier] UUIDString] isEqualToString:peripheralId]) {
            ofLog() << "Disconnecting... peripheral: " << string([aPeripheral.name UTF8String]);
            [manager cancelPeripheralConnection:aPeripheral];
            isConnected = FALSE;
            return;
        }
    }
}


#pragma mark - CBCentralManager delegate methods
/*
 Invoked whenever the central manager's state is updated.
 */
- (void) centralManagerDidUpdateState:(CBCentralManager *)central
{
    ofLog() << "centralManagerDidUpdateState";
    if([self isLECapableHardware]) {
        isPoweredOn = TRUE;
        [self startScan];
    } else {
        ofLog() << "Not powered on yet?";
    }
}

/*
 Invoked when the central discovers heart rate peripheral while scanning.
 */
- (void) centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)aPeripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    NSMutableArray *peripherals = [self mutableArrayValueForKey:@"heartRateMonitors"];
    double rssi = [RSSI doubleValue];
    ofLog() << "Found device with rssi " << rssi;
    NSLog(@"Doct %@", advertisementData);
    // https://stackoverflow.com/questions/28280025/core-bluetooth-doesnt-find-peripherals-when-scanning-for-specific-cbuuid
//    2018-11-05 21:27:17.043136+1100 HeartRateOSC[57353:3373245] Doct {
//        kCBAdvDataIsConnectable = 0;
//        kCBAdvDataServiceUUIDs =     (
//                                      "Heart Rate",
//                                      "Device Information",
//                                      Battery,
//                                      FEE8
//                                      );
//    }
    

    if( ![self.heartRateMonitors containsObject:aPeripheral] ) {
        
        
        // new device detected
        if(aPeripheral.name != nil) {
            [peripherals addObject:aPeripheral];
            
            ofxBLEHeartRateEventArgs args(string([aPeripheral.identifier.UUIDString UTF8String]), string([aPeripheral.name UTF8String]), 0, RSSI.intValue, "Discovered device");
            ofNotifyEvent(bleHeartRateCpp->scanEvent, args);//, bleHeartRateCpp);
            ofNotifyEvent(bleHeartRateCpp->statusEvent, args);
        }
        
        
        /* Retreive already known devices */
        //if(autoConnect)
        //{
        //[manager retrievePeripherals:[NSArray arrayWithObject:(id)aPeripheral.UUID]];
        //}
    }
    
}

/*
 Invoked when the central manager retrieves the list of known peripherals.
 Automatically connect to first known peripheral
 */
- (void)centralManager:(CBCentralManager *)central didRetrievePeripherals:(NSArray *)peripherals
{
    //NSLog(@"Retrieved peripheral: %d - %@", [peripherals count], peripherals);
    ofLog() << "Retrieved peripheral:" << [peripherals count];
    
    //[self stopScan];
    
    /* If there are any known devices, automatically connect to it.*/
    if([peripherals count] >=1) {
        
        //[indicatorButton setHidden:FALSE];
        //[progressIndicator setHidden:FALSE];
        //[progressIndicator startAnimation:self];
        //[peripheral retain];
        //[connectButton setTitle:@"Cancel"];
        
        // notify with full list of devices
        for (CBPeripheral *aPeripheral in peripherals) {
            ofxBLEHeartRateEventArgs args(string([aPeripheral.identifier.UUIDString UTF8String]), string([aPeripheral.name UTF8String]), heartRate,aPeripheral.RSSI.intValue, "Retrieved device");
            ofNotifyEvent(bleHeartRateCpp->statusEvent, args);
        }

        
        // if we are not connected at all - auto connect to first itme
        /*if(!isConnected) {
            
            //isConnected = TRUE; // this actually means pending connection
            
            CBPeripheral* firstPeripheral = [peripherals objectAtIndex:0];
            
            //[manager connectPeripheral:firstPeripheral options:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:CBConnectPeripheralOptionNotifyOnDisconnectionKey]];
            
            // connect to this peripheral's id
            [self connectDevice:firstPeripheral.identifier.UUIDString];
        }*/
        
    }
}

/*
 Invoked whenever a connection is succesfully created with the peripheral.
 Discover available services on the peripheral
 */
- (void) centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)aPeripheral
{
    if( peripheral ) {
        [peripheral setDelegate:nil];
        [peripheral release];
        peripheral = nil;
    }
    
    peripheral = aPeripheral;
    [peripheral retain];
    
    [peripheral setDelegate:self];
    [peripheral discoverServices:nil];
    
    //NSLog(@"Connected to peripheral %@", aPeripheral.name);
    ofLog() << "Connected to peripheral: " << string([peripheral.name UTF8String]);
    /*self.connected = @"Connected";
    [connectButton setTitle:@"Disconnect"];
    [indicatorButton setHidden:TRUE];
    [progressIndicator setHidden:TRUE];
    [progressIndicator stopAnimation:self];*/
    
    
    
    ofxBLEHeartRateEventArgs args(string([peripheral.identifier.UUIDString UTF8String]), string([peripheral.name UTF8String]), heartRate,peripheral.RSSI.intValue, "Connected to device");
    ofNotifyEvent(bleHeartRateCpp->statusEvent, args);
    ofNotifyEvent(bleHeartRateCpp->connectEvent, args);
}

/*
 Invoked whenever an existing connection with the peripheral is torn down.
 Reset local variables
 */
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)aPeripheral error:(NSError *)error
{
    //NSLog(@"Disconnected peripheral!");
    ofLog() << "Disconnected peripheral!";
    ofxBLEHeartRateEventArgs args(string([aPeripheral.identifier.UUIDString UTF8String]), string([aPeripheral.name UTF8String]), heartRate,aPeripheral.RSSI.intValue, "Disconnected device");
    ofNotifyEvent(bleHeartRateCpp->statusEvent, args);
    ofNotifyEvent(bleHeartRateCpp->disconnectEvent, args);
    
    
    //self.connected = @"Not connected";
    //[connectButton setTitle:@"Connect"];
    self.manufacturer = @"";
    self.heartRate = 0;
    if( peripheral )
    {
        [peripheral setDelegate:nil];
        [peripheral release];
        peripheral = nil;
    }
    
    
}

/*
 Invoked whenever the central manager fails to create a connection with the peripheral.
 */
- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)aPeripheral error:(NSError *)error
{
    //NSLog(@"Fail to connect to peripheral: %@ with error = %@", aPeripheral, [error localizedDescription]);
    ofLog() << "Fail to connect to peripheral! " << string([error.localizedDescription UTF8String]);
    ofxBLEHeartRateEventArgs args(string([aPeripheral.identifier.UUIDString UTF8String]), string([aPeripheral.name UTF8String]), heartRate,aPeripheral.RSSI.intValue, "Failed to connect to device");
    ofNotifyEvent(bleHeartRateCpp->statusEvent, args);
    ofNotifyEvent(bleHeartRateCpp->disconnectEvent, args);
    
    //[connectButton setTitle:@"Connect"];
    if( peripheral )
    {
        [peripheral setDelegate:nil];
        [peripheral release];
        peripheral = nil;
    }
}


#pragma mark - CBPeripheral delegate methods
/*
 Invoked upon completion of a -[discoverServices:] request.
 Discover available characteristics on interested services
 */
- (void) peripheral:(CBPeripheral *)aPeripheral didDiscoverServices:(NSError *)error
{
    for (CBService *aService in aPeripheral.services)
    {
        //NSLog(@"Service found with UUID: %@", aService.UUID);
        NSString* str = [aService.UUID UUIDString];// CFUUIDCreateString(nil, aService.UUID);
        //NSString* str = [[[NSUUID alloc] initWithUUIDBytes:[[self aService.UUID.data] aService.UUID.bytes]] UUIDString];
        ofLog() << "Service found with UUID: " << string([str UTF8String]);
        
        
        /* Heart Rate Service */
        if ([aService.UUID isEqual:[CBUUID UUIDWithString:@"180D"]])
        {
            [aPeripheral discoverCharacteristics:nil forService:aService];
            ofxBLEHeartRateEventArgs args(string([aPeripheral.identifier.UUIDString UTF8String]), string([aPeripheral.name UTF8String]), heartRate,aPeripheral.RSSI.intValue, "Service found: 180D");
            ofNotifyEvent(bleHeartRateCpp->statusEvent, args);
        }
        
        /* Device Information Service */
        if ([aService.UUID isEqual:[CBUUID UUIDWithString:@"180A"]])
        {
            [aPeripheral discoverCharacteristics:nil forService:aService];
            ofxBLEHeartRateEventArgs args(string([aPeripheral.identifier.UUIDString UTF8String]), string([aPeripheral.name UTF8String]), heartRate,aPeripheral.RSSI.intValue, "Service found: 180A");
            ofNotifyEvent(bleHeartRateCpp->statusEvent, args);
        }
        
        /* GAP (Generic Access Profile) for Device Name */
        // https://stackoverflow.com/questions/19984314/core-bluetooth-deprecations-for-ios-7?noredirect=1&lq=1
        //CBUUIDGenericAccessProfileString = "1800" //0x1800 is the Generic Access Service Identifier
        if ( [aService.UUID isEqual:[CBUUID UUIDWithString:@"1800"]] )
        {
            [aPeripheral discoverCharacteristics:nil forService:aService];
            ofxBLEHeartRateEventArgs args(string([aPeripheral.identifier.UUIDString UTF8String]), string([aPeripheral.name UTF8String]), heartRate,aPeripheral.RSSI.intValue, "Service found: GenericAccessProfile");
            ofNotifyEvent(bleHeartRateCpp->statusEvent, args);
        }
        
        
    }
}

/*
 Invoked upon completion of a -[discoverCharacteristics:forService:] request.
 Perform appropriate operations on interested characteristics
 */
- (void) peripheral:(CBPeripheral *)aPeripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    if ([service.UUID isEqual:[CBUUID UUIDWithString:@"180D"]])
    {
        for (CBCharacteristic *aChar in service.characteristics)
        {
            /* Set notification on heart rate measurement */
            if ([aChar.UUID isEqual:[CBUUID UUIDWithString:@"2A37"]])
            {
                [peripheral setNotifyValue:YES forCharacteristic:aChar];
                //NSLog(@"Found a Heart Rate Measurement Characteristic");
                ofLog() << "Found a Heart Rate Measurement Characteristic";
                ofxBLEHeartRateEventArgs args(string([aPeripheral.identifier.UUIDString UTF8String]), string([aPeripheral.name UTF8String]), heartRate,aPeripheral.RSSI.intValue, "Found heart rate measurement characteristic: 2A37");
                ofNotifyEvent(bleHeartRateCpp->statusEvent, args);
                
            }
            /* Read body sensor location */
            if ([aChar.UUID isEqual:[CBUUID UUIDWithString:@"2A38"]])
            {
                [aPeripheral readValueForCharacteristic:aChar];
                //NSLog(@"Found a Body Sensor Location Characteristic");
                ofLog() << "Found a Body Sensor Location Characteristic";
                ofxBLEHeartRateEventArgs args(string([aPeripheral.identifier.UUIDString UTF8String]), string([aPeripheral.name UTF8String]), heartRate,aPeripheral.RSSI.intValue, "Found body sensor location characteristic: 2A38");
                ofNotifyEvent(bleHeartRateCpp->statusEvent, args);

            }
            
            /* Write heart rate control point */
            if ([aChar.UUID isEqual:[CBUUID UUIDWithString:@"2A39"]])
            {
                uint8_t val = 1;
                NSData* valData = [NSData dataWithBytes:(void*)&val length:sizeof(val)];
                [aPeripheral writeValue:valData forCharacteristic:aChar type:CBCharacteristicWriteWithResponse];
            }
        }
    }
    
    // https://stackoverflow.com/questions/19984314/core-bluetooth-deprecations-for-ios-7?noredirect=1&lq=1
    //CBUUIDGenericAccessProfileString = @"1800" //0x1800 is the Generic Access Service Identifier
    if ( [service.UUID isEqual:[CBUUID UUIDWithString:@"1800"]] )
    {
        for (CBCharacteristic *aChar in service.characteristics)
        {
            /* Read device name */
            // CBUUIDDeviceNameString = @"2A00" // 0x2A00
            if ([aChar.UUID isEqual:[CBUUID UUIDWithString:@"2A00"]])
            {
                [aPeripheral readValueForCharacteristic:aChar];
                //NSLog(@"Found a Device Name Characteristic");
                ofLog() << "Found a Device Name Characteristic";
                ofxBLEHeartRateEventArgs args(string([aPeripheral.identifier.UUIDString UTF8String]), string([aPeripheral.name UTF8String]), heartRate,aPeripheral.RSSI.intValue, "Found device name characteristic: GAP");
                ofNotifyEvent(bleHeartRateCpp->statusEvent, args);
            }
        }
    }
    
    if ([service.UUID isEqual:[CBUUID UUIDWithString:@"180A"]])
    {
        for (CBCharacteristic *aChar in service.characteristics)
        {
            /* Read manufacturer name */
            if ([aChar.UUID isEqual:[CBUUID UUIDWithString:@"2A29"]])
            {
                [aPeripheral readValueForCharacteristic:aChar];
                //NSLog(@"Found a Device Manufacturer Name Characteristic");
                ofLog() << "Found a Device Manufacturer Name Characteristic";
                ofxBLEHeartRateEventArgs args(string([aPeripheral.identifier.UUIDString UTF8String]), string([aPeripheral.name UTF8String]), heartRate,aPeripheral.RSSI.intValue, "Found device manufacturer characteristic: 2A29");
                ofNotifyEvent(bleHeartRateCpp->statusEvent, args);
            }
        }
    }
}

/*
 Invoked upon completion of a -[readValueForCharacteristic:] request or on the reception of a notification/indication.
 */
- (void) peripheral:(CBPeripheral *)aPeripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    NSLog(@"received value for char %@", characteristic.UUID);
    
    /* Updated value for heart rate measurement received */
    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:@"2A37"]])
    {
        if( (characteristic.value)  || !error )
        {
            /* Update UI with heart rate data */
            [self updateWithHRMData:characteristic.value];
            
        }
    }
    /* Value for body sensor location received */
    // corsense elitehrv finger here
    else  if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:@"2A38"]])
    {
        NSData * updatedValue = characteristic.value;
        uint8_t* dataPointer = (uint8_t*)[updatedValue bytes];
        if(dataPointer)
        {
            uint8_t location = dataPointer[0];
            NSString*  locationString;
            switch (location)
            {
                case 0:
                    locationString = @"Other";
                    break;
                case 1:
                    locationString = @"Chest";
                    break;
                case 2:
                    locationString = @"Wrist";
                    break;
                case 3:
                    locationString = @"Finger";
                    break;
                case 4:
                    locationString = @"Hand";
                    break;
                case 5:
                    locationString = @"Ear Lobe";
                    break;
                case 6:
                    locationString = @"Foot";
                    break;
                default:
                    locationString = @"Reserved";
                    break;
            }
            //NSLog(@"Body Sensor Location = %@ (%d)", locationString, location);
            ofLog() << "Body Sensor Location = " << string([locationString UTF8String]);
            ofxBLEHeartRateEventArgs args(string([aPeripheral.identifier.UUIDString UTF8String]), string([aPeripheral.name UTF8String]), heartRate,aPeripheral.RSSI.intValue, "Body sensor location received: " + string([locationString UTF8String]));
            ofNotifyEvent(bleHeartRateCpp->statusEvent, args);
        }
    }
    /* Value for device Name received */
    // CBUUIDDeviceNameString = @"2A00" // 0x2A00
    else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:@"2A00"]])
    {
        NSString * deviceName = [[[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding] autorelease];
        //NSLog(@"Device Name = %@", deviceName);
        ofLog() << "Device Name = " << string([deviceName UTF8String]);
        ofxBLEHeartRateEventArgs args(string([aPeripheral.identifier.UUIDString UTF8String]), string([aPeripheral.name UTF8String]), heartRate,aPeripheral.RSSI.intValue, "Device name received: " + string([deviceName UTF8String]));
        ofNotifyEvent(bleHeartRateCpp->statusEvent, args);
    }
    /* Value for manufacturer name received */
    else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:@"2A29"]])
    {
        self.manufacturer = [[[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding] autorelease];
        //NSLog(@"Manufacturer Name = %@", self.manufacturer);
        ofLog() << "Manufacturer Name = " << string([self.manufacturer UTF8String]);
        ofxBLEHeartRateEventArgs args(string([aPeripheral.identifier.UUIDString UTF8String]), string([aPeripheral.name UTF8String]), heartRate,aPeripheral.RSSI.intValue, "Manufacturer name received: " + string([self.manufacturer  UTF8String]));
        ofNotifyEvent(bleHeartRateCpp->statusEvent, args);
    }
    else {
        // ok wtf is the value
        ofLog() << "Unknown charactersitc value " << string([characteristic.UUID.UUIDString UTF8String]);
    }
}

- (void)peripheral:(CBPeripheral *)peripheral
       didReadRSSI:(NSNumber *)RSSI
             error:(NSError *)error {
    //NSLog(@"ok rssi: %@", RSSI);
}

- (void) peripheralDidUpdateRSSI:(CBPeripheral *)peripheral
                          error:(NSError *)error {
    //NSLog(@"ok2 rssi: %@", [peripheral RSSI]);
}

@end
