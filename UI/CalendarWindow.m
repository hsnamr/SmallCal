//
//  CalendarWindow.m
//  SmallCal
//

#import "CalendarWindow.h"
#import "SSWindowStyle.h"
#import "SSFileDialog.h"
#import "ICalEvent.h"
#import "ICalParser.h"
#import "CalDAVClient.h"

#if defined(GNUSTEP) && !defined(NSAlertDefaultReturn)
#define NSAlertDefaultReturn 1
#define NSAlertAlternateReturn 0
#endif

static const CGFloat kMargin = 12.0;
static const CGFloat kButtonH = 28.0;

@interface CalendarWindow () <NSTableViewDataSource, NSTableViewDelegate>
@end

@implementation CalendarWindow

- (instancetype)init {
    NSUInteger style = [SSWindowStyle standardWindowMask];
    NSRect frame = NSMakeRect(120, 120, 720, 480);
    self = [super initWithContentRect:frame
                            styleMask:style
                              backing:NSBackingStoreBuffered
                                defer:NO];
    if (self) {
        [self setTitle:@"SmallCal"];
        [self setReleasedWhenClosed:NO];
        _events = [[NSMutableArray alloc] init];
        _documentPath = nil;
        _documentDirty = NO;
        _caldavURL = nil;
        _caldavUsername = nil;
        _caldavPassword = nil;
        [self buildContent];
    }
    return self;
}

#if defined(GNUSTEP) && !__has_feature(objc_arc)
- (void)dealloc {
    [_eventTable release];
    [_tableScroll release];
    [_addButton release];
    [_refreshButton release];
    [_detailView release];
    [_detailScroll release];
    [_events release];
    [_documentPath release];
    [_caldavURL release];
    [_caldavUsername release];
    [_caldavPassword release];
    [super dealloc];
}
#endif

