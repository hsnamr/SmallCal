//
//  ICalParser.h
//  SmallCal
//
//  Parse and write iCalendar (.ics) files (RFC 5545); supports VEVENT.
//

#import <Foundation/Foundation.h>

@class ICalEvent;

@interface ICalParser : NSObject

/// Parse .ics data; returns array of ICalEvent (nil on error).
+ (NSArray *)eventsFromICSData:(NSData *)data;

/// Parse .ics file at path; returns array of ICalEvent (nil on error).
+ (NSArray *)eventsFromICSFile:(NSString *)path;

/// Serialize events to .ics data (VCALENDAR with VEVENTs).
+ (NSData *)icsDataFromEvents:(NSArray *)events;

/// Write events to .ics file; returns YES on success.
+ (BOOL)writeEvents:(NSArray *)events toFile:(NSString *)path;

@end
