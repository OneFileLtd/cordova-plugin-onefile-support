#include <mach/mach.h>
#include <mach/mach_host.h>
#include <mach/vm_statistics.h>

#import "ZKDefs.h"
#import "ZKDataArchive.h"
#import "ZKFileArchive.h"

#import "OnefileSupport.h"

#define GIGABYTE                                ((uint64_t)1073741824)
#define GIGABYTE_1000                           ((uint64_t)1000000000)

//#define MAX_SINGLE_FILE_SIZE                    (40000)
//#define MAX_ZIP_FILE_SIZE                       (40000)

#define ZIP_FILENAME                            @"ZipFile%d"
#define EVIDENCE_LOG_FILENAME                   @"evidence-log-file.log"

#define REQUIRED_DISK_SPACE                     (1 * GIGABYTE_1000)

#define eNOT_ENOUGH_DISK_SPACE                  @"Not enough space"
#define eCANT_DELETE_TEMPORARY_FILE             @"error deleting temporary log file!! "
#define eFILE_DOESNT_EXIST                      @"file doesn't exist"
#define eMAX_FILE_SIZE                          @"No valid max file size provided"
#define eMAX_ZIP_FILES                          @"No valid max zip file size"

typedef enum {
    SUPPORT_ERROR = 0,
} SUPPORT_ERRORS;

typedef enum {
    STATUS_ERROR = 0,
    STATUS_SUCCESSFUL
} RECOVER_STATUS;

@interface OnefileSupport ()
{
    NSURLConnection *_uploadConnection;
    CDVInvokedUrlCommand *_command;
    NSString *_callbackId;
    NSDictionary *_options;

	NSString *_username;
	NSString *_password;
	NSString *_selectedServer;

    NSString *_ticketDescription;
    NSString *_ticketNumber;
    NSString *_contactDetails;
    NSString *_sessionToken;
    NSString *_endpoint;
    NSString *_device;
    NSString *_zipFilename;
    NSString *_zipPath;
    NSArray *_files;

    NSString *_documentPath;
    NSString *_cachePath;
    NSString *_libraryPath;

    NSMutableArray *_paths;
    NSString *_authEndpoint;
    NSString *_startEndpoint;
    NSString *_uploadEndpoint;
    NSString *sessionGUID;
    NSString *_maxFileSize;
    NSString *_maxZipFiles;
}

@property (nonatomic, retain) NSURLConnection *uploadConnection;
@property (nonatomic, retain) CDVInvokedUrlCommand *command;
@property (nonatomic, retain) NSString *callbackId;
@property (nonatomic, retain) NSDictionary *options;

@property (nonatomic, retain) NSString *username;
@property (nonatomic, retain) NSString *password;
@property (nonatomic, retain) NSString *selectedServer;

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

@property (nonatomic, retain) NSString *documentPath;
@property (nonatomic, retain) NSString *cachePath;
@property (nonatomic, retain) NSString *libraryPath;

@property (nonatomic, retain) NSString *authEndpoint;
@property (nonatomic, retain) NSString *startEndpoint;
@property (nonatomic, retain) NSString *uploadEndpoint;
@property (nonatomic, retain) NSString *sessionGUID;
@property (nonatomic, retain) NSString *maxFileSize;
@property (nonatomic, retain) NSString *maxZipFiles;

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

@synthesize documentPath = _documentPath;
@synthesize cachePath = cachePath;
@synthesize libraryPath = libraryPath;

@synthesize authEndpoint = _authEndpoint;
@synthesize startEndpoint = _startEndpoint;
@synthesize uploadEndpoint = _uploadEndpoint;
@synthesize sessionGUID = sessionGUID;
@synthesize maxFileSize = _maxFileSize;
@synthesize maxZipFiles = _maxZipFiles;

- (void)pluginInitialize
{
    self.inUse = NO;
    NSArray *docpath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    self.documentPath = [docpath objectAtIndex:0];
    NSArray *cacpath = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    self.cachePath = [cacpath objectAtIndex:0];
    NSArray *libpath = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    self.libraryPath = [libpath objectAtIndex:0];
}