- (void)buildContent {
    NSView *content = [self contentView];
    NSRect bounds = [content bounds];
    CGFloat topY = bounds.size.height - kMargin - kButtonH;

    _addButton = [[NSButton alloc] initWithFrame:NSMakeRect(kMargin, topY, 90, kButtonH)];
    [_addButton setTitle:@"Add Event"];
    [_addButton setButtonType:NSMomentaryPushInButton];
    [_addButton setBezelStyle:NSRoundedBezelStyle];
    [_addButton setTarget:self];
    [_addButton setAction:@selector(addEvent)];
    [_addButton setAutoresizingMask:NSViewMinYMargin];
    [content addSubview:_addButton];

    _refreshButton = [[NSButton alloc] initWithFrame:NSMakeRect(kMargin + 98, topY, 80, kButtonH)];
    [_refreshButton setTitle:@"Refresh"];
    [_refreshButton setButtonType:NSMomentaryPushInButton];
    [_refreshButton setBezelStyle:NSRoundedBezelStyle];
    [_refreshButton setTarget:self];
    [_refreshButton setAction:@selector(refreshCalDAV)];
    [_refreshButton setAutoresizingMask:NSViewMinYMargin];
    [_refreshButton setEnabled:NO];
    [content addSubview:_refreshButton];

    CGFloat tableWidth = 280;
    CGFloat tableTop = topY - kMargin - kButtonH;
    _tableScroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(kMargin, kMargin, tableWidth, tableTop - kMargin)];
    [_tableScroll setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [_tableScroll setHasVerticalScroller:YES];
    [_tableScroll setBorderType:NSBezelBorder];

    _eventTable = [[NSTableView alloc] initWithFrame:NSZeroRect];
    NSTableColumn *colSummary = [[NSTableColumn alloc] initWithIdentifier:@"summary"];
    [colSummary setTitle:@"Event"];
    [colSummary setWidth:120];
    NSTableColumn *colDate = [[NSTableColumn alloc] initWithIdentifier:@"date"];
    [colDate setTitle:@"Start"];
    [colDate setWidth:140];
    [_eventTable addTableColumn:colSummary];
    [_eventTable addTableColumn:colDate];
#if defined(GNUSTEP) && !__has_feature(objc_arc)
    [colSummary release];
    [colDate release];
#endif
    [_eventTable setDataSource:self];
    [_eventTable setDelegate:self];
    [_eventTable setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [_tableScroll setDocumentView:_eventTable];
    [content addSubview:_tableScroll];

    CGFloat detailX = kMargin + tableWidth + kMargin;
    _detailScroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(detailX, kMargin, bounds.size.width - detailX - kMargin, tableTop - kMargin)];
    [_detailScroll setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [_detailScroll setHasVerticalScroller:YES];
    [_detailScroll setBorderType:NSBezelBorder];
    _detailView = [[NSTextView alloc] initWithFrame:NSZeroRect];
    [_detailView setEditable:NO];
    [_detailView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [_detailScroll setDocumentView:_detailView];
    [content addSubview:_detailScroll];

#if defined(GNUSTEP) && !__has_feature(objc_arc)
    [_eventTable release];
    [_tableScroll release];
    [_addButton release];
    [_refreshButton release];
    [_detailView release];
    [_detailScroll release];
#endif
}

- (void)updateTitle {
    NSString *name = _documentPath ? [_documentPath lastPathComponent] : @"SmallCal";
    if (_caldavURL) name = [NSString stringWithFormat:@"%@ (CalDAV)", name];
    if (_documentDirty) name = [name stringByAppendingString:@" *"];
    [self setTitle:name];
}

- (void)reloadEvents {
    [_eventTable reloadData];
    [self updateTitle];
}

- (void)openICS {
    SSFileDialog *dialog = [SSFileDialog openDialog];
    [dialog setAllowedFileTypes:[NSArray arrayWithObjects:@"ics", nil]];
    NSArray *urls = [dialog showModal];
    if (!urls || [urls count] == 0) return;
    NSURL *url = [urls objectAtIndex:0];
    NSString *path = [url path];
    if (!path || [path length] == 0) return;
    NSArray *loaded = [ICalParser eventsFromICSFile:path];
    if (!loaded) return;
    [_events removeAllObjects];
    [_events addObjectsFromArray:loaded];
#if defined(GNUSTEP) && !__has_feature(objc_arc)
    [_documentPath release];
    _documentPath = [path copy];
#else
    _documentPath = [path copy];
#endif
    _documentDirty = NO;
    _caldavURL = nil;
    _caldavUsername = nil;
    _caldavPassword = nil;
    [_refreshButton setEnabled:NO];
    [self reloadEvents];
}

- (void)saveICS {
    if (_documentPath && [_documentPath length] > 0) {
        if ([ICalParser writeEvents:_events toFile:_documentPath]) {
            _documentDirty = NO;
            [self updateTitle];
        }
        return;
    }
    [self saveICSAs];
}

- (void)saveICSAs {
    SSFileDialog *dialog = [SSFileDialog saveDialog];
    [dialog setAllowedFileTypes:[NSArray arrayWithObjects:@"ics", nil]];
    NSArray *urls = [dialog showModal];
    if (!urls || [urls count] == 0) return;
    NSURL *url = [urls objectAtIndex:0];
    NSString *path = [url path];
    if (!path || [path length] == 0) return;
    if (![[path pathExtension] length])
        path = [path stringByAppendingPathExtension:@"ics"];
    if ([ICalParser writeEvents:_events toFile:path]) {
#if defined(GNUSTEP) && !__has_feature(objc_arc)
        [_documentPath release];
        _documentPath = [path copy];
#else
        _documentPath = [path copy];
#endif
        _documentDirty = NO;
        [self updateTitle];
    }
}

- (void)openCalDAV {
    NSRect frame = NSMakeRect(0, 0, 400, 160);
    NSPanel *panel = [[NSPanel alloc] initWithContentRect:frame
                                                styleMask:(NSTitledWindowMask | NSClosableWindowMask)
                                                  backing:NSBackingStoreBuffered
                                                    defer:NO];
    [panel setTitle:@"Open CalDAV Calendar"];
    NSView *root = [panel contentView];

    CGFloat y = frame.size.height - 24;
    NSTextField *urlLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(12, y - 18, 80, 18)];
    [urlLabel setStringValue:@"Calendar URL:"];
    [urlLabel setEditable:NO];
    [urlLabel setBordered:NO];
    [urlLabel setDrawsBackground:NO];
    [root addSubview:urlLabel];
    NSTextField *urlField = [[NSTextField alloc] initWithFrame:NSMakeRect(100, y - 20, 288, 22)];
    [urlField setPlaceholderString:@"https://server/caldav/user/calendar/"];
    [urlField setTag:100];
    [root addSubview:urlField];

    y -= 36;
    NSTextField *userLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(12, y - 18, 80, 18)];
    [userLabel setStringValue:@"Username:"];
    [userLabel setEditable:NO];
    [userLabel setBordered:NO];
    [userLabel setDrawsBackground:NO];
    [root addSubview:userLabel];
    NSTextField *userField = [[NSTextField alloc] initWithFrame:NSMakeRect(100, y - 20, 288, 22)];
    [userField setTag:101];
    [root addSubview:userField];

    y -= 36;
    NSTextField *passLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(12, y - 18, 80, 18)];
    [passLabel setStringValue:@"Password:"];
    [passLabel setEditable:NO];
    [passLabel setBordered:NO];
    [passLabel setDrawsBackground:NO];
    [root addSubview:passLabel];
    NSSecureTextField *passField = [[NSSecureTextField alloc] initWithFrame:NSMakeRect(100, y - 20, 288, 22)];
    [passField setTag:102];
    [root addSubview:passField];

    y -= 44;
    NSButton *okButton = [[NSButton alloc] initWithFrame:NSMakeRect(220, y, 80, 28)];
    [okButton setTitle:@"Open"];
    [okButton setButtonType:NSMomentaryPushInButton];
    [okButton setBezelStyle:NSRoundedBezelStyle];
    [okButton setKeyEquivalent:@"\r"];
    [okButton setTarget:self];
    [okButton setAction:@selector(calDAVPanelOK:)];
    NSButton *cancelButton = [[NSButton alloc] initWithFrame:NSMakeRect(308, y, 80, 28)];
    [cancelButton setTitle:@"Cancel"];
    [cancelButton setButtonType:NSMomentaryPushInButton];
    [cancelButton setBezelStyle:NSRoundedBezelStyle];
    [cancelButton setKeyEquivalent:@"\e"];
    [cancelButton setTarget:self];
    [cancelButton setAction:@selector(calDAVPanelCancel:)];
    [root addSubview:okButton];
    [root addSubview:cancelButton];

    [panel makeFirstResponder:urlField];
    NSInteger result = [NSApp runModalForWindow:panel];
    [panel orderOut:nil];

    NSString *urlStr = nil;
    if (result == NSAlertDefaultReturn) {
        NSTextField *uf = (NSTextField *)[root viewWithTag:100];
        NSTextField *un = (NSTextField *)[root viewWithTag:101];
        NSSecureTextField *pf = (NSSecureTextField *)[root viewWithTag:102];
        urlStr = [uf stringValue];
        urlStr = [urlStr stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([urlStr length] > 0) {
#if defined(GNUSTEP) && !__has_feature(objc_arc)
            [_caldavURL release];
            [_caldavUsername release];
            [_caldavPassword release];
#endif
            _caldavURL = [urlStr copy];
            _caldavUsername = [[un stringValue] copy];
            _caldavPassword = [[pf stringValue] copy];
            _documentPath = nil;
            [_refreshButton setEnabled:YES];
            [self refreshCalDAV];
        }
    }
#if defined(GNUSTEP) && !__has_feature(objc_arc)
    [panel release];
    [urlLabel release];
    [urlField release];
    [userLabel release];
    [userField release];
    [passLabel release];
    [passField release];
    [okButton release];
    [cancelButton release];
#endif
}

