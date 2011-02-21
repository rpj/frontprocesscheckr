//
//  FPCheckrController.m
//  FrontProcessCheckr
//
//  Created by Jacob Farkas on 2/29/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "FPCheckrController.h"
#import "FPProcLogScriptProxy.h"

@implementation FPCheckrController

- (void) _log:(NSString*)frontProcessName event:(NSString*)event
{
	if (_logging) {
		NSFileManager* fileMgr = [NSFileManager defaultManager];
		NSString* myName = [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString*)kCFBundleNameKey];
		NSString* appSup = [NSString stringWithFormat:@"~/Library/Application Support/%@", myName];
		appSup = [appSup stringByExpandingTildeInPath];
		
		if (![fileMgr fileExistsAtPath:[appSup stringByExpandingTildeInPath]])
			[fileMgr createDirectoryAtPath:appSup attributes:nil];
		
		NSString* csvLog = [appSup stringByAppendingString:@"/log.csv"];
		
		if (![fileMgr fileExistsAtPath:csvLog])
			[@"Datestamp,Event,ProcessName\n" writeToFile:csvLog atomically:NO encoding:NSASCIIStringEncoding error:nil];
		
		NSString* logLine = [NSString stringWithFormat:@"%f,%@,%@\n", [[NSDate date] timeIntervalSince1970], event, frontProcessName];
		NSFileHandle* fileHandle = [NSFileHandle fileHandleForWritingAtPath:csvLog];
		[fileHandle seekToEndOfFile];
		[fileHandle writeData:[logLine dataUsingEncoding:NSASCIIStringEncoding]];
		[fileHandle closeFile];
	}
}

- (void) _displayProcessChangedNotification:(NSString *)frontProcessName iconData:(NSData *)icon
{
    if (_growling)
        [GrowlApplicationBridge
         notifyWithTitle:@"Front Process Changed"
         description:frontProcessName
         notificationName:@"Front Process Changed"
         iconData:icon
         priority:0
         isSticky:NO
         clickContext:nil];
    
	[self _log:frontProcessName event:@"Change"];
}

- (NSData *) _iconForProcess:(ProcessSerialNumber *)psn
{
    NSData *icon = nil;
    CFDictionaryRef processInfoDict = ProcessInformationCopyDictionary(psn, kProcessDictionaryIncludeAllInformationMask);
    if (processInfoDict) {
        CFStringRef bundlePath = CFDictionaryGetValue(processInfoDict, CFSTR("BundlePath"));
        if (bundlePath) {
            NSBundle *appBundle = [NSBundle bundleWithPath:(NSString *)bundlePath];
            NSString *iconName = [[appBundle infoDictionary] objectForKey:@"CFBundleIconFile"];
            NSString *iconPath = [appBundle pathForResource:iconName ofType:@"icns"];
            // Some apps specify the icon with an extension, some don't. Check for both.
            if (iconPath == nil) {
                iconName = [iconName stringByDeletingPathExtension];
                iconPath = [appBundle pathForResource:iconName ofType:@"icns"];
            }
            if (iconPath) 
                icon = [NSData dataWithContentsOfFile:iconPath];
        }
        CFRelease(processInfoDict);
    }
    return icon;
}

- (NSString*) _lastFrontProcessName
{
    NSString* processName = NULL;
    
    if (_lastFrontProcess.highLongOfPSN || _lastFrontProcess.lowLongOfPSN) {
        CopyProcessName(&_lastFrontProcess, (CFStringRef*)&processName);
        [processName autorelease];
    }
    
    return processName;
}

- (void) _swapMenuBarImages;
{
    NSImage* swap = [_menuBarItem image];
    [_menuBarItem setImage:[_menuBarItem alternateImage]];
    [_menuBarItem setAlternateImage:swap];
}

- (void) _updateMenuBarTooltip;
{
    [_menuBarItem setToolTip:[NSString stringWithFormat:@"Monitor %@ | Growl %@ | Log %@",
                              _monitoring ? @"ON" : @"OFF", 
                              _growling ? @"ON" : @"OFF", 
                              _logging ? @"ON" : @"OFF"]];
}

- (void) _checkIdleState
{
    if (time(NULL) - _lastEvent >= kIdleTimeoutInSeconds) {
        if (_lastEvent) {
            [self _log:[self _lastFrontProcessName] event:@"Idle"];
            [self _swapMenuBarImages];
            _lastEvent = kIdleEventMarker;
        }
    }
}

