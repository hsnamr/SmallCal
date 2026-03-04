//
//  ICalEvent.m
//  SmallCal
//

#import "ICalEvent.h"

@implementation ICalEvent

@synthesize uid = _uid;
@synthesize summary = _summary;
@synthesize eventDescription = _eventDescription;
@synthesize startDate = _startDate;
@synthesize endDate = _endDate;
@synthesize allDay = _allDay;

+ (instancetype)eventWithSummary:(NSString *)summary start:(NSDate *)start end:(NSDate *)end {
    ICalEvent *e = [[ICalEvent alloc] init];
    [e setSummary:summary ? summary : @""];
    [e setStartDate:start];
    [e setEndDate:end];
    [e setUid:[[NSUUID UUID] UUIDString]];
    [e setEventDescription:@""];
    [e setAllDay:NO];
    return e;
}

#if defined(GNUSTEP) && !__has_feature(objc_arc)
- (void)dealloc {
    [_uid release];
    [_summary release];
    [_eventDescription release];
    [_startDate release];
    [_endDate release];
    [super dealloc];
}
#endif

@end
