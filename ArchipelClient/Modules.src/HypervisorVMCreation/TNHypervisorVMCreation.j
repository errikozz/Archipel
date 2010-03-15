/*  
 * TNViewHypervisorControl.j
 *    
 * Copyright (C) 2010 Antoine Mercadal <antoine.mercadal@inframonde.eu>
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as
 * published by the Free Software Foundation, either version 3 of the
 * License, or (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 * 
 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

@import <Foundation/Foundation.j>
@import <AppKit/AppKit.j>
 
@import "TNDatasourceVMs.j"

TNArchipelTypeHypervisorControl            = @"archipel:hypervisor:control";

TNArchipelTypeHypervisorControlAlloc       = @"alloc";
TNArchipelTypeHypervisorControlFree        = @"free";
TNArchipelTypeHypervisorControlRosterVM    = @"rostervm";

TNArchipelPushNotificationSubscription      = @"archipel:push:subscription";
TNArchipelPushNotificationSubscriptionAdded = @"added";

@implementation TNHypervisorVMCreation : TNModule 
{
    @outlet CPTextField     fieldJID            @accessors;
    @outlet CPTextField     fieldName           @accessors;
    @outlet CPButton        buttonCreateVM      @accessors;
    @outlet CPPopUpButton   popupDeleteMachine  @accessors;
    @outlet CPButton        buttonDeleteVM      @accessors;
    @outlet CPScrollView    scrollViewListVM    @accessors;
    
    CPTableView         tableVirtualMachines        @accessors;
    TNDatasourceVMs     virtualMachinesDatasource   @accessors;
    
    TNStropheContact    _virtualMachineRegistredForDeletion;
}

- (void)awakeFromCib
{
    // VM table view
    virtualMachinesDatasource   = [[TNDatasourceVMs alloc] init];
    tableVirtualMachines        = [[CPTableView alloc] initWithFrame:[[self scrollViewListVM] bounds]];
    
    [[self scrollViewListVM] setAutoresizingMask: CPViewWidthSizable | CPViewHeightSizable];
    [[self scrollViewListVM] setAutohidesScrollers:YES];
    [[self scrollViewListVM] setDocumentView:[self tableVirtualMachines]];
    [[self scrollViewListVM] setBorderedWithHexColor:@"#9e9e9e"];
    
    [[self tableVirtualMachines] setUsesAlternatingRowBackgroundColors:YES];
    [[self tableVirtualMachines] setAutoresizingMask: CPViewWidthSizable | CPViewHeightSizable];
    [[self tableVirtualMachines] setAllowsColumnReordering:YES];
    [[self tableVirtualMachines] setAllowsColumnResizing:YES];
    [[self tableVirtualMachines] setAllowsEmptySelection:YES];
    
    var vmColumNickname = [[CPTableColumn alloc] initWithIdentifier:@"nickname"];
    [vmColumNickname setWidth:250];
    [[vmColumNickname headerView] setStringValue:@"Name"];
    
    var vmColumJID = [[CPTableColumn alloc] initWithIdentifier:@"jid"];
    [vmColumJID setWidth:450];
    [[vmColumJID headerView] setStringValue:@"Jabber ID"];
    
    var vmColumStatusIcon = [[CPTableColumn alloc] initWithIdentifier:@"statusIcon"];
    var imgView = [[CPImageView alloc] initWithFrame:CGRectMake(0,0,16,16)];
    [imgView setImageScaling:CPScaleNone];
    [vmColumStatusIcon setDataView:imgView];
    [vmColumStatusIcon setResizingMask:CPTableColumnAutoresizingMask ];
    [vmColumStatusIcon setWidth:16];
    [[vmColumStatusIcon headerView] setStringValue:@""];
    
    [[self tableVirtualMachines] addTableColumn:vmColumStatusIcon];
    [[self tableVirtualMachines] addTableColumn:vmColumNickname];
    [[self tableVirtualMachines] addTableColumn:vmColumJID];
    
    [[self tableVirtualMachines] setDataSource:[self virtualMachinesDatasource]];
}

- (void)willLoad
{
    [super willLoad];
    
    [self registerSelector:@selector(didSubscriptionPushReceived:) forPushNotificationType:TNArchipelPushNotificationSubscription];
}

- (void)willShow
{
    [super willShow];
    
    var center = [CPNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(didNickNameUpdated:) name:TNStropheContactNicknameUpdatedNotification object:[self entity]];
    [center addObserver:self selector:@selector(didContactAdded:) name:TNStropheRosterAddedContactNotification object:nil];
    
    [[self fieldName] setStringValue:[[self entity] nickname]];
    [[self fieldJID] setStringValue:[[self entity] jid]];
        
    [self getHypervisorRoster];
}

- (BOOL)didSubscriptionPushReceived:(TNStropheStanza)aStanza
{
    if ([[aStanza firstChildWithName:@"query"] valueForAttribute:@"change"] == TNArchipelPushNotificationSubscriptionAdded)
        [self getHypervisorRoster];
    
    return YES;
}

- (void)didContactAdded:(CPNotification)aNotification
{
    [self getHypervisorRoster];
}

- (void)didNickNameUpdated:(CPNotification)aNotification
{
    [[self fieldName] setStringValue:[[self entity] nickname]] 
}

- (void)getHypervisorRoster
{
    var rosterStanza    = [TNStropheStanza iqWithAttributes:{"type" : TNArchipelTypeHypervisorControl}];
        
    [rosterStanza addChildName:@"query" withAttributes:{"type" : TNArchipelTypeHypervisorControlRosterVM}];
    
    [[self entity] sendStanza:rosterStanza andRegisterSelector:@selector(didReceiveHypervisorRoster:) ofObject:self];
}

- (void)didReceiveHypervisorRoster:(id)aStanza 
{
    var queryItems  = [aStanza childrenWithName:@"item"];
    var center      = [CPNotificationCenter defaultCenter];
    
    [[[self virtualMachinesDatasource] VMs] removeAllObjects];
    
    for (var i = 0; i < [queryItems count]; i++)
    {
        var jid     = [[queryItems objectAtIndex:i] text];
        var entry   = [[self roster] getContactFromJID:jid];
        
        if (entry) 
        {
           if ([[[entry vCard] firstChildWithName:@"TYPE"] text] != "hypervisor")
           {
                [[self virtualMachinesDatasource] addVM:entry];
                [center addObserver:self selector:@selector(didVirtualMachineChangesStatus:) name:TNStropheContactPresenceUpdatedNotification object:entry];   
           }
        }
    }
    [[self tableVirtualMachines] reloadData];
}

- (void)didVirtualMachineChangesStatus:(CPNotification)aNotif
{
    [[self tableVirtualMachines] reloadData];
}


//actions
- (IBAction)addVirtualMachine:(id)sender
{
    var creationStanza  = [TNStropheStanza iqWithAttributes:{"type": TNArchipelTypeHypervisorControl}];
    var uuid            = [CPString UUID];
    
    [creationStanza addChildName:@"query" withAttributes:{"type": TNArchipelTypeHypervisorControlAlloc}];
    [creationStanza addChildName:@"jid"];
    [creationStanza addTextNode:uuid];
    
    [[self entity] sendStanza:creationStanza andRegisterSelector:@selector(didAllocVirtualMachine:) ofObject:self];
    
    [buttonCreateVM setEnabled:NO];
}

- (void)didAllocVirtualMachine:(id)aStanza
{
    [buttonCreateVM setEnabled:YES];
    
    if ([aStanza getType] == @"success")
    {
        var vmJid   = [[[aStanza firstChildWithName:@"query"] firstChildWithName:@"virtualmachine"] valueForAttribute:@"jid"];
        [[TNViewLog sharedLogger] log:@"sucessfully create a virtual machine"];
    }
    else
    {
        [CPAlert alertWithTitle:@"Error" message:@"Unable to create virtual machine" style:CPCriticalAlertStyle];
        [[TNViewLog sharedLogger] log:@"error during creation a virtual machine"];
    }
}

- (IBAction) deleteVirtualMachine:(id)sender
{
    if (([[self tableVirtualMachines] numberOfRows] == 0) || ([[self tableVirtualMachines] numberOfSelectedRows] <= 0))
    {
         [CPAlert alertWithTitle:@"Error" message:@"You must select a virtual machine"];
         return;
    }
    
    var selectedIndex                       = [[[self tableVirtualMachines] selectedRowIndexes] firstIndex];
    _virtualMachineRegistredForDeletion     = [[[self virtualMachinesDatasource] VMs] objectAtIndex:selectedIndex];
    
    var alert = [[CPAlert alloc] init];
    
    [buttonDeleteVM setEnabled:NO];
    
    [alert setDelegate:self];
    [alert setTitle:@"Destroying a Virtual Machine"];
    [alert setMessageText:@"Are you sure you want to completely remove this virtual machine ?"];
    [alert setWindowStyle:CPHUDBackgroundWindowMask];
    [alert addButtonWithTitle:@"Yes"];
    [alert addButtonWithTitle:@"No"];
    [alert runModal];
}

- (void)alertDidEnd:(CPAlert)theAlert returnCode:(int)returnCode 
{
    if (returnCode == 0)
    {
        var vm              = _virtualMachineRegistredForDeletion;
        var freeStanza      = [TNStropheStanza iqWithAttributes:{"type" : TNArchipelTypeHypervisorControl}];
        
        [freeStanza addChildName:@"query" withAttributes:{"type" : TNArchipelTypeHypervisorControlFree}];
        [freeStanza addTextNode:[vm jid]];
        
        [[self roster] removeContact:[vm jid]];
        
        [[self entity] sendStanza:freeStanza andRegisterSelector:@selector(didFreeVirtualMachine:) ofObject:self];
    }
    else
    {
        _virtualMachineRegistredForDeletion = Nil;
        [buttonDeleteVM setEnabled:YES];
    }
}

- (void)didFreeVirtualMachine:(id)aStanza
{
    [buttonDeleteVM setEnabled:YES];
    _virtualMachineRegistredForDeletion = Nil;
    if ([aStanza getType] == @"success")
    {
        [[TNViewLog sharedLogger] log:@"sucessfully deallocating a virtual machine"];
        [self getHypervisorRoster];
    }
    else
    {
        [CPAlert alertWithTitle:@"Error" message:@"Unable to free virtual machine" style:CPCriticalAlertStyle];
        [[TNViewLog sharedLogger] log:@"error during free a virtual machine"];
    }
}

@end


