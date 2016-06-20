
#define WCSyncCDRequestQueueLastRecievedRequestKey @"lastRecievedRequest"

#import <Foundation/Foundation.h>
#import <WatchConnectivity/WatchConnectivity.h>
#import "WCSyncCDRequest.h"

@interface WCSyncCDRequestQueue : NSObject <NSCoding>
//- (void)save;
+ (_Nonnull instancetype)loadFromStdUD;
- (void)newRequest:(WCSyncCDRequest * _Nonnull)request;
- (void)sendQueue;
- (WCSyncCDRequest * _Nonnull)nextRequest;
- (void)sendLastRecievedRequest;
- (BOOL)didReceiveApplicationContext:(NSDictionary <NSString *, id> * _Nonnull)applicationContext;
@property (nullable, nonatomic, strong) NSMutableDictionary <NSNumber *, WCSyncCDRequest *> *queue;
@property (nullable, nonatomic, strong) NSMutableDictionary <NSNumber *, WCSyncCDRequest *> *recieved;
@end