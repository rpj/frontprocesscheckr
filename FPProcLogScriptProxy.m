//
//  FPProcLogScriptProxy.m
//  FrontProcessCheckr
//
//  Created by Ryan Joseph on 2/20/11.
//  Copyright 2011 Apple Inc. All rights reserved.
//

#import "FPProcLogScriptProxy.h"
#import "FPCheckrController.h"

@implementation FPProcLogScriptProxy
+ (FPProcLogScriptProxy*) proxyWithArguments:(NSArray*)args;
{
    return [[[self alloc] initWithArguments:args] autorelease];
}

+ (NSString*) _groupsAsFormattedString:(NSDictionary*)groups;
{
    NSMutableString* rv = nil;
    
    if (groups && [[groups allKeys] count]) {
        rv = [NSMutableString string];
        
        for (NSString* gname in [groups allKeys]) {
            [rv appendFormat:@"%@=", gname];
            
            for (NSString* aname in (NSArray*)[groups objectForKey:gname])
                [rv appendFormat:@"%@,", aname];
            
            [rv replaceCharactersInRange:NSMakeRange([rv length] - 1, 1) withString:@""];
            [rv appendString:@":"];
        }
        
        [rv replaceCharactersInRange:NSMakeRange([rv length] - 1, 1) withString:@""];
    }
    
    return rv;
}

+ (NSString*) chartURLWithIdleFlag:(BOOL)useIdle metricIsCount:(BOOL)isCount groups:(NSDictionary*)groups;
{
    NSMutableArray* targs = [NSMutableArray arrayWithObjects:
                             @"-c", @"-C", @"-b", @"7", @"-f", LOG_FILE, 
                             @"-s", (isCount ? @"count" : @"time"), nil];
    
    if (useIdle) [targs addObject:@"-i"];
    
    if (groups && [[groups allKeys] count])
        [targs addObjectsFromArray:
         [NSArray arrayWithObjects:
          @"-g", [self _groupsAsFormattedString:groups], nil]];
    
    return [[self proxyWithArguments:targs] runSynchronous];
}

+ (NSString*) chartURLWithIdleFlag:(BOOL)useIdle metricIsCount:(BOOL)isCount;
{
    return [self chartURLWithIdleFlag:useIdle metricIsCount:isCount groups:nil];
}

+ (NSArray*) fullAppList;
{
    return [[[self proxyWithArguments:[NSArray arrayWithObjects:@"-f", LOG_FILE, @"-G", nil]]
             runSynchronous] componentsSeparatedByString:@"\n"];
}

- (void) _run;
{
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    id output = nil;
    
    if (_args) {
        NSPipe* tStdOutPipe = [NSPipe pipe];
        _task = [[NSTask alloc] init];
        
        [_task setArguments:_args];	
        [_task setLaunchPath:_scriptPath];
        [_task setStandardOutput:tStdOutPipe];
        [_task launch];
        
        while ([_task isRunning])
            [NSThread sleepForTimeInterval:0.001];
        
        output = [[tStdOutPipe fileHandleForReading] availableData];
        
        [_task release];
    }
    else
        output = @"No arguments given, can't run task!";
    
    [_target performSelector:_action withObject:output];
    [pool release];
}

- (void) _syncRunCallback:(id)arg;
{
    if ([arg isKindOfClass:[NSData class]]) {
        if (_syncRunData) [_syncRunData release];
        _syncRunData = (NSData*)[arg retain];
    }
    else {
        NSLog(@"FPProcLogScriptProxy run thread error: '%@'", arg);
        _syncRunData = [[NSData alloc] initWithBytes:[(NSString*)arg cStringUsingEncoding:NSASCIIStringEncoding]
                                              length:[(NSString*)arg lengthOfBytesUsingEncoding:NSASCIIStringEncoding]];
    }
}

- (NSString*) runSynchronous;
{
    [self setTarget:self andAction:@selector(_syncRunCallback:)];
    _syncRunData = nil;
    
    if ([self runInBackgroundAndCallback])
        while (!_syncRunData)
            [NSThread sleepForTimeInterval:0.001];
    
    return [[[NSString alloc] initWithData:_syncRunData encoding:NSASCIIStringEncoding] autorelease];
}

- (void) setTarget:(id)target andAction:(SEL)action;
{
    _target = [target retain];
    _action = action;
}

- (BOOL) runInBackgroundAndCallback;
{
    BOOL rv = NO;
    
    if (_target && _action)
    {
        [NSThread detachNewThreadSelector:@selector(_run) toTarget:self withObject:nil];
        rv = YES;
    }
    
    return rv;
}

- (id)initWithArguments:(NSArray*)args
{
    if ((self = [super init])) {
        _scriptPath = [[[NSBundle mainBundle] pathForResource:@"procLog" ofType:@"pl"] retain];
        _args = [args retain];
        _syncRunData = nil;
    }
    
    return self;
}

- (id)init
{
    return [self initWithArguments:nil];
}

- (void)dealloc
{
    [_syncRunData release];
    [_target release];
    [_scriptPath release];
    [_args release];
    [super dealloc];
}

@end
