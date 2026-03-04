//
//  CalDAVClient.h
//  SmallCal
//
//  Simple CalDAV client: fetch events from a calendar URL via REPORT calendar-query.
//

#import <Foundation/Foundation.h>

@class ICalEvent;

@interface CalDAVClient : NSObject
{
    NSString *_baseURL;
    NSString *_username;
    NSString *_password;
}

@property (nonatomic, copy) NSString *baseURL;
@property (nonatomic, copy) NSString *username;
@property (nonatomic, copy) NSString *password;

/// Fetch events in the given date range. Returns array of ICalEvent or nil on error; error string in outError.
- (NSArray *)fetchEventsFrom:(NSDate *)start to:(NSDate *)end error:(NSString **)outError;

@end
