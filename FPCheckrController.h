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
#import "FPChartPanelController.h"

#define kIdleTimeoutInSeconds   30
#define kIdleEventMarker        (time_t)0
#define kMenuBarIconSizeTweak   43
#define kChartRefreshMult		15

#define LOG_FILE	([[NSString stringWithFormat:@"~/Library/Application Support/%@/log.csv", \
[[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString*)kCFBundleNameKey]] stringByExpandingTildeInPath])

#define CAN_CHART()	(_logging && [[NSFileManager defaultManager] fileExistsAtPath:LOG_FILE])


@interface FPCheckrController : NSObject <GrowlApplicationBridgeDelegate> {
	IBOutlet NSWindow *_window;
	IBOutlet NSTabView *_tabView;
    IBOutlet NSTextField *_statusText;
    IBOutlet NSButton *_monitorButton;
    IBOutlet NSButton *_growlButton;
    IBOutlet NSButton *_logButton;
    IBOutlet NSMenu *_menuBarMenu;
    IBOutlet NSMenuItem *_mainWinMI;
    IBOutlet NSMenuItem *_monitorMI;
    IBOutlet NSMenuItem *_growlMI;
    IBOutlet NSMenuItem *_logMI;
	IBOutlet NSSegmentedControl *_chartMetricSelect;
	IBOutlet NSButton *_chartIdleButton;
	IBOutlet NSMenuItem *_chartingMI;
    IBOutlet NSButton *_enableGroupsButton;
    
    IBOutlet FPChartPanelController* _chartPanelCtlr;
	
    NSStatusItem *_menuBarItem;
    
    NSTimer *_checkFrontProcessTimer;
    BOOL _monitoring;
    BOOL _growling;
    BOOL _logging;
    ProcessSerialNumber _lastFrontProcess;
    
    FPCheckrEventController* _events;
    time_t _lastEvent;
}

- (IBAction) showPrefs:(id)sender;
- (IBAction) toggleMonitoring:(id)sender;
- (IBAction) toggleGrowl:(id)sender;
- (IBAction) toggleLog:(id)sender;

- (IBAction) chartClick:(id)sender;
@end
