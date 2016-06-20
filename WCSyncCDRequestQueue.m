
#import "WCSyncCDRequestQueue.h"

@interface WCSyncCDRequestQueue()
@property (nullable, nonatomic, strong) NSNumber *nextRequestNumber;
@property (nullable, nonatomic, strong) NSNumber *nextRecievedRequestNumber;
@end

@implementation WCSyncCDRequestQueue {
    NSTimeInterval timeout;
    BOOL waitingTimeOut;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _queue = [[coder decodeObjectForKey:@"queue"] mutableCopy];
        _nextRequestNumber = [coder decodeObjectForKey:@"nextRequestNumber"];
        _nextRecievedRequestNumber = [coder decodeObjectForKey:@"nextRecievedRequestNumber"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_queue forKey:@"queue"];
    [coder encodeObject:_nextRequestNumber forKey:@"nextRequestNumber"];
    [coder encodeObject:_nextRecievedRequestNumber forKey:@"nextRecievedRequestNumber"];
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _queue = [NSMutableDictionary new];
        _nextRequestNumber = @0;
        _nextRecievedRequestNumber = @0;
        [self save];
    }
    return self;
}

- (void)save {
    NSData *archived = [NSKeyedArchiver archivedDataWithRootObject:self];
    [[NSUserDefaults standardUserDefaults] setObject:archived forKey:NSStringFromClass(self.class)];
}

+ (instancetype)loadFromStdUD {
    NSData *archived = [[NSUserDefaults standardUserDefaults] objectForKey:NSStringFromClass(self.class)];
    if (archived) {
        return [NSKeyedUnarchiver unarchiveObjectWithData:archived];
    } else {
        return [self new];
    }
}

- (void)newRequest:(WCSyncCDRequest *)request {
    [_queue setObject:request forKey:_nextRequestNumber];
    _nextRequestNumber = [NSNumber numberWithUnsignedInteger:_nextRequestNumber.unsignedIntegerValue+1];
    [self save];
    [self sendQueue];
}

- (void)sendQueue {    
    if (_queue.count && [WCSession isSupported]) {
        NSError *error = nil;
        [[WCSession defaultSession] updateApplicationContext:@{ NSStringFromClass(self.class) : [NSKeyedArchiver archivedDataWithRootObject:_queue] } error:&error];
        if (error) {
            NSLog(@"WCSession error: %ld %@", (long)error.code, error.localizedDescription);
            switch (error.code) {
                case 7009 : {
                    
                } break;
                default: {
                    if (!waitingTimeOut) {
                        waitingTimeOut = YES;
                        [NSTimer scheduledTimerWithTimeInterval:++timeout target:self selector:@selector(delayedSendQueue) userInfo:nil repeats:NO];
                    }
                }
            }
        } else {
            timeout = 0;
            waitingTimeOut = NO;
        }



    }
}

- (void)delayedSendQueue {
    waitingTimeOut = NO;
    [self sendQueue];
}


- (WCSyncCDRequest *)nextRequest {
    WCSyncCDRequest *request = [_recieved objectForKey:_nextRecievedRequestNumber];
    if (request) {
        _nextRecievedRequestNumber = [NSNumber numberWithUnsignedInteger:_nextRecievedRequestNumber.unsignedIntegerValue+1];
        [self save];
    }    
    return request;
}

- (void)sendLastRecievedRequest {
    if ([WCSession isSupported]) {
        [[WCSession defaultSession] updateApplicationContext:@{WCSyncCDRequestQueueLastRecievedRequestKey : _nextRecievedRequestNumber} error:nil];
    }
}

- (BOOL)didReceiveApplicationContext:(nonnull NSDictionary<NSString *,id> *)applicationContext {
    NSLog(@"%s", __FUNCTION__);
    NSNumber *newKey = [applicationContext objectForKey:WCSyncCDRequestQueueLastRecievedRequestKey];
    if (newKey) {
        for (NSNumber *key in _queue.allKeys) {
            if (key.unsignedIntegerValue < newKey.unsignedIntegerValue) {
                [_queue removeObjectForKey:key];
                [self save];
            }
        }
        return YES;
    } else {
        return NO;
    }
    
}



@end