- (void) _checkFrontProcess
{
    ProcessSerialNumber frontProcess;
    Boolean sameProcess = false;
    
    GetFrontProcess(&frontProcess);
    SameProcess(&frontProcess, &_lastFrontProcess, &sameProcess);
    if (sameProcess == false) {
        memcpy(&_lastFrontProcess, &frontProcess, sizeof(ProcessSerialNumber));
        CFStringRef processName = NULL;
        CopyProcessName(&frontProcess, &processName);
        
        [self _displayProcessChangedNotification:(NSString *)processName iconData:[self _iconForProcess:&frontProcess]];
        if (processName) CFRelease(processName);
    }
    
    [self _checkIdleState];
}
 
- (void) _disableTimer
{
    [_checkFrontProcessTimer invalidate];
    [_checkFrontProcessTimer release];
    _checkFrontProcessTimer = nil;
}

- (void) _startTimer
{
    if (_checkFrontProcessTimer == nil) {
        _checkFrontProcessTimer = [[NSTimer alloc] initWithFireDate:[NSDate date] interval:1.0 target:self selector:@selector(_checkFrontProcess) userInfo:nil repeats:YES];
        [[NSRunLoop currentRunLoop] addTimer:_checkFrontProcessTimer forMode:NSDefaultRunLoopMode];
    }
}

- (void) _event:(id)infoObj;
{
    if (_lastEvent == kIdleEventMarker) {
        [self _log:[self _lastFrontProcessName] event:@"Active"];
        [self _swapMenuBarImages];
    }
    
    (void)time(&_lastEvent);
}

- (id) init
{
    if ((self = [super init])) {
        _monitoring = NO;
        (void)time(&_lastEvent);
    }
    return self;
}

- (void) dealloc
{
    [_menuBarItem release];
    [_events release];
    
    [self _disableTimer];
    [super dealloc];
}

// old NSMenuDelegate method (now informal)
- (void)menuWillOpen:(NSMenu *)menu
{
	[NSThread detachNewThreadSelector:@selector(generateChart:) toTarget:self withObject:self];
}

- (void)windowDidBecomeKey:(NSNotification*)notify;
{
    [_enableGroupsButton setEnabled:[_chartPanelCtlr hasAtleastOneGroup]];
    [_enableGroupsButton setHidden:![_chartPanelCtlr hasAtleastOneGroup]];
}

- (void) awakeFromNib
{
    [[NSApplication sharedApplication] setDelegate:self];
    [_chartPanelCtlr setAppDelegate:self];
    [GrowlApplicationBridge setGrowlDelegate:self];
    
    _events = [[FPCheckrEventController alloc] initWithTarget:self andSelector:@selector(_event:)];
    [_events installEventHandlers];
    
    NSUserDefaults* sud = [NSUserDefaults standardUserDefaults];
    id curID = nil;
	
	if ((curID = [sud objectForKey:@"ch.idle"]))
		[_chartIdleButton setState:[curID boolValue]];
	if ((curID = [sud objectForKey:@"ch.metric"]))
		[_chartMetricSelect setSelectedSegment:[curID intValue]];
    
    // set these to the negation of what they should be, so that the toggleXYZ: method calls
    // (below) do the proper thing
    if ((curID = [sud objectForKey:@"Growl"]))
        _growling = ![curID boolValue];
    if ((curID = [sud objectForKey:@"Log"]))
        _logging = ![curID boolValue];
    
    [self toggleGrowl:self];
    [self toggleLog:self];
    [self toggleMonitoring:self];
    
    NSImage* icon = [NSImage imageNamed:@"mbIcon.png"];
    NSImage* hiIcon = [NSImage imageNamed:@"mbIcon-uf.png"];
    NSSize imgSize = [icon size];
    imgSize.height -= kMenuBarIconSizeTweak;
    imgSize.width -= kMenuBarIconSizeTweak;
    [icon setSize:imgSize];
    [hiIcon setSize:imgSize];
    
    _menuBarItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength] retain];
    [_menuBarItem setImage:icon];
    [_menuBarItem setAlternateImage:hiIcon];
    [_menuBarItem setHighlightMode:YES];
    [_menuBarItem setMenu:_menuBarMenu];
    [self _updateMenuBarTooltip];
	
	[_menuBarMenu setDelegate:self];
	[self menuWillOpen:_menuBarMenu];
    [self windowDidBecomeKey:nil];
}

- (NSApplicationTerminateReply) applicationShouldTerminate:(NSApplication *)sender
{
    if (_monitoring) [self toggleMonitoring:self];
    return NSTerminateNow;
}

