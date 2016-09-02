
#import "OnefileSupport.h"

@interface OnefileSupport ()
{
    NSString *_ticketDescription;
    NSString *_ticketNumber;
    NSString *_contactDetails;
    NSString *_sessionToken;
    NSString *_endpoint;
    NSString *_device;
    NSString *_zipPath;
    NSArray *_files;
    NSMutableDictionary *_paths;
}

@property (nonatomic, retain) NSString *ticketDescription;
@property (nonatomic, retain) NSString *ticketNumber;
@property (nonatomic, retain) NSString *contactDetails;
@property (nonatomic, retain) NSString *sessionToken;
@property (nonatomic, retain) NSString *endpoint;
@property (nonatomic, retain) NSString *device;
@property (nonatomic, retain) NSString *zipPath;
@property (nonatomic, retain) NSArray *files;
@property (nonatomic, retain) NSMutableDictionary *paths;
@end

@implementation OnefileSupport

@synthesize ticketDescription = _ticketDescription;
@synthesize ticketNumber = ticketNumber;
@synthesize contactDetails = _contactDetails;
@synthesize sessionToken = _sessionToken;
@synthesize endpoint = _endpoint;
@synthesize device = _device;
@synthesize zipPath = _zipPath;
@synthesize files = _files;
@synthesize paths = _paths;

- (void)pluginInitialize
{
    NSLog(@"OnefileSupport - pluginInitialize");
    self.inUse = NO;
    NSArray *cachePath = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    self.zipPath = [[cachePath objectAtIndex:0] stringByAppendingPathComponent:@"database.zip"];
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
    self.ticketNumber = [options objectForKey:@"ticketID"];
    self.contactDetails = [options objectForKey:@"contactDetails"];
    self.sessionToken = [options objectForKey:@"sessionToken"];
    self.endpoint = [options objectForKey:@"endpoint"];
    self.device = [options objectForKey:@"device"];
    self.files = [options objectForKey:@"files"];
    if(!self.ticketNumber)
        self.ticketNumber = @"";
    NSLog(@"ticketDescription: %@",self.ticketDescription);
    NSLog(@"ticketNumber: %@",self.ticketNumber);
    NSLog(@"contactDetails: %@",self.contactDetails);
    NSLog(@"sessionToken: %@",self.sessionToken);
    NSLog(@"endpoint: %@",self.endpoint);
    NSLog(@"device: %@",self.device);
    NSLog(@"files: %@",self.files);

    [self fetchDatabasePaths];

    CDVPluginResult* result = nil;
    result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageToErrorObject:SUPPORT_ERROR];
    if (result) {
        [self.commandDelegate sendPluginResult:result callbackId:callbackId];
    }
    [self zipFiles];
    [self uploadSupport];
}

-(void)fetchDatabasePaths
{
    if(self.paths)
        [self.paths removeAllObjects];
    else
        self.paths = [[NSMutableDictionary alloc] init];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    NSArray *databasePaths;
    if([paths count] > 0)
    {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSArray *directoryContents = [fileManager subpathsAtPath:[paths objectAtIndex:0]];
        if([directoryContents count] > 0)
        {
            databasePaths = [directoryContents pathsMatchingExtensions:[NSArray arrayWithObjects:@"db", nil]];
        }
        for(NSString *file in self.files)
        {
            for(NSString *path in databasePaths)
            {
                NSString *filename = [path lastPathComponent];
                if(filename && [file isEqualToString:filename])
                {
                    NSString *name = [filename stringByDeletingPathExtension];
                    NSString *fullPath = [NSString stringWithFormat:@"%@/%@", [paths objectAtIndex:0], path];
                    [self.paths setObject:fullPath forKey:name];
                }
            }
        }
    }
    NSLog(@"%@", self.paths);
}

-(void)zipFiles
{
//    if([self.paths count] > 0)
//    {
//        for(NSString *key in self.paths)
//        {
//            NSString *path = [self.paths objectForKey:key];
//            NSLog(@"%@ - %@", path, self.zipPath);
//
//            ZZArchive* newArchive = [[ZZArchive alloc] initWithURL:[NSURL fileURLWithPath:@"/tmp/new.zip"]
//                                                           options:@{ZZOpenOptionsCreateIfMissingKey : @YES}
//                                                             error:nil];
//
//        }
//    }
}

- (void)uploadSupport
{
    NSURLResponse *response;
    NSError *error;

    NSString *filename = @"nomad-server-UAT 2";
    NSData *zipData = [[NSFileManager defaultManager] contentsAtPath: [self.paths objectForKey: filename]];

    NSString *charSet = @"UTF-8";
    NSURL *url = [NSURL URLWithString:self.endpoint];
    NSString *boundary = [NSString stringWithFormat: @"-----%9.0f-----", [NSDate timeIntervalSinceReferenceDate]];

    NSMutableData *body = [NSMutableData data];
    [body appendData:[[NSString stringWithFormat:@"%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"Device\"\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"Content-Type: text/plain; charset=%@\r\n", charSet] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"%@\r\n", self.device] dataUsingEncoding:NSUTF8StringEncoding]];

    [body appendData:[[NSString stringWithFormat:@"%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"TicketDescription\"\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"Content-Type: text/plain; charset=%@\r\n", charSet] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"%@\r\n", self.ticketDescription] dataUsingEncoding:NSUTF8StringEncoding]];

    [body appendData:[[NSString stringWithFormat:@"%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"TicketID\"\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"Content-Type: text/plain; charset=%@\r\n", charSet] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"%@\r\n", self.ticketNumber] dataUsingEncoding:NSUTF8StringEncoding]];

    [body appendData:[[NSString stringWithFormat:@"%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"ContactDetails\"\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"Content-Type: text/plain; charset=%@\r\n", charSet] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"%@\r\n", self.contactDetails] dataUsingEncoding:NSUTF8StringEncoding]];

    [body appendData:[[NSString stringWithFormat:@"%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"File\"; filename=\"%@.zip\"\r\n", filename] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"Content-Type: application/octet-stream\r\n\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[NSData dataWithData: zipData]];
    [body appendData:[[NSString stringWithFormat:@"\r\n%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];

    NSString *postLength = [NSString stringWithFormat:@"%lu", (unsigned long)[body length]];
    NSString *ContentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL: url];

    [request setHTTPMethod:@"POST"];
    [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
    [request setValue:ContentType forHTTPHeaderField:@"Content-Type"];
    [request setValue:self.sessionToken forHTTPHeaderField:@"X-SessionID"];
    [request setHTTPBody:body];

    NSString  *bodyString = [[NSString alloc] initWithData:body encoding:NSUTF8StringEncoding];
    NSLog(@"---- REQUEST ----");
    NSLog(@"%@", request);
    NSLog(@"%@", [request allHTTPHeaderFields]);
    NSLog(@"----- BODY ------");
    NSLog(@"%@", bodyString);
    NSLog(@"-----------------");
    [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    NSLog(@"--- RESPONSE ----");
    NSLog(@"%@", response);
    NSLog(@"---- ERROR ------");
    NSLog(@"%@", error);
}
@end