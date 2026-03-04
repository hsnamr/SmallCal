//
//  ICalParser.m
//  SmallCal
//
//  Simple iCalendar parser/writer for VEVENT (RFC 5545). Handles line folding and basic properties.
//

#import "ICalParser.h"
#import "ICalEvent.h"

@implementation ICalParser

static NSArray *unfoldLines(NSString *content) {
    NSMutableArray *lines = [NSMutableArray array];
    NSScanner *scanner = [NSScanner scannerWithString:content];
    [scanner setCharactersToBeSkipped:nil];
    NSCharacterSet *newline = [NSCharacterSet characterSetWithCharactersInString:@"\r\n"];
    for (;;) {
        NSString *line = nil;
        if (![scanner scanUpToCharactersFromSet:newline intoString:&line])
            break;
        [scanner scanCharactersFromSet:newline intoString:NULL];
        while ([scanner scanString:@" " intoString:NULL] || [scanner scanString:@"\t" intoString:NULL]) {
            NSString *cont = nil;
            if ([scanner scanUpToCharactersFromSet:newline intoString:&cont]) {
                line = [line stringByAppendingString:cont];
                [scanner scanCharactersFromSet:newline intoString:NULL];
            }
        }
        if ([line length])
            [lines addObject:line];
    }
    return lines;
}

static NSString *valueForLine(NSString *line) {
    NSRange colon = [line rangeOfString:@":"];
    if (colon.location == NSNotFound) return nil;
    return [line substringFromIndex:colon.location + 1];
}

static NSString *propertyNameForLine(NSString *line) {
    NSRange colon = [line rangeOfString:@":"];
    if (colon.location == NSNotFound) return nil;
    NSString *part = [line substringToIndex:colon.location];
    NSRange semicolon = [part rangeOfString:@";"];
    if (semicolon.location != NSNotFound)
        part = [part substringToIndex:semicolon.location];
    return [part uppercaseString];
}

static NSDate *dateFromICalDateTime(NSString *value) {
    if (!value || [value length] == 0) return nil;
    value = [value stringByReplacingOccurrencesOfString:@"Z" withString:@""];
    value = [value stringByReplacingOccurrencesOfString:@"T" withString:@""];
    if ([value length] == 8) {
        // DATE only: YYYYMMDD
        int y = [[value substringWithRange:NSMakeRange(0, 4)] intValue];
        int m = [[value substringWithRange:NSMakeRange(4, 2)] intValue];
        int d = [[value substringWithRange:NSMakeRange(6, 2)] intValue];
        NSCalendar *cal = [NSCalendar currentCalendar];
        NSDateComponents *comp = [[NSDateComponents alloc] init];
        [comp setYear:y];
        [comp setMonth:m];
        [comp setDay:d];
        [comp setHour:0];
        [comp setMinute:0];
        [comp setSecond:0];
        NSDate *date = [cal dateFromComponents:comp];
#if defined(GNUSTEP) && !__has_feature(objc_arc)
        [comp release];
#endif
        return date;
    }
    if ([value length] >= 14) {
        int y = [[value substringWithRange:NSMakeRange(0, 4)] intValue];
        int mo = [[value substringWithRange:NSMakeRange(4, 2)] intValue];
        int d = [[value substringWithRange:NSMakeRange(6, 2)] intValue];
        int h = [[value substringWithRange:NSMakeRange(8, 2)] intValue];
        int mi = [[value substringWithRange:NSMakeRange(10, 2)] intValue];
        int s = [value length] >= 14 ? [[value substringWithRange:NSMakeRange(12, 2)] intValue] : 0;
        NSCalendar *cal = [NSCalendar currentCalendar];
        NSDateComponents *comp = [[NSDateComponents alloc] init];
        [comp setYear:y];
        [comp setMonth:mo];
        [comp setDay:d];
        [comp setHour:h];
        [comp setMinute:mi];
        [comp setSecond:s];
        NSDate *date = [cal dateFromComponents:comp];
#if defined(GNUSTEP) && !__has_feature(objc_arc)
        [comp release];
#endif
        return date;
    }
    return nil;
}

static NSString *stringFromDateForICS(NSDate *date, BOOL allDay) {
    NSCalendar *cal = [NSCalendar currentCalendar];
    NSDateComponents *comp = [cal components:(NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond) fromDate:date];
    if (allDay)
        return [NSString stringWithFormat:@"%04ld%02ld%02ld",
                (long)[comp year], (long)[comp month], (long)[comp day]];
    return [NSString stringWithFormat:@"%04ld%02ld%02ldT%02ld%02ld%02ld",
            (long)[comp year], (long)[comp month], (long)[comp day],
            (long)[comp hour], (long)[comp minute], (long)[comp second]];
}

