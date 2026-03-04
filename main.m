//
//  main.m
//  SmallCal
//
//  Calendar app for GNUstep: .ics files and CalDAV. Uses SmallStepLib for lifecycle and file dialogs.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "AppDelegate.h"
#import "SSAppDelegate.h"
#import "SSHostApplication.h"

int main(int argc, const char *argv[]) {
#if defined(GNUSTEP) && !__has_feature(objc_arc)
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
#endif
    id<SSAppDelegate> delegate = [[AppDelegate alloc] init];
    [SSHostApplication runWithDelegate:delegate];
#if defined(GNUSTEP) && !__has_feature(objc_arc)
    [delegate release];
    [pool release];
#endif
    return 0;
}
