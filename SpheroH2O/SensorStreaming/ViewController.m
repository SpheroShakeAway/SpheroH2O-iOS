//
//  ViewController.m
//  SensorStreaming
//
//  Created by Brian Smith on 03/28/12.
//  Copyright (c) 2011 Orbotix, Inc. All rights reserved.
//

#import "ViewController.h"
#import "RobotKit/RobotKit.h"
#include <AudioToolbox/AudioToolbox.h>
#include "GameSettings.h"

#define TOTAL_PACKET_COUNT 200
#define PACKET_COUNT_THRESHOLD 50
@interface ViewController()
@property (nonatomic, strong) Team *redTeam;
@property (nonatomic, strong) Team *blueTeam;
@property (nonatomic, strong) Team *currentTeam;
@end

@implementation ViewController

@synthesize redTeam     = _redTeam;
@synthesize blueTeam    = _blueTeam;
@synthesize currentTeam = _currentTeam;

@synthesize redShakesValueLabel;
@synthesize blueShakesValueLabel;

extern int turnSeconds;
extern int gameSeconds;

- (void)dealloc
{
    [_redTeam       release];
    [_blueTeam      release];
    [_currentTeam   release];
    [super dealloc];
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.

    /*Register for application lifecycle notifications so we known when to connect and disconnect from the robot*/
    [[NSNotificationCenter defaultCenter] addObserver:self 
                                             selector:@selector(appDidBecomeActive:) 
                                                 name:UIApplicationDidBecomeActiveNotification 
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self 
                                             selector:@selector(appWillResignActive:)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:nil];

    /*Only start the blinking loop when the view loads*/
    robotOnline = NO;
    
    //for now...
    gameLength = gameSeconds; // CHANGE BASED ON SETTINGS GLOBAL VARIABLE
    turnLength = turnSeconds; // CHANGE BASED ON SETTINGS GLOBAL VARIABLE

        
    remainingSeconds = gameLength;
    
    self.redShakesValueLabel.text  = [NSString stringWithFormat:@"%d", self.redTeam.shakesCount];
    self.redShakesValueLabel.font = [UIFont fontWithName:@"Sullivan-Fill" size:100.0];
    self.blueShakesValueLabel.text = [NSString stringWithFormat:@"%d", self.blueTeam.shakesCount];
    self.blueShakesValueLabel.font = [UIFont fontWithName:@"Sullivan-Fill" size:100.0];

    self.countdownLabel.text = [self getString: remainingSeconds];
    self.countdownLabel.font = [UIFont fontWithName:@"Sullivan-Fill" size:50.0];
    [self setupRobotConnection];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    
    self.redShakesValueLabel = nil;
    self.blueShakesValueLabel = nil;
    self.countdownLabel = nil;
    
    /*When the application is entering the background we need to close the connection to the robot*/
    [[NSNotificationCenter defaultCenter] removeObserver:self name:RKDeviceConnectionOnlineNotification object:nil];
    
    // Turn off data streaming
    [RKSetDataStreamingCommand sendCommandWithSampleRateDivisor:0
                                                   packetFrames:0
                                                     sensorMask:RKDataStreamingMaskOff
                                                    packetCount:0];
    // Unregister for async data packets
    [[RKDeviceMessenger sharedMessenger] removeDataStreamingObserver:self];
    
    // Restore stabilization (the control unit)
    [RKStabilizationCommand sendCommandWithState:RKStabilizationStateOn];
    
    // Close the connection
    [[RKRobotProvider sharedRobotProvider] closeRobotConnection];
    
    robotOnline = NO;
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return ((interfaceOrientation == UIInterfaceOrientationLandscapeLeft) ||
            (interfaceOrientation == UIInterfaceOrientationLandscapeRight));
}

-(void)appWillResignActive:(NSNotification*)notification {
    /*When the application is entering the background we need to close the connection to the robot*/
    [[NSNotificationCenter defaultCenter] removeObserver:self name:RKDeviceConnectionOnlineNotification object:nil];
    
    // Turn off data streaming
    [RKSetDataStreamingCommand sendCommandWithSampleRateDivisor:0 
                                                   packetFrames:0 
                                                     sensorMask:RKDataStreamingMaskOff 
                                                    packetCount:0];
    // Unregister for async data packets
    [[RKDeviceMessenger sharedMessenger] removeDataStreamingObserver:self];
    
    // Restore stabilization (the control unit)
    [RKStabilizationCommand sendCommandWithState:RKStabilizationStateOn];
    
    // Close the connection
    [[RKRobotProvider sharedRobotProvider] closeRobotConnection];
    
    robotOnline = NO;
}

-(void)appDidBecomeActive:(NSNotification*)notification {
    /*When the application becomes active after entering the background we try to connect to the robot*/
    [self setupRobotConnection];
}

