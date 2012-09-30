//
//  HomeScreenViewController.m
//  SensorStreaming
//
//  Created by Qays Poonawala on 2012-09-01.
//  Copyright (c) 2012 Orbotix, Inc. All rights reserved.
//

#import "HomeScreenViewController.h"
#import "GameSettings.h"

@interface HomeScreenViewController ()

@end

@implementation HomeScreenViewController

extern int turnSeconds;
extern int gameSeconds;

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    //should load fron nsUserDefaults
    if(!turnSeconds){
    turnSeconds = 20;
    }
    if(!gameSeconds){
    gameSeconds = 60;
    }
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return ((interfaceOrientation == UIInterfaceOrientationLandscapeLeft) ||
            (interfaceOrientation == UIInterfaceOrientationLandscapeRight));
}

- (void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
//    UIViewController 
}

@end