- (void)calDAVPanelOK:(id)sender {
    [NSApp stopModalWithCode:NSAlertDefaultReturn];
}

- (void)calDAVPanelCancel:(id)sender {
    (void)sender;
    [NSApp stopModalWithCode:NSAlertAlternateReturn];
}

- (void)refreshCalDAV {
    if (!_caldavURL || [_caldavURL length] == 0) return;
    CalDAVClient *client = [[CalDAVClient alloc] init];
    [client setBaseURL:_caldavURL];
    [client setUsername:_caldavUsername];
    [client setPassword:_caldavPassword];
    NSCalendar *cal = [NSCalendar currentCalendar];
    NSDate *now = [NSDate date];
    NSDateComponents *oneYear = [[NSDateComponents alloc] init];
    [oneYear setYear:1];
    NSDate *end = [cal dateByAddingComponents:oneYear toDate:now options:0];
#if defined(GNUSTEP) && !__has_feature(objc_arc)
    [oneYear release];
#endif
    NSString *err = nil;
    NSArray *fetched = [client fetchEventsFrom:now to:end error:&err];
#if defined(GNUSTEP) && !__has_feature(objc_arc)
    [client release];
#endif
    if (err) {
        [_detailView setString:[NSString stringWithFormat:@"CalDAV error: %@", err]];
        return;
    }
    [_events removeAllObjects];
    if ([fetched count])
        [_events addObjectsFromArray:fetched];
    _documentDirty = NO;
    [self reloadEvents];
}

