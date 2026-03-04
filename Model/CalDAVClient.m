//
//  CalDAVClient.m
//  SmallCal
//
//  CalDAV: REPORT calendar-query with time range; parse multistatus for calendar-data or href then GET.
//

#import "CalDAVClient.h"
#import "ICalEvent.h"
#import "ICalParser.h"

static const char kBase64Chars[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

static NSString *base64Encode(NSData *data) {
    const unsigned char *bytes = [data bytes];
    NSUInteger len = [data length];
    NSMutableString *result = [NSMutableString stringWithCapacity:((len + 2) / 3) * 4];
    NSUInteger i;
    for (i = 0; i < len; i += 3) {
        unsigned int n = (unsigned int)(bytes[i]) << 16;
        if (i + 1 < len) n |= (unsigned int)(bytes[i + 1]) << 8;
        if (i + 2 < len) n |= (unsigned int)(bytes[i + 2]);
        [result appendFormat:@"%c%c%c%c",
            kBase64Chars[(n >> 18) & 63],
            kBase64Chars[(n >> 12) & 63],
            (i + 1 < len) ? kBase64Chars[(n >> 6) & 63] : '=',
            (i + 2 < len) ? kBase64Chars[n & 63] : '='];
    }
    return result;
}

@implementation CalDAVClient

@synthesize baseURL = _baseURL;
@synthesize username = _username;
@synthesize password = _password;

#if defined(GNUSTEP) && !__has_feature(objc_arc)
- (void)dealloc {
    [_baseURL release];
    [_username release];
    [_password release];
    [super dealloc];
}
#endif

static NSMutableURLRequest *requestWithAuth(NSURL *url, NSString *method, NSData *body, NSString *username, NSString *password) {
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url
                                                       cachePolicy:NSURLRequestReloadIgnoringCacheData
                                                   timeoutInterval:30];
    [req setHTTPMethod:method];
    if (body)
        [req setHTTPBody:body];
    if ([username length] && [password length]) {
        NSString *auth = [NSString stringWithFormat:@"%@:%@", username, password];
        NSData *authData = [auth dataUsingEncoding:NSUTF8StringEncoding];
        NSString *b64 = base64Encode(authData);
        if (b64)
            [req setValue:[NSString stringWithFormat:@"Basic %@", b64] forHTTPHeaderField:@"Authorization"];
    }
    return req;
}

static NSString *dateToCalDAVUTCString(NSDate *d) {
    NSCalendar *cal = [NSCalendar currentCalendar];
    NSDateComponents *comp = [cal components:(NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond) fromDate:d];
    return [NSString stringWithFormat:@"%04ld%02ld%02ldT%02ld%02ld%02ldZ",
            (long)[comp year], (long)[comp month], (long)[comp day],
            (long)[comp hour], (long)[comp minute], (long)[comp second]];
}

- (NSArray *)fetchEventsFrom:(NSDate *)start to:(NSDate *)end error:(NSString **)outError {
    if (!_baseURL || [_baseURL length] == 0) {
        if (outError) *outError = @"No calendar URL set";
        return nil;
    }
    NSURL *url = [NSURL URLWithString:_baseURL];
    if (!url || (![[url scheme] isEqualToString:@"http"] && ![[url scheme] isEqualToString:@"https"])) {
        if (outError) *outError = @"Invalid calendar URL";
        return nil;
    }

    NSMutableString *xml = [NSMutableString string];
    [xml appendString:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>"];
    [xml appendString:@"<d:calendar-query xmlns:d=\"DAV:\" xmlns:c=\"urn:ietf:params:xml:ns:caldav\">"];
    [xml appendString:@"<d:prop><d:getetag/><c:calendar-data/></d:prop>"];
    [xml appendString:@"<c:filter>"];
    [xml appendString:@"<c:comp-filter name=\"VCALENDAR\">"];
    [xml appendString:@"<c:comp-filter name=\"VEVENT\">"];
    [xml appendString:@"<c:time-range start=\""];
    [xml appendString:dateToCalDAVUTCString(start)];
    [xml appendString:@"\" end=\""];
    [xml appendString:dateToCalDAVUTCString(end)];
    [xml appendString:@"\"/></c:comp-filter></c:comp-filter></c:filter>"];
    [xml appendString:@"</d:calendar-query>"];

    NSData *body = [xml dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableURLRequest *req = requestWithAuth(url, @"REPORT", body, _username, _password);
    [req setValue:@"application/xml" forHTTPHeaderField:@"Content-Type"];
    [req setValue:@"1" forHTTPHeaderField:@"Depth"];

    NSURLResponse *response = nil;
    NSError *error = nil;
    NSData *data = [NSURLConnection sendSynchronousRequest:req returningResponse:&response error:&error];
    if (error) {
        if (outError) *outError = [error localizedDescription];
        return nil;
    }
    NSHTTPURLResponse *http = (NSHTTPURLResponse *)response;
    if ([http statusCode] != 200 && [http statusCode] != 207) {
        if (outError) *outError = [NSString stringWithFormat:@"CalDAV returned %ld", (long)[http statusCode]];
        return nil;
    }
    if (!data || [data length] == 0) {
        if (outError) *outError = @"Empty response";
        return nil;
    }

    NSMutableArray *events = [NSMutableArray array];
    NSString *respStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
#if defined(GNUSTEP) && !__has_feature(objc_arc)
    [respStr autorelease];
#endif
    // Parse multistatus: look for <c:calendar-data>...</c:calendar-data> or CDATA wrapped
    NSRange searchStart = NSMakeRange(0, [respStr length]);
    for (;;) {
        NSRange r = [respStr rangeOfString:@"calendar-data" options:0 range:searchStart];
        if (r.location == NSNotFound) break;
        NSRange open = [respStr rangeOfString:@">" options:0 range:NSMakeRange(r.location, [respStr length] - r.location)];
        if (open.location == NSNotFound) break;
        NSInteger contentStart = open.location + 1;
        NSRange close = [respStr rangeOfString:@"</" options:0 range:NSMakeRange((NSUInteger)contentStart, [respStr length] - (NSUInteger)contentStart)];
        if (close.location == NSNotFound) break;
        NSString *inner = [respStr substringWithRange:NSMakeRange((NSUInteger)contentStart, close.location - contentStart)];
        if ([inner hasPrefix:@"<![CDATA["]) {
            inner = [inner substringFromIndex:9];
            NSRange cdataEnd = [inner rangeOfString:@"]]>"];
            if (cdataEnd.location != NSNotFound)
                inner = [inner substringToIndex:cdataEnd.location];
        }
        NSData *icsChunk = [inner dataUsingEncoding:NSUTF8StringEncoding];
        NSArray *parsed = [ICalParser eventsFromICSData:icsChunk];
        if ([parsed count])
            [events addObjectsFromArray:parsed];
        searchStart.location = close.location + 2;
        searchStart.length = [respStr length] - searchStart.location;
    }
    return events;
}

@end
