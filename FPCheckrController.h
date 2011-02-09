//
//  FPCheckrController.h
//  FrontProcessCheckr
//
//  Created by Jacob Farkas on 2/29/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Growl-WithInstaller/GrowlApplicationBridge.h>

@interface FPCheckrController : NSObject <GrowlApplicationBridgeDelegate> {
    IBOutlet NSTextField *_statusText;
    IBOutlet NSButton *_monitorButton;
    IBOutlet NSButton *_growlButton;
    IBOutlet NSButton *_logButton;
    
    NSTimer *_checkFrontProcessTimer;
    BOOL _monitoring;
    BOOL _growling;
    BOOL _logging;
    ProcessSerialNumber _lastFrontProcess;
}

- (IBAction) toggleMonitoring:(id)sender;
- (IBAction) toggleGrowl:(id)sender;
- (IBAction) toggleLog:(id)sender;

@end
