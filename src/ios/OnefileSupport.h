#import <Cordova/CDVPlugin.h>

/************************************************************************************************************
 *      OnefileSupport - Initialisation point of the plugin
 ************************************************************************************************************/

@interface OnefileSupport : CDVPlugin <UINavigationControllerDelegate>
{
    BOOL _inUse;
}
@property BOOL inUse;

- (void)pluginInitialize;
- (void)onefileSupport:(CDVInvokedUrlCommand*)command;
- (void)onefileRecover:(CDVInvokedUrlCommand*)command;

-(void)startRecovery:(NSData *)jSON;
-(void)uploadRecovery:(NSData *)jSON;
@end
