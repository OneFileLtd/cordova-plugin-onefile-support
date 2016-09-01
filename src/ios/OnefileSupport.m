
#import "NSData+Base64Additions.h"
#import "OnefileSupport.h"

@interface OnefileSupport ()
{
    NSString *_ticketDescription;
    NSString *_ticketNumber;
    NSString *_contactDetails;
    NSString *_sessionToken;
    NSString *_endpoint;
    NSString *_device;
    NSArray *_files;
}

@property (nonatomic, retain) NSString *ticketDescription;
@property (nonatomic, retain) NSString *ticketNumber;
@property (nonatomic, retain) NSString *contactDetails;
@property (nonatomic, retain) NSString *sessionToken;
@property (nonatomic, retain) NSString *endpoint;
@property (nonatomic, retain) NSString *device;
@property (nonatomic, retain) NSArray *files;
@end

@implementation OnefileSupport

@synthesize ticketDescription = _ticketDescription;
@synthesize ticketNumber = ticketNumber;
@synthesize contactDetails = _contactDetails;
@synthesize sessionToken = _sessionToken;
@synthesize endpoint = _endpoint;
@synthesize device = _device;
@synthesize files = _files;

- (void)pluginInitialize
{
    NSLog(@"OnefileSupport - pluginInitialize");
    self.inUse = NO;
}

// ----------------------------------
// -- ENTRY POINT FROM JAVA SCRIPT --
// ----------------------------------
- (void)onefileSupport:(CDVInvokedUrlCommand*)command
{
    NSLog(@"OnefileSupport - (void)onefileSupport:(CDVInvokedUrlCommand*)command");

    NSString *callbackId = command.callbackId;
    NSDictionary *options = [command argumentAtIndex:0];

    if ([options isKindOfClass:[NSNull class]]) {
        options = [NSDictionary dictionary];
    }

    self.ticketDescription = [options objectForKey:@"ticketDescription"];
    self.contactDetails = [options objectForKey:@"contactDetails"];
    self.sessionToken = [options objectForKey:@"sessionToken"];
    self.endpoint = [options objectForKey:@"endpoint"];
    self.device = [options objectForKey:@"device"];
    self.files = [options objectForKey:@"files"];
    NSLog(@"ticketDescription: %@",self.ticketDescription);
    NSLog(@"contactDetails: %@",self.contactDetails);
    NSLog(@"sessionToken: %@",self.sessionToken);
    NSLog(@"endpoint: %@",self.endpoint);
    NSLog(@"device: %@",self.device);
    NSLog(@"files: %@",self.files);

    CDVPluginResult* result = nil;

    if (result) {
        [self.commandDelegate sendPluginResult:result callbackId:callbackId];
    }
}

- (void)uploadSupport
{
    NSData *data = [[NSFileManager defaultManager] contentsAtPath:self.files[0]];
    NSString *zipFileDataBase64 = [data encodeBase64ForData];

    NSURL *url = [NSURL URLWithString:self.endpoint];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];

    NSString *boundary = [NSString stringWithFormat: @"++++ %f ++++", [NSDate timeIntervalSinceReferenceDate]];
    NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary];
    [request addValue:contentType forHTTPHeaderField:@"Content-Type"];
    [request addValue:self.sessionToken forHTTPHeaderField:@"X-SessionID"];

    NSMutableData *body = [NSMutableData data];

    [body appendData:[[NSString stringWithFormat:@"\r\n--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"photo\"; filename=\"%@.jpg\"\r\n", self.files[0]] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[@"Content-Type: application/octet-stream\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[NSData dataWithData:zipFileDataBase64]];

    [body appendData:[[NSString stringWithFormat:@"\r\n--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"Device\"\r\n\r\n%@", self.device] dataUsingEncoding:NSUTF8StringEncoding]];

    [body appendData:[[NSString stringWithFormat:@"\r\n--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"TicketDescription\"\r\n\r\n%@", self.ticketDescription] dataUsingEncoding:NSUTF8StringEncoding]];

    [body appendData:[[NSString stringWithFormat:@"\r\n--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"TicketID\"\r\n\r\n%@", self.ticketNumber] dataUsingEncoding:NSUTF8StringEncoding]];

    [body appendData:[[NSString stringWithFormat:@"\r\n--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"ContactDetails\"\r\n\r\n%@", self.contactDetails] dataUsingEncoding:NSUTF8StringEncoding]];

    [body appendData:[[NSString stringWithFormat:@"\r\n--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];

    [request setHTTPBody:body];

    NSURLResponse *response;
    NSError *error;

    [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
}
@end