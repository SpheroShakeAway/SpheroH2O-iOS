//
//  Team.m
//  SensorStreaming
//
//  Created by Matthew Harding on 8/24/12.
//  Copyright (c) 2012 Orbotix, Inc. All rights reserved.
//

#import "Team.h"

@interface Team()

@end

@implementation Team

@synthesize shakesCount = _shakesCount;
@synthesize r = _r;
@synthesize g = _g;
@synthesize b = _b;

- (void)setShakesCount:(int)count
{
    _shakesCount = count;
}

-(int) shakesCount
{
    if (!_shakesCount)
        _shakesCount = 0;
    return _shakesCount;
}

- (void) incrementShakesCount
{
    [self setShakesCount: self.shakesCount+1 ];
}

- (void) setColor : (double) r
                  : (double) g
                  : (double) b
{
    _r = r;
    _g = g;
    _b = b;
}

- (double) r
{
    return _r;
}

- (double) g
{
    return _g;
}

- (double) b
{
    return _b;
}

@end