// ----------------------------------
// -- ENTRY POINT FROM JAVA SCRIPT --
// ----------------------------------
- (void)onefileSupport:(CDVInvokedUrlCommand *)command
{
    self.zipFilename = @"database.zip";
    self.zipPath = [self.cachePath stringByAppendingPathComponent:self.zipFilename];
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

- (void)onefileRecover:(CDVInvokedUrlCommand *)command
{
    self.zipFilename = @"evidence.zip";
    self.zipPath = [self.cachePath stringByAppendingPathComponent:self.zipFilename];
    self.command = command;
    self.callbackId = command.callbackId;
    self.options = [command argumentAtIndex:0];

    if ([self.options isKindOfClass:[NSNull class]]) {
        self.options = [NSDictionary dictionary];
    }
    NSLog(@"%@", self.options);
    self.sessionToken = [self.options objectForKey:@"sessionToken"];
    self.username = [self.options objectForKey:@"username"];
    self.password = [self.options objectForKey:@"password"];
    self.ticketNumber = [self.options objectForKey:@"ticketNumber"];
    self.selectedServer = [self.options objectForKey:@"selectedServer"];
    self.authEndpoint = [self.options objectForKey:@"authEndpoint"];
    self.startEndpoint = [self.options objectForKey:@"endpoint"];
    self.uploadEndpoint = [self.options objectForKey:@"endpoint"];
    self.maxFileSize = [self.options objectForKey:@"maxFileSize"];
    self.maxZipFiles = [self.options objectForKey:@"maxZipFiles"];

    if(!self.ticketNumber)
        self.ticketNumber = @"";

    NSData *jSONData = [self createEvidenceLog];
    [self createLogFile: jSONData];
    
    [self startRecovery: jSONData];
    [self zipFilesFromEvidenceLog: jSONData];
    
	NSDictionary *jsonResult = @
	{
		@"status": [NSNumber numberWithInteger:STATUS_SUCCESSFUL],
	};
	[self pluginSuccess:jsonResult];
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

// -------------------------
// -- SUPPORT PLUGIN CODE --
// -------------------------
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
        [self pluginSuccess:jSON];
    }
}


// --------------------------
// -- RECOVERY PLUGIN CODE --
// --------------------------
-(void)fetchDatabasePaths
{
    if(self.paths)
        [self.paths removeAllObjects];
    else
        self.paths = [[NSMutableArray alloc] init];
    NSArray *databasePaths;

    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *directoryContents = [fileManager subpathsAtPath:self.libraryPath];
    if([directoryContents count] > 0) {
        databasePaths = [directoryContents pathsMatchingExtensions:[NSArray arrayWithObjects:@"db", nil]];
    }
    for(NSString *file in self.files) {
        for(NSString *path in databasePaths) {
            NSString *filename = [path lastPathComponent];
            if(filename && [file isEqualToString:filename])
            {
                NSString *fullPath = [NSString stringWithFormat:@"%@/%@", self.libraryPath, path];
                [self.paths addObject: fullPath];
            }
        }
    }
}

-(void)createLogFile:(NSData *)fileContents
{
    NSError *error;
    NSString *logFilePath = [NSString stringWithFormat: @"%@/%@", self.documentPath, EVIDENCE_LOG_FILENAME];
    BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:logFilePath];
    if(fileExists) {
        BOOL success = [[NSFileManager defaultManager] removeItemAtPath:logFilePath error:&error];
        if(!success)
        {
            [self pluginError:eCANT_DELETE_TEMPORARY_FILE];
            return;
        }
    }
    [[NSFileManager defaultManager] createFileAtPath: logFilePath
                                            contents:fileContents
                                          attributes:nil];

    [self.paths addObject:logFilePath];
}

