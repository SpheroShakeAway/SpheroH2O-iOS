//
//  Team.h
//  SensorStreaming
//
//  Created by Matthew Harding on 8/24/12.
//  Copyright (c) 2012 Orbotix, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Team : NSObject

@property (nonatomic) int shakesCount;
@property (nonatomic) double r;
@property (nonatomic) double g;
@property (nonatomic) double b;

- (void) incrementShakesCount;

@end
