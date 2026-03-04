//
//  AppDelegate.h
//  SmallCal
//
//  App lifecycle and menu; creates the main calendar window.
//

#import <Foundation/Foundation.h>
#if !TARGET_OS_IPHONE
#import <AppKit/AppKit.h>
#endif
#import "SSAppDelegate.h"

@class CalendarWindow;

@interface AppDelegate : NSObject <SSAppDelegate>
{
    CalendarWindow *_mainWindow;
}
@end