+ (NSArray *)eventsFromICSData:(NSData *)data {
    if (!data || [data length] == 0) return [NSArray array];
    NSString *content = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (!content) return nil;
#if defined(GNUSTEP) && !__has_feature(objc_arc)
    [content autorelease];
#endif
    NSArray *lines = unfoldLines(content);
    NSMutableArray *events = [NSMutableArray array];
    NSInteger i = 0;
    while (i < (NSInteger)[lines count]) {
        NSString *line = [lines objectAtIndex:(NSUInteger)i];
        if ([line isEqualToString:@"BEGIN:VEVENT"]) {
            i++;
            ICalEvent *ev = [[ICalEvent alloc] init];
            [ev setSummary:@""];
            [ev setEventDescription:@""];
            [ev setAllDay:NO];
            while (i < (NSInteger)[lines count]) {
                NSString *l = [lines objectAtIndex:(NSUInteger)i];
                if ([l isEqualToString:@"END:VEVENT"]) {
                    i++;
                    [events addObject:ev];
#if defined(GNUSTEP) && !__has_feature(objc_arc)
                    [ev release];
#endif
                    break;
                }
                NSString *name = propertyNameForLine(l);
                NSString *val = valueForLine(l);
                if ([name isEqualToString:@"UID"])
                    [ev setUid:val ? val : @""];
                else if ([name isEqualToString:@"SUMMARY"])
                    [ev setSummary:val ? val : @""];
                else if ([name isEqualToString:@"DESCRIPTION"])
                    [ev setEventDescription:val ? val : @""];
                else if ([name isEqualToString:@"DTSTART"]) {
                    BOOL dateOnly = [l rangeOfString:@"VALUE=DATE"].location != NSNotFound;
                    [ev setAllDay:dateOnly];
                    [ev setStartDate:dateFromICalDateTime(val)];
                } else if ([name isEqualToString:@"DTEND"]) {
                    [ev setEndDate:dateFromICalDateTime(val)];
                }
                i++;
            }
            continue;
        }
        if ([line isEqualToString:@"BEGIN:VCALENDAR"]) {
            i++;
            continue;
        }
        if ([line isEqualToString:@"END:VCALENDAR"])
            break;
        i++;
    }
    return events;
}

+ (NSArray *)eventsFromICSFile:(NSString *)path {
    NSData *data = [NSData dataWithContentsOfFile:path];
    return [self eventsFromICSData:data];
}

+ (NSData *)icsDataFromEvents:(NSArray *)events {
    NSMutableString *out = [NSMutableString string];
    [out appendString:@"BEGIN:VCALENDAR\r\n"];
    [out appendString:@"VERSION:2.0\r\n"];
    [out appendString:@"PRODID:-//SmallCal//EN\r\n"];
    [out appendString:@"CALSCALE:GREGORIAN\r\n"];
    for (ICalEvent *ev in events) {
        [out appendString:@"BEGIN:VEVENT\r\n"];
        [out appendFormat:@"UID:%@\r\n", [ev uid] ? [ev uid] : [[NSUUID UUID] UUIDString]];
        [out appendFormat:@"SUMMARY:%@\r\n", [ev summary] ? [ev summary] : @""];
        if ([[ev eventDescription] length])
            [out appendFormat:@"DESCRIPTION:%@\r\n", [ev eventDescription]];
        if ([ev allDay]) {
            [out appendFormat:@"DTSTART;VALUE=DATE:%@\r\n", stringFromDateForICS([ev startDate], YES)];
            if ([ev endDate])
                [out appendFormat:@"DTEND;VALUE=DATE:%@\r\n", stringFromDateForICS([ev endDate], YES)];
        } else {
            [out appendFormat:@"DTSTART:%@\r\n", stringFromDateForICS([ev startDate], NO)];
            if ([ev endDate])
                [out appendFormat:@"DTEND:%@\r\n", stringFromDateForICS([ev endDate], NO)];
        }
        [out appendString:@"END:VEVENT\r\n"];
    }
    [out appendString:@"END:VCALENDAR\r\n"];
    return [out dataUsingEncoding:NSUTF8StringEncoding];
}

+ (BOOL)writeEvents:(NSArray *)events toFile:(NSString *)path {
    NSData *data = [self icsDataFromEvents:events];
    return data && [data writeToFile:path atomically:YES];
}

@end
