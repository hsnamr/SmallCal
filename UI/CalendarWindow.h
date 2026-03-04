//
//  CalendarWindow.h
//  SmallCal
//
//  Main calendar window: event list, open/save .ics, CalDAV, add event.
//

#import <AppKit/AppKit.h>

@class ICalEvent;

@interface CalendarWindow : NSWindow
{
    NSTableView *_eventTable;
    NSScrollView *_tableScroll;
    NSButton *_addButton;
    NSButton *_refreshButton;
    NSTextView *_detailView;
    NSScrollView *_detailScroll;
    NSMutableArray *_events;
    NSString *_documentPath;
    BOOL _documentDirty;
    NSString *_caldavURL;
    NSString *_caldavUsername;
    NSString *_caldavPassword;
}

- (void)openICS;
- (void)saveICS;
- (void)saveICSAs;
- (void)openCalDAV;
- (void)addEvent;
- (void)refreshCalDAV;

@end