- (void)addEvent {
    NSRect frame = NSMakeRect(0, 0, 380, 200);
    NSPanel *panel = [[NSPanel alloc] initWithContentRect:frame
                                                styleMask:(NSTitledWindowMask | NSClosableWindowMask)
                                                  backing:NSBackingStoreBuffered
                                                    defer:NO];
    [panel setTitle:@"Add Event"];
    NSView *root = [panel contentView];

    CGFloat y = frame.size.height - 24;
    NSTextField *sumLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(12, y - 18, 70, 18)];
    [sumLabel setStringValue:@"Summary:"];
    [sumLabel setEditable:NO];
    [sumLabel setBordered:NO];
    [sumLabel setDrawsBackground:NO];
    [root addSubview:sumLabel];
    NSTextField *sumField = [[NSTextField alloc] initWithFrame:NSMakeRect(90, y - 20, 278, 22)];
    [sumField setTag:200];
    [root addSubview:sumField];

    y -= 36;
    NSTextField *startLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(12, y - 18, 70, 18)];
    [startLabel setStringValue:@"Start:"];
    [startLabel setEditable:NO];
    [startLabel setBordered:NO];
    [startLabel setDrawsBackground:NO];
    [root addSubview:startLabel];
    NSDatePicker *startPicker = [[NSDatePicker alloc] initWithFrame:NSMakeRect(90, y - 24, 278, 22)];
    [startPicker setTag:201];
    [startPicker setDatePickerElements:NSYearMonthDayDatePickerElementFlag | NSHourMinuteDatePickerElementFlag];
    [startPicker setDateValue:[NSDate date]];
    [root addSubview:startPicker];

    y -= 36;
    NSTextField *endLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(12, y - 18, 70, 18)];
    [endLabel setStringValue:@"End:"];
    [endLabel setEditable:NO];
    [endLabel setBordered:NO];
    [endLabel setDrawsBackground:NO];
    [root addSubview:endLabel];
    NSDate *endDefault = [NSDate dateWithTimeIntervalSinceNow:3600];
    NSDatePicker *endPicker = [[NSDatePicker alloc] initWithFrame:NSMakeRect(90, y - 24, 278, 22)];
    [endPicker setTag:202];
    [endPicker setDatePickerElements:NSYearMonthDayDatePickerElementFlag | NSHourMinuteDatePickerElementFlag];
    [endPicker setDateValue:endDefault];
    [root addSubview:endPicker];

    y -= 44;
    NSButton *okBtn = [[NSButton alloc] initWithFrame:NSMakeRect(200, y, 80, 28)];
    [okBtn setTitle:@"Add"];
    [okBtn setButtonType:NSMomentaryPushInButton];
    [okBtn setBezelStyle:NSRoundedBezelStyle];
    [okBtn setKeyEquivalent:@"\r"];
    [okBtn setTarget:self];
    [okBtn setAction:@selector(addEventPanelOK:)];
    NSButton *cancelBtn = [[NSButton alloc] initWithFrame:NSMakeRect(288, y, 80, 28)];
    [cancelBtn setTitle:@"Cancel"];
    [cancelBtn setButtonType:NSMomentaryPushInButton];
    [cancelBtn setBezelStyle:NSRoundedBezelStyle];
    [cancelBtn setKeyEquivalent:@"\e"];
    [cancelBtn setTarget:self];
    [cancelBtn setAction:@selector(addEventPanelCancel:)];
    [root addSubview:okBtn];
    [root addSubview:cancelBtn];

    [panel makeFirstResponder:sumField];
    NSInteger result = [NSApp runModalForWindow:panel];
    [panel orderOut:nil];

    if (result == NSAlertDefaultReturn) {
        NSTextField *sumF = (NSTextField *)[root viewWithTag:200];
        NSDatePicker *startP = (NSDatePicker *)[root viewWithTag:201];
        NSDatePicker *endP = (NSDatePicker *)[root viewWithTag:202];
        NSString *summary = [sumF stringValue];
        if (!summary) summary = @"";
        summary = [summary stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSDate *start = [startP dateValue];
        NSDate *endDate = [endP dateValue];
        if ([endDate timeIntervalSinceDate:start] <= 0)
            endDate = [NSDate dateWithTimeInterval:3600 sinceDate:start];
        ICalEvent *ev = [ICalEvent eventWithSummary:summary start:start end:endDate];
        [_events addObject:ev];
        _documentDirty = YES;
        [self reloadEvents];
    }

#if defined(GNUSTEP) && !__has_feature(objc_arc)
    [panel release];
    [sumLabel release];
    [sumField release];
    [startLabel release];
    [startPicker release];
    [endLabel release];
    [endPicker release];
    [okBtn release];
    [cancelBtn release];
#endif
}

