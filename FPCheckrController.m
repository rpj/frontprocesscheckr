//
//  FPCheckrController.m
//  FrontProcessCheckr
//
//  Created by Jacob Farkas on 2/29/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "FPCheckrController.h"

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
    NSLog(@"New front process is %@", frontProcessName);
	
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

- (id) init
{
    if ((self = [super init])) {
        _monitoring = NO;
    }
    return self;
}

- (void) dealloc
{
    [self _disableTimer];
    [super dealloc];
}

- (void) awakeFromNib
{
    [GrowlApplicationBridge setGrowlDelegate:self];
    
    NSUserDefaults* sud = [NSUserDefaults standardUserDefaults];
    id curBool = nil;
    if ((curBool = [sud objectForKey:@"Growl"]))
        _growlButton.state = [curBool boolValue];
    if ((curBool = [sud objectForKey:@"Log"]))
        _logButton.state = [curBool boolValue];
    
    [self toggleGrowl:self];
    [self toggleLog:self];
    [self toggleMonitoring:self];
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
}

- (IBAction) toggleGrowl:(id)sender
{
    _growling = _growlButton.state;
    _growlButton.title = [NSString stringWithFormat:@"Growl %@", _growling ? @"ON" : @"OFF"];
    [[NSUserDefaults standardUserDefaults] setBool:_growling forKey:@"Growl"];
}

- (IBAction) toggleLog:(id)sender
{
    _logging = _logButton.state;
    _logButton.title = [NSString stringWithFormat:@"Log %@", _logging ? @"ON" : @"OFF"];
    [[NSUserDefaults standardUserDefaults] setBool:_logging forKey:@"Log"];
}
@end
