//
//  FPCheckrEventController.m
//  FrontProcessCheckr
//
//  Created by Ryan Joseph on 2/11/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "FPCheckrEventController.h"

static OSStatus fpcEventHandler(EventHandlerCallRef inHandlerRef, EventRef event, void* refCon)
{
    OSStatus rv = noErr;
    OSType class = GetEventClass(event);
    
    if (refCon && [(id)refCon isKindOfClass:[FPCheckrEventController class]]) {
        [(FPCheckrEventController*)refCon postEvent:[NSDictionary dictionaryWithObjectsAndKeys:
                                                     [NSNumber numberWithUnsignedInt:class], @"class", nil]];
    }
            
    return rv;
}

@implementation FPCheckrEventController
- (void) postEvent:(NSDictionary*)info;
{
    [_eventTarget performSelector:_eventSel withObject:info];
}
    
- (BOOL) installEventHandlers;
{
    if (!_eventTarget || ![_eventTarget respondsToSelector:_eventSel])
        return NO;
    
    EventTypeSpec eventTypes[2];
    
    eventTypes[0].eventClass = kEventClassKeyboard;
    eventTypes[0].eventKind = kEventRawKeyDown;
    
    eventTypes[1].eventClass = kEventClassMouse;
    eventTypes[1].eventKind = kEventMouseMoved;
    
    EventHandlerUPP handlerUPP = NewEventHandlerUPP(fpcEventHandler);
    OSStatus err = InstallEventHandler(GetEventMonitorTarget(), handlerUPP, 2, eventTypes, self, NULL);
    
    return (err == noErr);
}

- (void) dealloc;
{
    [_eventTarget release];
    
    [super dealloc];
}

- (id) initWithTarget:(id)target andSelector:(SEL)selector;
{
    if ((self = [super init])) {
        _eventTarget = [target retain];
        _eventSel = selector;
    }
    
    return self;
}
@end