- (void)handleRobotOnline {
    /*The robot is now online, we can begin sending commands*/
    if(!robotOnline) {
        // Start streaming sensor data
        ////First turn off stabilization so the drive mechanism does not move.
        [RKStabilizationCommand sendCommandWithState:RKStabilizationStateOff];
        
        [self sendSetDataStreamingCommand];
        
        ////Register for asynchronise data streaming packets
        [[RKDeviceMessenger sharedMessenger] addDataStreamingObserver:self selector:@selector(handleAsyncData:)];
    }
    robotOnline = YES;
    [timer invalidate];
    timer = nil;
    startGameTime1 = CFAbsoluteTimeGetCurrent();
    alarm = NO;
    
    [self updateTimer];
    timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(updateTimer) userInfo:nil repeats:YES];
}

-(void)sendSetDataStreamingCommand {
    
    // Requesting the Accelerometer X, Y, and Z filtered (in Gs)
    //            the IMU Angles roll, pitch, and yaw (in degrees)
    //            the Quaternion data q0, q1, q2, and q3 (in 1/10000) of a Q
    RKDataStreamingMask mask =  RKDataStreamingMaskAccelerometerFilteredAll |
                                RKDataStreamingMaskIMUAnglesFilteredAll   |
                                RKDataStreamingMaskQuaternionAll;
    
    // Note: If your ball has Firmware < 1.20 then these Quaternions
    //       will simply show up as zeros.
    
    // Sphero samples this data at 400 Hz.  The divisor sets the sample
    // rate you want it to store frames of data.  In this case 400Hz/40 = 10Hz
    uint16_t divisor = 40;
    
    // Packet frames is the number of frames Sphero will store before it sends
    // an async data packet to the iOS device
    uint16_t packetFrames = 1;
    
    // Count is the number of async data packets Sphero will send you before
    // it stops.  You want to register for a finite count and then send the command
    // again once you approach the limit.  Otherwise data streaming may be left
    // on when your app crashes, putting Sphero in a bad state.
    uint8_t count = TOTAL_PACKET_COUNT;
    
    // Reset finite packet counter
    packetCounter = 0;
    
    // Send command to Sphero
    [RKSetDataStreamingCommand sendCommandWithSampleRateDivisor:divisor
                                                   packetFrames:packetFrames
                                                     sensorMask:mask
                                                    packetCount:count];

}

- (void)handleAsyncData:(RKDeviceAsyncData *)asyncData
{
    // Need to check which type of async data is received as this method will be called for
    // data streaming packets and sleep notification packets. We are going to ingnore the sleep
    // notifications.
    if ([asyncData isKindOfClass:[RKDeviceSensorsAsyncData class]]) {
        
        // If we are getting close to packet limit, request more
        packetCounter++;
        if( packetCounter > (TOTAL_PACKET_COUNT-PACKET_COUNT_THRESHOLD)) {
            [self sendSetDataStreamingCommand];
        }
        
        // Received sensor data, so display it to the user.
        RKDeviceSensorsAsyncData *sensorsAsyncData = (RKDeviceSensorsAsyncData *)asyncData;
        RKDeviceSensorsData *sensorsData = [sensorsAsyncData.dataFrames lastObject];
        RKAccelerometerData *accelerometerData = sensorsData.accelerometerData;
        
        // Print data to the text fields
        
        self.redShakesValueLabel.text  = [NSString stringWithFormat:@"%d", self.redTeam.shakesCount];
        self.redShakesValueLabel.font = [UIFont fontWithName:@"Sullivan-Fill" size:100.0];
        self.blueShakesValueLabel.text = [NSString stringWithFormat:@"%d", self.blueTeam.shakesCount];
        self.blueShakesValueLabel.font = [UIFont fontWithName:@"Sullivan-Fill" size:100.0];
        
        uint8_t accel = pow(accelerometerData.acceleration.x,2) +
                        pow(accelerometerData.acceleration.y,2) +
                        pow(accelerometerData.acceleration.z,2);
        if (accel > 70.0)
        {
            [self.currentTeam incrementShakesCount];
            //[self vibrateMacro];
        }
        
    }
}

-(void)setupRobotConnection {
    /*Try to connect to the robot*/
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleRobotOnline) name:RKDeviceConnectionOnlineNotification object:nil];
    if ([[RKRobotProvider sharedRobotProvider] isRobotUnderControl]) {
        [[RKRobotProvider sharedRobotProvider] openRobotConnection];        
    }
}

- (Team *)redTeam
{
    if (!_redTeam)
    {
        _redTeam = [[Team alloc] init];
        [_redTeam setR: 1.0];
        [_redTeam setG: 0.0];
        [_redTeam setB: 0.0];
    }
    return _redTeam;
}

