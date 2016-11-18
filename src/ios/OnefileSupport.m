#include <mach/mach.h>
#include <mach/mach_host.h>
#include <mach/vm_statistics.h>

#import "ZKDefs.h"
#import "ZKDataArchive.h"
#import "ZKFileArchive.h"

#import "OnefileSupport.h"

#define GIGABYTE                                ((uint64_t)1073741824)
#define GIGABYTE_1000                           ((uint64_t)1000000000)

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

-(uint64_t)getFreeDiskspace;
-(uint64_t)getDiskspace;
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

    // Addition device information.
    uint64_t free = [self getFreeDiskspace];
    Float64 freeFloat = ((Float64)free / GIGABYTE);
    uint64_t space = [self getDiskspace];
    Float64 spaceFloat = ((Float64)space / GIGABYTE);

    NSString *model = [UIDevice currentDevice].model;
    // NSString *systemName = [UIDevice currentDevice].systemName;
    NSString *systemVersion = [UIDevice currentDevice].systemVersion;
    NSString *versionNumber = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    NSString *buildNumber = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
    NSString *actualDiskSpace = [NSString stringWithFormat:@"%5.2f", (Float64)spaceFloat];
    NSString *freeDiskSpace = [NSString stringWithFormat:@"%5.2f", (Float64)freeFloat];
    NSString *freeMemory = [NSString stringWithFormat:@"%llu", (uint64_t)(logMemUsage)];
    self.ticketDescription = [self.options objectForKey:@"ticketDescription"];
    self.ticketNumber = [self.options objectForKey:@"ticketNumber"];
    self.contactDetails = [self.options objectForKey:@"contactDetails"];
    self.sessionToken = [self.options objectForKey:@"sessionToken"];
    self.endpoint = [self.options objectForKey:@"endpoint"];
    NSString *deviceJS = [self.options objectForKey:@"device"];
    self.files = [self.options objectForKey:@"files"];

    self.device = [NSString stringWithFormat:@"%@\n\nModel: %@\nSystem Version: %@\nVersion Number: %@\nBuild Number: %@\nActual Disk Space: %@\nFree Disk Space: %@\nFree Memory: %@",
                   deviceJS, model, systemVersion, versionNumber, buildNumber, actualDiskSpace, freeDiskSpace, freeMemory];

    if(!self.ticketNumber)
        self.ticketNumber = @"";
    [self fetchDatabasePaths];
    [self zipFiles];
}

static long prevMemUsage = 0;
static long curMemUsage = 0;
static long memUsageDiff = 0;

vm_size_t usedMemory(void) {
    struct task_basic_info info;
    mach_msg_type_number_t size = sizeof(info);
    kern_return_t kerr = task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)&info, &size);
    return (kerr == KERN_SUCCESS) ? info.resident_size : 0; // size in bytes
}

vm_size_t freeMemory(void) {
    mach_port_t host_port = mach_host_self();
    mach_msg_type_number_t host_size = sizeof(vm_statistics_data_t) / sizeof(integer_t);
    vm_size_t pagesize;
    vm_statistics_data_t vm_stat;

    host_page_size(host_port, &pagesize);
    (void) host_statistics(host_port, HOST_VM_INFO, (host_info_t)&vm_stat, &host_size);
    return vm_stat.free_count * pagesize;
}

uint64_t logMemUsage(void) {
    // compute memory usage and log if different by >= 100k
    curMemUsage = usedMemory();
    memUsageDiff = curMemUsage - prevMemUsage;

    if (memUsageDiff > 100000 || memUsageDiff < -100000) {
        prevMemUsage = curMemUsage;
    }
    return curMemUsage;
}

-(uint64_t)getFreeDiskspace
{
    uint64_t totalFreeSpace = 0;
    NSError *error = nil;
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSDictionary *dictionary = [[NSFileManager defaultManager] attributesOfFileSystemForPath:[paths lastObject] error: &error];

    if (dictionary) {
        NSNumber *freeFileSystemSizeInBytes = [dictionary objectForKey:NSFileSystemFreeSize];
        totalFreeSpace = [freeFileSystemSizeInBytes unsignedLongLongValue];
    }
    return totalFreeSpace;
}

-(uint64_t)getDiskspace
{
    uint64_t totalSpace = 0;
    NSError *error = nil;
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSDictionary *dictionary = [[NSFileManager defaultManager] attributesOfFileSystemForPath:[paths lastObject] error: &error];

    if (dictionary) {
        NSNumber *fileSystemSizeInBytes = [dictionary objectForKey: NSFileSystemSize];
        totalSpace = [fileSystemSizeInBytes unsignedLongLongValue];
    }
    return totalSpace;
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
    [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"Device\"\r\n\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"%@\r\n", self.device] dataUsingEncoding:NSUTF8StringEncoding]];

    [body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"TicketDescription\"\r\n\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"%@\r\n", self.ticketDescription] dataUsingEncoding:NSUTF8StringEncoding]];

    [body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"TicketID\"\r\n\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"%@\r\n", self.ticketNumber] dataUsingEncoding:NSUTF8StringEncoding]];

    [body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"ContactDetails\"\r\n\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"%@\r\n", self.contactDetails] dataUsingEncoding:NSUTF8StringEncoding]];

    [body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"File\"; filename=\"%@\"\r\n\r\n", self.zipFilename] dataUsingEncoding:NSUTF8StringEncoding]];

    [body appendData:[NSData dataWithData: zipData]];
    [body appendData:[[NSString stringWithFormat:@"\r\n\r\n--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];

    NSString *postLength = [NSString stringWithFormat:@"%lu", (unsigned long)[body length]];
    NSString *ContentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@; charset=%@", boundary, charSet];

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