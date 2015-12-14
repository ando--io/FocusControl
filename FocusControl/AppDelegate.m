/*
 FocusControl

 
 Copyright (C) 2015  ando.io
 
 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
 
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */


#import "AppDelegate.h"
#import "USBFocusViewController.h"
#import "USBFocusDeviceManager.h"
#import <ORSSerial/ORSSerialPortManager.h>
#import <Carbon/Carbon.h>

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;

@end

@implementation AppDelegate {
   NSMutableArray * temp;
   EventHotKeyRef hotkey_;
   EventHotKeyID hotkeyID;
}

OSStatus GlobalKeyHandler(EventHandlerCallRef nextHandler, EventRef anEvent, void *userData) {
   [[USBFocusDeviceManager sharedUSBFocusDeviceManager] stopAllMoves];
   return noErr;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
   hotkeyID.signature='mhk1';
   hotkeyID.id=1;
   RegisterEventHotKey(0x35, 0, hotkeyID, GetApplicationEventTarget(), 0, &hotkey_);

   EventTypeSpec eventType;
   eventType.eventClass=kEventClassKeyboard;
   eventType.eventKind=kEventHotKeyPressed;
   InstallApplicationEventHandler(&GlobalKeyHandler,1,&eventType,NULL,NULL);
   
   temp = [[NSMutableArray alloc]init];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
   UnregisterEventHotKey(hotkey_);
}

-(void)newDocument:(id) foo {

   NSWindow * window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 300, 300) styleMask:NSTitledWindowMask backing:NSBackingStoreBuffered defer:NO];
   [temp addObject:window];
   USBFocusViewController * ctrl = [[USBFocusViewController alloc] initWithNibName:nil bundle:nil];
   [window setFrame:(NSRect){0,0, ctrl.view.frame.size} display:NO animate:NO];
   window.contentView = ctrl.view;
   [window center];
   [window makeKeyAndOrderFront:NSApp];
}

@end
