//
//  GameSettingsViewController.h
//  SensorStreaming
//
//  Created by Qays Poonawala on 2012-09-01.
//  Copyright (c) 2012 Orbotix, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "GameSettings.h"

@interface GameSettingsViewController : UIViewController
@property (retain, nonatomic) IBOutlet UILabel *gameDurationLabel;

@property (retain, nonatomic) IBOutlet UILabel *turnDurationLabel;
@end