-(NSData *)createEvidenceLog
{
    long long maxFileSize = [self.maxFileSize longLongValue];
    long long maxZipFiles = [self.maxZipFiles longLongValue];
    
    uint64_t space = [self getDiskspace];
    if(space < REQUIRED_DISK_SPACE) {
        [self pluginError: eNOT_ENOUGH_DISK_SPACE];
        return nil;
    }
    if(self.paths)
        [self.paths removeAllObjects];
    else
        self.paths = [[NSMutableArray alloc] init];
    NSError *error;
    NSArray *evidencePaths;
    unsigned long long currentZipSize = 0;
    int zipFileIndex = 0;
    NSUInteger numberOfFilesInZip = 0;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *directoryContents = [fileManager subpathsAtPath: self.documentPath];

    if([directoryContents count] > 0) {
        evidencePaths = [directoryContents pathsMatchingExtensions:[NSArray arrayWithObjects:@"jpg", @"jpeg", @"png", @"wav", @"caf", @"mov", @"mp3", @"mp4", nil]];
    }
    NSMutableArray *zipFiles = [[NSMutableArray alloc] init];
    NSMutableArray *files = [[NSMutableArray alloc] init];
    NSMutableArray *excluded = [[NSMutableArray alloc] init];
    
    for(NSString *path in evidencePaths) {
        NSString *fullPath = [NSString stringWithFormat: @"%@/%@", self.documentPath, path];
        NSString *filePath = [NSString stringWithFormat: @"%@", path];
        NSString *name = [NSString stringWithFormat:@"%@", [path lastPathComponent]];
        BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath: fullPath];
        BOOL inzipfile = false;
        unsigned long long fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:fullPath error:nil] fileSize];
    
        if(fileExists) {
            inzipfile = (fileSize > 0 && fileSize <= maxFileSize && zipFileIndex <= maxZipFiles);
            NSDictionary *file = @{
                                   @"FullPath" : fullPath,
                                   @"Path" : filePath,
                                   @"Name" : name,
                                   @"Size" : [NSNumber numberWithUnsignedInteger: fileSize],
                                   @"InZipFile" : [NSNumber numberWithBool: inzipfile]
                                   };
            if(inzipfile) {
                if((currentZipSize + fileSize) > maxFileSize) {
                    NSDictionary *zipFile = @{
                                           @"Name" : [NSString stringWithFormat: ZIP_FILENAME, zipFileIndex],
                                           @"Size" : [NSNumber numberWithUnsignedInteger: currentZipSize],
                                           @"Files" : [files copy],
                                           @"Count" : [NSNumber numberWithUnsignedInteger: numberOfFilesInZip]
                                           };
                    [zipFiles addObject: zipFile];
                    zipFileIndex++;
                    currentZipSize = 0;
                    numberOfFilesInZip = 0;
                    [files removeAllObjects];
                }
                [files addObject:file];
                numberOfFilesInZip++;
                currentZipSize += fileSize;
            } else {
                // File too big to add to zip or send up, or is zero so no point.
                [excluded addObject: file];
            }
        }
        else
        {
            [self pluginError: eFILE_DOESNT_EXIST];
            return nil;
        }
    }
    if([files count] > 0) {
        NSDictionary *zipFile = @{
                                  @"Name" : [NSString stringWithFormat: ZIP_FILENAME, zipFileIndex],
                                  @"Size" : [NSNumber numberWithUnsignedInteger: currentZipSize],
                                  @"Files" : [files copy],
                                  @"Count" : [NSNumber numberWithUnsignedInteger: numberOfFilesInZip]
                                  };
        [zipFiles addObject: zipFile];
    }
    NSDictionary *logFile = @{
                              @"ExcludedFiles" : excluded,
                              @"TicketID" : self.ticketNumber,
                              @"ZipFiles" : zipFiles
                           };
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject: logFile
                                                       options: NSJSONWritingPrettyPrinted
                                                         error: &error];
    NSString *jSON = [[NSString alloc] initWithData: jsonData encoding: NSUTF8StringEncoding];
    return jsonData;
}

-(void)zipFiles
{
    NSError *error;
    if([self.paths count] > 0) {
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
        NSInteger result = [fileArchive deflateFiles:self.paths relativeToPath:self.libraryPath usingResourceFork:NO];
        if(result > 0) {
            [self uploadSupport];
        }
        else
        [self pluginError:@"error during compression!! "];
    }
    else {
        [self pluginError:@"no databases found!! "];
    }
}

