//
//  FPCheckrController.m
//  FrontProcessCheckr
//
//  Created by Jacob Farkas on 2/29/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "FPCheckrController.h"

#define LOG_FILE	([[NSString stringWithFormat:@"~/Library/Application Support/%@/log.csv", \
					[[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString*)kCFBundleNameKey]] stringByExpandingTildeInPath])

@implementation FPCheckrController

- (void) _log:(NSString*)frontProcessName event:(NSString*)event
{
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
    
    if (_logging)
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

- (void) awakeFromNib
{
    [GrowlApplicationBridge setGrowlDelegate:self];
    
    _events = [[FPCheckrEventController alloc] initWithTarget:self andSelector:@selector(_event:)];
    [_events installEventHandlers];
    
    NSUserDefaults* sud = [NSUserDefaults standardUserDefaults];
    id curBool = nil;
    
    // set these to the negation of what they should be, so that the toggleXYZ: method calls
    // (below) do the proper thing
    if ((curBool = [sud objectForKey:@"Growl"]))
        _growling = ![curBool boolValue];
    if ((curBool = [sud objectForKey:@"Log"]))
        _logging = ![curBool boolValue];
    
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
	[_chartingMI setEnabled:[[NSFileManager defaultManager] fileExistsAtPath:LOG_FILE]];
}

- (IBAction) toggleMain:(id)sender;
{
	[_window makeKeyAndOrderFront:self];
	[_window orderFrontRegardless];
}

- (IBAction) toggleCharting:(id)sender;
{
	[_chartWindow setIsVisible:YES];
	[_chartWindow makeKeyAndOrderFront:self];
	[_chartWindow orderFrontRegardless];
}

- (IBAction) generateChart:(id)sender;
{
	[_chartingSpinner setHidden:NO];
	[_chartingSpinner startAnimation:self];
	
	NSString* script = [[NSBundle mainBundle] pathForResource:@"procLog" ofType:@"pl"];
	
	NSPipe* tStdOutPipe = [NSPipe pipe];
	NSTask* task = [[NSTask alloc] init];
	
	NSMutableArray* targs = [NSMutableArray arrayWithObjects:@"-c", @"-C", @"-f", LOG_FILE, nil];
	
	if ([_chartIdleButton state] == NSOnState)
		[targs addObject:@"-i"];
	if ([_chartMetricSelect selectedSegment] == 1)
		[targs addObjectsFromArray:[NSArray arrayWithObjects:@"-s", @"count", nil]];
	
	[task setArguments:targs];	
	[task setLaunchPath:script];
	[task setStandardOutput:tStdOutPipe];
	[task launch];
	
	while ([task isRunning])
		[NSThread sleepForTimeInterval:0.001];
	
	NSData* output = [[tStdOutPipe fileHandleForReading] availableData];
	NSString* outputStr = [[NSString alloc] initWithData:output encoding:NSASCIIStringEncoding];
	
	NSURL* url = [[NSURL alloc] initWithScheme:@"http" host:@"chart.googleapis.com" path:outputStr];
	NSURLRequest* imageReq = [NSURLRequest requestWithURL:url];
	NSURLResponse* imageResp = nil;
	NSError* err = nil;
	NSData* imageData = [NSURLConnection sendSynchronousRequest:imageReq returningResponse:&imageResp error:&err];
	
	if (!err) {
		NSImage* image = [[NSImage alloc] initWithData:imageData];
		[_chartImage setImage:image];
		[image release];
	}
	else
		NSLog(@"Loading URL:\n%@\nfailed with error:\n%@\n", url, err);
	
	[[NSFileManager defaultManager] removeItemAtPath:outputStr error:nil];
	[outputStr release];
	
	[_chartingSpinner setHidden:YES];
	[_chartingSpinner stopAnimation:self];
}
						  
@end
