#import "ZKDefs.h"
#import "ZKDataArchive.h"
#import "ZKFileArchive.h"

#import "OnefileSupport.h"

typedef enum {
    SUPPORT_ERROR = 0,
} SUPPORT_ERRORS;

@interface OnefileSupport ()
{
    NSURLConnection *_uploadConnection;
    CDVInvokedUrlCommand *_command;
    NSString *_callbackId;
    NSDictionary *_options;

    NSString *_ticketDescription;
    NSString *_ticketNumber;
    NSString *_contactDetails;
    NSString *_sessionToken;
    NSString *_endpoint;
    NSString *_device;
    NSString *_zipFilename;
    NSString *_zipPath;
    NSArray *_files;
    NSMutableArray *_paths;
}

@property (nonatomic, retain) NSURLConnection *uploadConnection;
@property (nonatomic, retain) CDVInvokedUrlCommand *command;
@property (nonatomic, retain) NSString *callbackId;
@property (nonatomic, retain) NSDictionary *options;

@property (nonatomic, retain) NSString *ticketDescription;
@property (nonatomic, retain) NSString *ticketNumber;
@property (nonatomic, retain) NSString *contactDetails;
@property (nonatomic, retain) NSString *sessionToken;
@property (nonatomic, retain) NSString *endpoint;
@property (nonatomic, retain) NSString *device;
@property (nonatomic, retain) NSString *zipFilename;
@property (nonatomic, retain) NSString *zipPath;
@property (nonatomic, retain) NSArray *files;
@property (nonatomic, retain) NSMutableArray *paths;
@end

@implementation OnefileSupport

@synthesize ticketDescription = _ticketDescription;
@synthesize ticketNumber = ticketNumber;
@synthesize contactDetails = _contactDetails;
@synthesize sessionToken = _sessionToken;
@synthesize endpoint = _endpoint;
@synthesize device = _device;
@synthesize zipFilename = _zipFilename;
@synthesize zipPath = _zipPath;
@synthesize files = _files;
@synthesize paths = _paths;

- (void)pluginInitialize
{
    NSLog(@"OnefileSupport - pluginInitialize");
    self.inUse = NO;
    NSArray *cachePath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES); // NSCachesDirectory
    self.zipFilename = @"database.zip";
    self.zipPath = [[cachePath objectAtIndex:0] stringByAppendingPathComponent:self.zipFilename];
}

// ----------------------------------
// -- ENTRY POINT FROM JAVA SCRIPT --
// ----------------------------------
- (void)onefileSupport:(CDVInvokedUrlCommand *)command
{
    NSLog(@"OnefileSupport - (void)onefileSupport:(CDVInvokedUrlCommand*)command");

    self.command = command;
    self.callbackId = command.callbackId;
    self.options = [command argumentAtIndex:0];

    if ([self.options isKindOfClass:[NSNull class]]) {
        self.options = [NSDictionary dictionary];
    }

    self.ticketDescription = [self.options objectForKey:@"ticketDescription"];
    self.ticketNumber = [self.options objectForKey:@"ticketNumber"];
    self.contactDetails = [self.options objectForKey:@"contactDetails"];
    self.sessionToken = [self.options objectForKey:@"sessionToken"];
    self.endpoint = [self.options objectForKey:@"endpoint"];
    self.device = [self.options objectForKey:@"device"];
    self.files = [self.options objectForKey:@"files"];
    if(!self.ticketNumber)
        self.ticketNumber = @"";
    [self fetchDatabasePaths];
    [self zipFiles];
}

// -----------------------------
// -- EXIT POINT FROM PLUG IN --
// -----------------------------
-(void)pluginError:(NSString *)message
{
    CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString: message];
    [self.commandDelegate sendPluginResult:result callbackId:self.callbackId];
}

// -----------------------------
// -- EXIT POINT FROM PLUG IN --
// -----------------------------
-(void)pluginSuccess:(NSDictionary *)jSON
{
    CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary: jSON];
    [self.commandDelegate sendPluginResult:result callbackId:self.callbackId];
}