- (void)zipFilesFromEvidenceLog:(NSData *)jSON {
    if(jSON) {
        NSError *error;
        NSArray *jsonArray = [[NSJSONSerialization JSONObjectWithData:jSON options:0 error:&error] objectForKey:@"ZipFiles"];
        if([jsonArray count] > 0) {
            for(NSDictionary *currentZip in jsonArray) {
                NSString *zipPath = [self.documentPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.zip",[currentZip objectForKey:@"Name"]]];
                NSMutableArray *filePaths = [[NSMutableArray alloc] init];
                for(NSDictionary *file in [currentZip objectForKey:@"Files"]) {
                    [filePaths addObject:[file objectForKey:@"FullPath"]];
                }
                NSArray *filesToZip = filePaths;
                BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:zipPath];
                if(fileExists) {
                    BOOL success = [[NSFileManager defaultManager] removeItemAtPath:zipPath error:&error];
                    if(!success)
                    {
                        [self pluginError:@"error deleting temporary zip file!! "];
                        return;
                    }
                }
                ZKFileArchive *fileArchive = [ZKFileArchive archiveWithArchivePath:zipPath];
                NSInteger result = [fileArchive deflateFiles:filesToZip relativeToPath:self.documentPath usingResourceFork:NO];
                if(result > 0) {
                    unsigned long long fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:zipPath error:nil] fileSize];
                    [self uploadEvidenceZip: zipPath filename: [NSString stringWithFormat:@"%@.zip",[currentZip objectForKey:@"Name"]]];
                    [self deleteZipFile:zipPath];
                }
                else
                {
                    [self pluginError:@"error during compression of evidence files!! "];
                    return;
                }
            }
        }
    }
}

-(void)deleteZipFile: (NSString *)zipPath
{
    NSError *error;
    BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:zipPath];
    if(fileExists) {
        BOOL success = [[NSFileManager defaultManager] removeItemAtPath:zipPath error:&error];
        if(!success)
        {
            [self pluginError:@"error deleting temporary file!! "];
            return;
        }
    }
}

- (void)startRecovery:(NSData *)jSON
{
    NSURLResponse *response;
    NSError *error;
    NSURL *url = [NSURL URLWithString:self.startEndpoint];
    NSMutableData *body = [[NSMutableData data] initWithData:jSON];
    NSString *postLength = [NSString stringWithFormat:@"%lu", (unsigned long)[body length]];
    
    // Create Request
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL: url];
    [request setCachePolicy:NSURLRequestReloadIgnoringCacheData];
    [request setHTTPMethod:@"POST"];
    [request setValue:[NSString stringWithFormat:@"application/json"] forHTTPHeaderField:@"Content-Type"];
    [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
    [request setValue:self.sessionToken forHTTPHeaderField:@"X-SessionID"];
    [request setHTTPBody:body];
    
    // Send Request
    NSData *responseBody = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    // Process Response
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    if ([response respondsToSelector:@selector(allHeaderFields)]) {
        NSDictionary *jSONResponse = @
        {
            @"status": [NSNumber numberWithInteger:[httpResponse statusCode]],
            @"headers": [httpResponse allHeaderFields]
        };
        if(responseBody) {
            self.sessionGUID = [[NSString alloc] initWithData:responseBody encoding: NSUTF8StringEncoding];
        }
    }
}

- (void)uploadEvidenceZip:(NSString *)filePath filename:(NSString *)filename
{
    NSURLResponse *response;
    NSError *error;
    
    NSData *zipData = [[NSFileManager defaultManager] contentsAtPath: filePath];
    
    NSString *charSet = @"UTF-8";
    NSString *webURL = [self.uploadEndpoint stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSString *fullURL = [webURL stringByAppendingString: [NSString stringWithFormat:@"/%@", self.sessionGUID]];
    NSURL *url = [NSURL URLWithString: fullURL relativeToURL: nil];
    
    NSString *boundary = [NSString stringWithFormat: @"++++%9.0f++++", [NSDate timeIntervalSinceReferenceDate]];
    NSMutableData *body = [NSMutableData data];
    [body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"File\"; filename=\"%@\"\r\n\r\n", filename] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[NSData dataWithData: zipData]];
    [body appendData:[[NSString stringWithFormat:@"\r\n\r\n--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    
    NSString *postLength = [NSString stringWithFormat:@"%lu", (unsigned long)[body length]];
    NSString *ContentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@; charset=%@", boundary, charSet];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL: url];
    [request setCachePolicy:NSURLRequestReloadIgnoringCacheData];
    [request setHTTPMethod:@"POST"];
    [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
    [request setValue:ContentType forHTTPHeaderField:@"Content-Type"];
    [request setValue:self.sessionToken forHTTPHeaderField:@"X-SessionID"];
    [request setHTTPBody:body];
    
    [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    if ([response respondsToSelector:@selector(allHeaderFields)]) {
        NSDictionary *jSON = @
        {
            @"status": [NSNumber numberWithInteger:[httpResponse statusCode]],
            @"headers": [httpResponse allHeaderFields]
        };
    }
}
@end
