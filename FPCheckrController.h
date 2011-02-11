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
    IBOutlet NSMenu *_menuBarMenu;
    IBOutlet NSMenuItem *_monitorMI;
    IBOutlet NSMenuItem *_growlMI;
    IBOutlet NSMenuItem *_logMI;
    
    NSTimer *_checkFrontProcessTimer;
    BOOL _monitoring;
    BOOL _growling;
    BOOL _logging;
    ProcessSerialNumber _lastFrontProcess;
    
    NSStatusItem *_menuBarItem;
}

- (IBAction) toggleMonitoring:(id)sender;
- (IBAction) toggleGrowl:(id)sender;
- (IBAction) toggleLog:(id)sender;

@end