- (IBAction) toggleMonitoring:(id)sender
{
    if (_monitoring == NO) {
        _monitoring = YES;
        _monitorButton.title = @"Stop monitoring";
        _statusText.stringValue = @"ON";
        [self _log:nil event:@"Start"];
        [self _startTimer];
    } else {    
        _monitoring = NO;
        _monitorButton.title = @"Start monitoring";
        _statusText.stringValue = @"OFF";
        [self _disableTimer];
        [self _log:nil event:@"Stop"];
    }
    
    if ([sender isKindOfClass:[NSMenuItem class]])
        [(NSMenuItem*)sender setState:_monitoring ? NSOnState : NSOffState];
    
    [self _updateMenuBarTooltip];
}

- (void) _toggleElement:(NSButton*)button menuItem:(NSMenuItem*)mItem withFlag:(BOOL*)flag andTitle:(NSString*)title;
{
    *flag = !*flag;
    button.state = mItem.state = *flag ? NSOnState : NSOffState;
    button.title = [NSString stringWithFormat:@"%@ %@", title, *flag ? @"ON" : @"OFF"];
    [[NSUserDefaults standardUserDefaults] setBool:*flag forKey:title];
    [self _updateMenuBarTooltip];
}

- (IBAction) toggleGrowl:(id)sender
{
    [self _toggleElement:_growlButton menuItem:_growlMI withFlag:&_growling andTitle:@"Growl"];
}

- (IBAction) toggleLog:(id)sender
{
    [self _toggleElement:_logButton menuItem:_logMI withFlag:&_logging andTitle:@"Log"];
	
	// if logging was off before the toggle (i.e. was just enabled), log start
	if (_logging)
        [self _log:nil event:@"Start"];
	
	if (!CAN_CHART()) {
		[_chartingMI setImage:nil];
		[_chartingMI setTitle:@"Enable logging to see chart..."];
	}
	else if (_logging)
		[_chartingMI setTitle:@"Gathering samples..."];
	else
		[self menuWillOpen:_menuBarMenu];
}

- (void) showMain:(id)sender;
{
	[_window makeKeyAndOrderFront:self];
	[_window orderFrontRegardless];
}

- (IBAction) showPrefs:(id)sender;
{
	[_tabView selectTabViewItemAtIndex:0];
	[self showMain:self];
}

- (IBAction) chartClick:(id)sender;
{
	[_tabView selectTabViewItemAtIndex:1];
	[self showMain:self];
}

- (void) setChart:(NSImage*)image;
{
	if ([[NSThread currentThread] isMainThread]) {
		[_chartingMI setImage:image];
		[_chartingMI setTitle:@""];	
	}
	else
		[self performSelector:@selector(setChart:) onThread:[NSThread mainThread] withObject:image waitUntilDone:YES];
}

- (void) generateChart:(id)sender;
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	
	if (CAN_CHART()) {
		NSUserDefaults* sud = [NSUserDefaults standardUserDefaults];
		[sud setInteger:[_chartMetricSelect selectedSegment] forKey:@"ch.metric"];
		[sud setBool:([_chartIdleButton state] == NSOnState) forKey:@"ch.idle"];
		[sud synchronize];
        
        // TODO: the state of the _enableGroupsButton needs to be save to user defaults!
        NSDictionary* groups = (([_chartPanelCtlr hasAtleastOneGroup] && [_enableGroupsButton state]) == NSOnState ? 
                                [_chartPanelCtlr groups] : nil);
        NSString* outputStr = [FPProcLogScriptProxy chartURLWithIdleFlag:([_chartIdleButton state] == NSOnState)
                                                           metricIsCount:([_chartMetricSelect selectedSegment] == 1)
                                                                  groups:groups];
        
		NSURL* url = nil;
		
		@try {
			url = [[NSURL alloc] initWithScheme:@"http" host:@"chart.googleapis.com" path:outputStr];
			
			NSURLRequest* imageReq = [NSURLRequest requestWithURL:url];
			NSURLResponse* imageResp = nil;
			NSError* err = nil;
			NSData* imageData = [NSURLConnection sendSynchronousRequest:imageReq returningResponse:&imageResp error:&err];
			
			if (!err) {
				NSImage* image = [[NSImage alloc] initWithData:imageData];
				[self setChart:image];
				[image release];
			}
			else
				NSLog(@"Loading URL:\n%@\nfailed with error:\n%@\n", url, err);
		}
		@catch (NSException *exception) {
			NSLog(@"Bad news bears: %@", outputStr);
		}
	}
	
	[pool release];
}
@end