- (void)addEventPanelOK:(id)sender {
    (void)sender;
    [NSApp stopModalWithCode:NSAlertDefaultReturn];
}

- (void)addEventPanelCancel:(id)sender {
    (void)sender;
    [NSApp stopModalWithCode:NSAlertAlternateReturn];
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    (void)tableView;
    return (NSInteger)[_events count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (row < 0 || (NSUInteger)row >= [_events count]) return @"";
    ICalEvent *ev = [_events objectAtIndex:(NSUInteger)row];
    if ([[tableColumn identifier] isEqualToString:@"summary"])
        return [ev summary] ? [ev summary] : @"(no title)";
    if ([[tableColumn identifier] isEqualToString:@"date"]) {
        NSDate *d = [ev startDate];
        if (!d) return @"";
        NSDateFormatter *f = [[NSDateFormatter alloc] init];
        [f setDateStyle:NSDateFormatterShortStyle];
        [f setTimeStyle:[ev allDay] ? NSDateFormatterNoStyle : NSDateFormatterShortStyle];
        NSString *s = [f stringFromDate:d];
#if defined(GNUSTEP) && !__has_feature(objc_arc)
        [f release];
#endif
        return s;
    }
    return @"";
}

#pragma mark - NSTableViewDelegate

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    NSTableView *tv = [notification object];
    NSInteger row = [tv selectedRow];
    if (row < 0 || (NSUInteger)row >= [_events count]) {
        [_detailView setString:@""];
        return;
    }
    ICalEvent *ev = [_events objectAtIndex:(NSUInteger)row];
    NSMutableString *text = [NSMutableString string];
    if ([[ev summary] length]) [text appendFormat:@"%@\n\n", [ev summary]];
    if ([ev startDate]) {
        NSDateFormatter *f = [[NSDateFormatter alloc] init];
        [f setDateStyle:NSDateFormatterLongStyle];
        [f setTimeStyle:[ev allDay] ? NSDateFormatterNoStyle : NSDateFormatterShortStyle];
        [text appendFormat:@"Start: %@\n", [f stringFromDate:[ev startDate]]];
#if defined(GNUSTEP) && !__has_feature(objc_arc)
        [f release];
#endif
    }
    if ([ev endDate]) {
        NSDateFormatter *f = [[NSDateFormatter alloc] init];
        [f setDateStyle:NSDateFormatterLongStyle];
        [f setTimeStyle:[ev allDay] ? NSDateFormatterNoStyle : NSDateFormatterShortStyle];
        [text appendFormat:@"End: %@\n", [f stringFromDate:[ev endDate]]];
#if defined(GNUSTEP) && !__has_feature(objc_arc)
        [f release];
#endif
    }
    if ([[ev eventDescription] length]) [text appendFormat:@"\n%@", [ev eventDescription]];
    [_detailView setString:text];
}

@end
