//
//  FPChartPanelController.h
//  FrontProcessCheckr
//
//  Created by Ryan Joseph on 2/20/11.
//  Copyright 2011 Apple Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class FPCheckrController;

@interface FPChartPanelController : NSObject {
    IBOutlet NSPanel* _panel;
    IBOutlet NSPopUpButton* _groupPopUp;
    IBOutlet NSTableView* _availableTable;
    IBOutlet NSTableView* _inGroupTable;
    IBOutlet NSButton* _rmGroupButton;
    IBOutlet NSButton* _addToGroupButton;
    IBOutlet NSButton* _rmFromGroupButton;
    
    NSTextField* _addGroup;
    FPCheckrController* _appCtlr;
    NSMutableDictionary* _groups;
}

- (BOOL) hasAtleastOneGroup;
- (NSDictionary*) groups;

- (void) setAppDelegate:(id)delegate;

- (IBAction) showPanel:(id)sender;
- (IBAction) addGroupButton:(id)sender;
- (IBAction) rmGroupButton:(id)sender;
- (IBAction) addAppToGroupButton:(id)sender;
- (IBAction) rmAppFromGroupButton:(id)sender;
- (IBAction) groupPopUp:(id)sender;
@end
