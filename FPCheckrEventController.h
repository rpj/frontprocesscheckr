//
//  FPCheckrEventController.h
//  FrontProcessCheckr
//
//  Created by Ryan Joseph on 2/11/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Carbon/Carbon.h>

@interface FPCheckrEventController : NSObject {
    id  _eventTarget;
    SEL _eventSel;
}

- (void) postEvent:(NSDictionary*)info;
- (BOOL) installEventHandlers;
- (id) initWithTarget:(id)target andSelector:(SEL)selector;
@end
