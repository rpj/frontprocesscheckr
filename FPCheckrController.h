//
//  FPCheckrController.h
//  FrontProcessCheckr
//
//  Created by Jacob Farkas on 2/29/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Growl-WithInstaller/GrowlApplicationBridge.h>
#import "FPCheckrEventController.h"

#define kIdleTimeoutInSeconds   30
#define kIdleEventMarker        (time_t)0
#define kMenuBarIconSizeTweak   43

@interface FPCheckrController : NSObject <GrowlApplicationBridgeDelegate> {
	IBOutlet NSWindow *_window;
    IBOutlet NSTextField *_statusText;
    IBOutlet NSButton *_monitorButton;
    IBOutlet NSButton *_growlButton;
    IBOutlet NSButton *_logButton;
    IBOutlet NSMenu *_menuBarMenu;
    IBOutlet NSMenuItem *_monitorMI;
    IBOutlet NSMenuItem *_growlMI;
    IBOutlet NSMenuItem *_logMI;
	IBOutlet NSWindow *_chartWindow;
	IBOutlet NSImageView *_chartImage;
	IBOutlet NSSegmentedControl *_chartMetricSelect;
	IBOutlet NSButton *_chartIdleButton;
	IBOutlet NSMenuItem *_chartingMI;
	IBOutlet NSProgressIndicator *_chartingSpinner;
	
    NSStatusItem *_menuBarItem;
    
    NSTimer *_checkFrontProcessTimer;
    BOOL _monitoring;
    BOOL _growling;
    BOOL _logging;
    ProcessSerialNumber _lastFrontProcess;
    
    
    FPCheckrEventController* _events;
    time_t _lastEvent;
}

- (IBAction) toggleMonitoring:(id)sender;
- (IBAction) toggleGrowl:(id)sender;
- (IBAction) toggleLog:(id)sender;

- (IBAction) toggleCharting:(id)sender;

- (IBAction) generateChart:(id)sender;
@end
