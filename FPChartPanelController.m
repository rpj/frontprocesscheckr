//
//  FPChartPanelController.m
//  FrontProcessCheckr
//
//  Created by Ryan Joseph on 2/20/11.
//  Copyright 2011 Apple Inc. All rights reserved.
//

#import "FPChartPanelController.h"
#import "FPProcLogScriptProxy.h"

@implementation FPChartPanelController
- (NSArray*) _availableApps;
{
    static NSArray* _apps = nil;
    static NSDate* _lastRefesh = nil;
    
    if (!_apps || [[NSDate date] timeIntervalSinceDate:_lastRefesh] > 60.0) {
        [_apps release];
        [_lastRefesh release];
        _apps = [[FPProcLogScriptProxy fullAppList] retain];
        _lastRefesh = [[NSDate date] retain];
    }
    
    return _apps;
}

- (void) _populatePopUp;
{
    if (_groups && [[_groups allKeys] count]) {
        [_groupPopUp removeAllItems];
        
        for (NSString* gname in [_groups allKeys])
            [_groupPopUp addItemWithTitle:gname];
        
        [_groupPopUp selectItemAtIndex:0];
        [_groupPopUp setEnabled:YES];
        [_rmGroupButton setEnabled:YES];
        [_availableTable setEnabled:YES];
        [_inGroupTable setEnabled:YES];
        [_addToGroupButton setEnabled:YES];
        [_rmFromGroupButton setEnabled:YES];
    }
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView;
{
    if ([aTableView isEqualTo:_availableTable]) {
        return [[self _availableApps] count];
    }
    else if ([aTableView isEqualTo:_inGroupTable]) {
        return [[_groups objectForKey:[[_groupPopUp selectedItem] title]] count];
    }
    
    return 0;
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex;
{
    if ([aTableView isEqualTo:_availableTable]) {
        return [[self _availableApps] objectAtIndex:rowIndex];
    }
    else if ([aTableView isEqualTo:_inGroupTable]) {
        return [[_groups objectForKey:[[_groupPopUp selectedItem] title]] objectAtIndex:rowIndex];
    }
    
    return nil;
}

- (void) windowWillClose:(NSNotification*)notify;
{
    if (_groups) {
        NSUserDefaults* sud = [NSUserDefaults standardUserDefaults];
        [sud setObject:_groups forKey:@"Groups"];
        [sud synchronize];
        [_appCtlr windowDidBecomeKey:nil];
    }
}

- (void)windowDidBecomeKey:(NSNotification*)notify;
{
    NSDictionary* udDict = [[NSUserDefaults standardUserDefaults] objectForKey:@"Groups"];
    if (udDict && [[udDict allKeys] count]) {
        [_groups release];
        _groups = [[NSMutableDictionary dictionaryWithCapacity:[[udDict allKeys] count]] retain];
        
        for (NSString* gname in [udDict allKeys])
            [_groups setObject:[NSMutableArray arrayWithArray:[udDict objectForKey:gname]] forKey:gname];
        
        [self _populatePopUp];
    }
}

- (id)init
{
    if ((self = [super init])) {
        _addGroup = nil;
        _appCtlr = nil;
        
        // force a check in user defaults immediately
        [self windowDidBecomeKey:nil];
    }
    
    return self;
}

- (void)dealloc
{
    [super dealloc];
}

- (void) setAppDelegate:(id)delegate;
{
    _appCtlr = delegate;
}

- (IBAction) showPanel:(id)sender;
{
    [_panel setFloatingPanel:YES];
    [_panel makeKeyAndOrderFront:self];
    [_panel orderFrontRegardless];
}

- (IBAction) addGroupButton:(id)sender;
{
    static BOOL first = YES;
    
    if (!_addGroup) {
        _addGroup = [[NSTextField alloc] initWithFrame:[_groupPopUp frame]];
        [_addGroup setHidden:YES];
        [_addGroup setFont:[NSFont fontWithName:@"Lucida Grande" size:12.0]];
        [_addGroup setTarget:self];
        [_addGroup setAction:@selector(addGroupButton:)];
        
        [[_groupPopUp superview] addSubview:_addGroup];
        [[_groupPopUp animator] setHidden:YES];
        [[_addGroup animator] setHidden:NO];
        [_addGroup becomeFirstResponder];
    }
    else {
        if (first && !(first = NO))
            [_groupPopUp removeAllItems];
        
        NSString* gname = [_addGroup stringValue];
        
        if (!_groups)
            _groups = [[NSMutableDictionary dictionary] retain];
        
        if (![_groups objectForKey:gname])
            [_groups setObject:[NSMutableArray array] forKey:gname];
        
        [self _populatePopUp];
        [[_addGroup animator] setHidden:YES];
        [[_groupPopUp animator] setHidden:NO];
        
        [_groupPopUp selectItemWithTitle:gname];
        [self groupPopUp:self];
         
        [_addGroup release];
        _addGroup = nil;
    }
}

- (IBAction) rmGroupButton:(id)sender;
{
    [_groups removeObjectForKey:[[_groupPopUp selectedItem] title]];
    [_groupPopUp removeItemAtIndex:[_groupPopUp indexOfSelectedItem]];
    
    if (![[_groupPopUp itemArray] count]) {
        [_rmGroupButton setEnabled:NO];
        [_availableTable setEnabled:NO];
        [_inGroupTable setEnabled:NO];
        [_rmFromGroupButton setEnabled:NO];
        [_addToGroupButton setEnabled:NO];
    }
    
    [self groupPopUp:self];
}

- (void) _addOrRmToGroup:(BOOL)addingTo;
{
    NSTableView* tv = (addingTo ? _availableTable : _inGroupTable);
    SEL arrSel = (addingTo ? @selector(addObject:) : @selector(removeObjectIdenticalTo:));
    
    NSString* appName = [self tableView:tv objectValueForTableColumn:nil row:[tv selectedRow]];
    NSMutableArray* groupArray = [_groups objectForKey:[[_groupPopUp selectedItem] title]];
    
    if (groupArray)
    {
        [groupArray performSelector:arrSel withObject:appName];
        [_inGroupTable reloadData];
    }
}

- (IBAction) addAppToGroupButton:(id)sender;
{
    [self _addOrRmToGroup:YES];
}

- (IBAction) rmAppFromGroupButton:(id)sender;
{
    [self _addOrRmToGroup:NO];
}

- (IBAction) groupPopUp:(id)sender;
{
    [_inGroupTable reloadData];
}

- (BOOL) hasAtleastOneGroup;
{
    return (_groups && [[_groups allKeys] count] && 
            [[_groups objectForKey:[[_groups allKeys] objectAtIndex:0]] count]);
}

- (NSDictionary*) groups;
{
    return _groups;
}
@end
