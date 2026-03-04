//
//  ICalEvent.h
//  SmallCal
//
//  Simple calendar event model (VEVENT).
//

#import <Foundation/Foundation.h>

@interface ICalEvent : NSObject
{
    NSString *_uid;
    NSString *_summary;
    NSString *_eventDescription;
    NSDate *_startDate;
    NSDate *_endDate;
    BOOL _allDay;
}

@property (nonatomic, copy) NSString *uid;
@property (nonatomic, copy) NSString *summary;
@property (nonatomic, copy) NSString *eventDescription;
@property (nonatomic, retain) NSDate *startDate;
@property (nonatomic, retain) NSDate *endDate;
@property (nonatomic, assign) BOOL allDay;

+ (instancetype)eventWithSummary:(NSString *)summary start:(NSDate *)start end:(NSDate *)end;

@end
