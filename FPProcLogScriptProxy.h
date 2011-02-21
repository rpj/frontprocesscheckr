//
//  FPProcLogScriptProxy.h
//  FrontProcessCheckr
//
//  Created by Ryan Joseph on 2/20/11.
//  Copyright 2011 Apple Inc. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface FPProcLogScriptProxy : NSObject {
@private
    NSString* _scriptPath;
    NSArray* _args;
    NSTask* _task;
    id _target;
    SEL _action;
    NSData* _syncRunData;
}

+ (FPProcLogScriptProxy*) proxyWithArguments:(NSArray*)args;

+ (NSString*) chartURLWithIdleFlag:(BOOL)useIdle metricIsCount:(BOOL)isCount;
+ (NSString*) chartURLWithIdleFlag:(BOOL)useIdle metricIsCount:(BOOL)isCount groups:(NSDictionary*)groups;
+ (NSArray*) fullAppList;

- (NSString*) runSynchronous;

- (void) setTarget:(id)target andAction:(SEL)action;
- (BOOL) runInBackgroundAndCallback;

- (id)initWithArguments:(NSArray*)args;
@end