- (Team *) blueTeam
{
    if (!_blueTeam)
    {
        _blueTeam = [[Team alloc] init];
        [_blueTeam setR: 0.0];
        [_blueTeam setG: 0.0];
        [_blueTeam setB: 1.0];
    }
    return _blueTeam;
}

- (Team *) currentTeam
{
    if (!_currentTeam)
        [self setCurrentTeam : self.redTeam];
    return _currentTeam;
}

- (void) setCurrentTeam:(Team *)team
{
    _currentTeam = team;
}

- (void)decideWinner
{
    if (self.redTeam.shakesCount > self.blueTeam.shakesCount)
    {
        [self setCurrentTeam:self.redTeam];
    }
    else if (self.redTeam.shakesCount < self.blueTeam.shakesCount)
    {
        [self setCurrentTeam:self.blueTeam];
    }
    else
    {
        // Tie
    }
}

-(void) updateTimer
{
    self.countdownLabel.text = [self getString:remainingSeconds];
    self.countdownLabel.font = [UIFont fontWithName:@"Sullivan-Fill" size:50.0];
    if (remainingSeconds <= 0)
    {
        [self endGame];
        return;
    }
    if ((((gameLength - remainingSeconds) % turnLength) == 0) ||
        (((gameLength - remainingSeconds - 5) % turnLength) == 0))
    {
        [self changeTurn];
    }
    --remainingSeconds;
}

-(void)changeTurn
{
    if (alarm)
    {
        [RKRGBLEDOutputCommand sendCommandWithRed:self.currentTeam.r green:self.currentTeam.g blue:self.currentTeam.b];
        [RKRawMotorValuesCommand sendCommandWithLeftMode : RKRawMotorModeForward
                                               leftPower : (RKRawMotorPower) 0
                                               rightMode : RKRawMotorModeForward
                                              rightPower : (RKRawMotorPower) 0];
        alarm = NO;
    }
    else
    {
        if (self.currentTeam == self.redTeam)
        {
            [self setCurrentTeam : self.blueTeam];
        }
        else
        {
            [self setCurrentTeam : self.redTeam];
        }
        [RKAbortMacroCommand sendCommand];
        [RKRGBLEDOutputCommand sendCommandWithRed:1.0 green:1.0 blue:1.0];
        [RKRawMotorValuesCommand sendCommandWithLeftMode : RKRawMotorModeForward
                                               leftPower : (RKRawMotorPower) 255
                                               rightMode : RKRawMotorModeForward
                                              rightPower : (RKRawMotorPower) 255];
        alarm = YES;
    }
}

- (void)endGame
{
    [self decideWinner];
    [self toggleLED];
    [timer invalidate];
    
    // Unregister for async data packets
    [[RKDeviceMessenger sharedMessenger] removeDataStreamingObserver:self];
    
    // Restore stabilization (the control unit)
    [RKStabilizationCommand sendCommandWithState:RKStabilizationStateOn];
    AudioServicesPlaySystemSound(1005);
}

- (void)toggleLED
{
    /*Toggle the LED on and off*/
    if (ledON) {
        ledON = NO;
        [RKRGBLEDOutputCommand sendCommandWithRed:0.0 green:0.0 blue:0.0];
    } else {
        ledON = YES;
        [RKRGBLEDOutputCommand sendCommandWithRed:self.currentTeam.r
                                            green:self.currentTeam.g
                                             blue:self.currentTeam.b];
    }
    [self performSelector:@selector(toggleLED) withObject:nil afterDelay:0.5];
}


- (void)vibrateMacro
{
    if (!alarm)
    {
        //Create a new macro object to send to Sphero
        RKMacroObject *macro = [RKMacroObject new];
        [macro addCommand:[RKMCRawMotor commandWithLeftMode:RKRawMotorModeForward leftSpeed:255
                                                  rightMode:RKRawMotorModeForward rightSpeed:255 delay:0]];
        
        for (int i = 0; i<7; ++i) {
            [macro addCommand:[RKMCRawMotor commandWithLeftMode:RKRawMotorModeReverse leftSpeed:255
                                                      rightMode:RKRawMotorModeReverse rightSpeed:255 delay:25]];
            [macro addCommand:[RKMCRawMotor commandWithLeftMode:RKRawMotorModeForward leftSpeed:255
                                                      rightMode:RKRawMotorModeForward rightSpeed:255 delay:25]];
        }
        
        [macro addCommand:[RKMCRawMotor commandWithLeftMode:RKRawMotorModeReverse leftSpeed:0
                                                  rightMode:RKRawMotorModeForward rightSpeed:0 delay:25]];
        //Send full command down to Sphero to play
        [macro playMacro];
        //Release Macro
        [macro release];
    }
}


- (NSString*)getString: (int) time
{
    return [NSString stringWithFormat:@"%d:%.2d", (time / 60), (time % 60)];
}


@end