-(void)fetchDatabasePaths
{
    if(self.paths)
        [self.paths removeAllObjects];
    else
        self.paths = [[NSMutableArray alloc] init];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    NSArray *databasePaths;
    if([paths count] > 0) {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSArray *directoryContents = [fileManager subpathsAtPath:[paths objectAtIndex:0]];
        if([directoryContents count] > 0) {
            databasePaths = [directoryContents pathsMatchingExtensions:[NSArray arrayWithObjects:@"db", nil]];
        }
        for(NSString *file in self.files) {
            for(NSString *path in databasePaths) {
                NSString *filename = [path lastPathComponent];
                if(filename && [file isEqualToString:filename])
                {
                    NSString *fullPath = [NSString stringWithFormat:@"%@/%@", [paths objectAtIndex:0], path];
                    [self.paths addObject: fullPath];
                }
            }
        }
        NSLog(@"%@", self.paths);
    }
    else {
        [self pluginError:@"unable to create path!! "];
    }
}

-(void)zipFiles
{
    NSError *error;
    NSMutableArray *filePaths = [[NSMutableArray alloc] init];
    if([self.paths count] > 0) {
        NSLog(@"%@", filePaths);
        BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:self.zipPath];
        if(fileExists) {
            BOOL success = [[NSFileManager defaultManager] removeItemAtPath:self.zipPath error:&error];
            if(!success)
            {
                [self pluginError:@"error deleting temporary file!! "];
                return;
            }
        }
        ZKFileArchive *fileArchive = [ZKFileArchive archiveWithArchivePath:self.zipPath];
        NSString *basePath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,  NSUserDomainMask, YES) lastObject];

        NSInteger result = [fileArchive deflateFiles:self.paths relativeToPath:basePath usingResourceFork:NO];
        if(result > 0)
            [self uploadSupport];
        else
            [self pluginError:@"error during compression!! "];
    }
    else {
        [self pluginError:@"no databases found!! "];
    }
}

- (void)uploadSupport
{
    NSURLResponse *response;
    NSError *error;

    NSData *zipData = [[NSFileManager defaultManager] contentsAtPath: self.zipPath];

    NSString *charSet = @"UTF-8";
    NSURL *url = [NSURL URLWithString:self.endpoint];
    NSString *boundary = [NSString stringWithFormat: @"++++%9.0f++++", [NSDate timeIntervalSinceReferenceDate]];
    NSMutableData *body = [NSMutableData data];
    [body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"Device\"\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"Content-Type: text/plain; charset=%@\r\n", charSet] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"%@\r\n", self.device] dataUsingEncoding:NSUTF8StringEncoding]];

    [body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"TicketDescription\"\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"Content-Type: text/plain; charset=%@\r\n", charSet] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"%@\r\n", self.ticketDescription] dataUsingEncoding:NSUTF8StringEncoding]];

    [body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"TicketID\"\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"Content-Type: text/plain; charset=%@\r\n", charSet] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"%@\r\n", self.ticketNumber] dataUsingEncoding:NSUTF8StringEncoding]];

    [body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"ContactDetails\"\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"Content-Type: text/plain; charset=%@\r\n", charSet] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"%@\r\n", self.contactDetails] dataUsingEncoding:NSUTF8StringEncoding]];

    [body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"File\"; filename=\"%@\"\r\n", self.zipFilename] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"Content-Type: null\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"Content-Transfer-Encoding: binary\r\n\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[NSData dataWithData: zipData]];
    [body appendData:[[NSString stringWithFormat:@"\r\n\r\n--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];

    NSString *postLength = [NSString stringWithFormat:@"%lu", (unsigned long)[body length]];
    NSString *ContentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary];

    // Create Request
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL: url];
    [request setCachePolicy:NSURLRequestReloadIgnoringCacheData];
    [request setHTTPMethod:@"POST"];
    [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
    [request setValue:ContentType forHTTPHeaderField:@"Content-Type"];
    [request setValue:self.sessionToken forHTTPHeaderField:@"X-SessionID"];
    [request setHTTPBody:body];

    // Send Request
    [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];

    // Process Response
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    if ([response respondsToSelector:@selector(allHeaderFields)]) {
        NSDictionary *jSON = @
        {
            @"status": [NSNumber numberWithInteger:[httpResponse statusCode]],
            @"headers": [httpResponse allHeaderFields]
        };
        NSLog(@"%@", jSON);
        [self pluginSuccess:jSON];
    }
}
@end