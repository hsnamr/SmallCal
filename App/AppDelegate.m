//
//  AppDelegate.m
//  SmallCal
//

#import "AppDelegate.h"
#import "CalendarWindow.h"
#import "SSMainMenu.h"
#import "SSHostApplication.h"
#import "SSWindowStyle.h"

@implementation AppDelegate

- (void)applicationWillFinishLaunching {
    [self buildMenu];
}

- (void)applicationDidFinishLaunching {
    _mainWindow = [[CalendarWindow alloc] init];
    [_mainWindow makeKeyAndOrderFront:nil];
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(id)sender {
    (void)sender;
    return YES;
}

- (void)buildMenu {
#if !TARGET_OS_IPHONE
    SSMainMenu *menu = [[SSMainMenu alloc] init];
    [menu setAppName:@"SmallCal"];
    NSArray *items = [NSArray arrayWithObjects:
        [SSMainMenuItem itemWithTitle:@"Open .ics…" action:@selector(openICS:) keyEquivalent:@"o" modifierMask:NSCommandKeyMask target:self],
        [SSMainMenuItem itemWithTitle:@"Open CalDAV…" action:@selector(openCalDAV:) keyEquivalent:@"" modifierMask:0 target:self],
        [SSMainMenuItem itemWithTitle:@"Save" action:@selector(saveICS:) keyEquivalent:@"s" modifierMask:NSCommandKeyMask target:self],
        [SSMainMenuItem itemWithTitle:@"Save As…" action:@selector(saveICSAs:) keyEquivalent:@"" modifierMask:0 target:self],
        [SSMainMenuItem itemWithTitle:@"Add Event…" action:@selector(addEvent:) keyEquivalent:@"n" modifierMask:NSCommandKeyMask target:self],
        [SSMainMenuItem itemWithTitle:@"Refresh" action:@selector(refreshCalDAV:) keyEquivalent:@"r" modifierMask:NSCommandKeyMask target:self],
        nil];
    [menu buildMenuWithItems:items quitTitle:@"Quit SmallCal" quitKeyEquivalent:@"q"];
    [menu install];
#if defined(GNUSTEP) && !__has_feature(objc_arc)
    [menu release];
#endif
#endif
}

- (void)openICS:(id)sender {
    (void)sender;
    [_mainWindow openICS];
}

- (void)openCalDAV:(id)sender {
    (void)sender;
    [_mainWindow openCalDAV];
}

- (void)saveICS:(id)sender {
    (void)sender;
    [_mainWindow saveICS];
}

- (void)saveICSAs:(id)sender {
    (void)sender;
    [_mainWindow saveICSAs];
}

- (void)addEvent:(id)sender {
    (void)sender;
    [_mainWindow addEvent];
}

- (void)refreshCalDAV:(id)sender {
    (void)sender;
    [_mainWindow refreshCalDAV];
}

#if defined(GNUSTEP) && !__has_feature(objc_arc)
- (void)dealloc {
    [_mainWindow release];
    [super dealloc];
}
#endif

@end
