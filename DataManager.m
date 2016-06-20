
#import "DataManager.h"

#define synchroniztionTimeout 1.3

@interface DataManager()

@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (readonly, assign, nonatomic) BOOL sessionActivated;


@end



@implementation DataManager {
    WCSyncCDRequestQueue *syncQueue;
    NSDate *syncronizationStartedDate;
    BOOL coreDataInitializationInProgress, sessionActivationInProgress;
    NSCondition *coreDataInitializationCondition, *sessionActivationCondition;
    NSTimer *syncTimer;
    NSString *sqliteFilename;
    WCSessionActivationState sessionActivationState;
}

//----------- INIT SINGLETON

+ (instancetype)sharedInstance {
    static dispatch_once_t pred;
    static id shared = nil;
    dispatch_once(&pred, ^{
        shared = [[super alloc] initUniqueInstance];
    });
    return shared;
}

- (instancetype)initUniqueInstance {
    if (self = [super init]) {
        syncQueue = [WCSyncCDRequestQueue loadFromStdUD];
        WCSession *session = nil;
        if ([WCSession isSupported]) {
            session = [WCSession defaultSession];
            sessionActivationInProgress = YES;
            [session activateSession];
        }
    }
    return self;
}

- (void)session:(WCSession *)session activationDidCompleteWithState:(WCSessionActivationState)activationState error:(NSError *)error {
    sessionActivationState = activationState;
    sessionActivationInProgress = NO;
    [sessionActivationCondition signal];
    if (sessionActivationState == WCSessionActivationStateActivated) {
        [syncQueue sendQueue];
    }
    if (error) NSLog(@"ERROR: WCSession activation complete with error: %@", [error localizedDescription]);
}

- (void)setDataSource:(id<DataManagerDataSource>)dataSource {
    _dataSource = dataSource;
    if (dataSource) {
        sqliteFilename = [dataSource sqliteFilename];
        if (![sqliteFilename hasSuffix:@".sqlite"]) {
            sqliteFilename = [sqliteFilename stringByAppendingString:@".sqlite"];
        }
        _managedObjectContext = self.managedObjectContext;
    }
}

//DB

- (NSArray *)selectFrom:(NSString *)entity {
    return [self selectFrom:entity limit:0];
}

- (NSArray *)selectFrom:(NSString *)entity limit:(NSUInteger)limit {
    return [self selectFrom:entity where:nil limit:limit];
}

- (NSArray *)selectFrom:(NSString *)entity orderBy:(NSString *)key {
    return [self selectFrom:entity where:nil orderBy:key ASC limit:0];
}

- (NSArray *)selectFrom:(NSString *)entity orderBy:(NSString *)key ascending:(BOOL)ascending {
    return [self selectFrom:entity where:nil orderBy:key ascending:ascending limit:0];
}

- (NSArray *)selectFrom:(NSString *)entity orderBy:(NSString *)key limit:(NSUInteger)limit {
    return [self selectFrom:entity where:nil orderBy:key ASC limit:limit];
}

- (NSArray *)selectFrom:(NSString *)entity orderBy:(NSString *)key ascending:(BOOL)ascending limit:(NSUInteger)limit {
    return [self selectFrom:entity where:nil orderBy:key ascending:ascending limit:limit];
}

- (NSArray *)selectFrom:(NSString *)entity where:(NSPredicate *)predicate {
    return [self selectFrom:entity where:predicate limit:0];
}

- (NSArray *)selectFrom:(NSString *)entity where:(NSPredicate *)predicate limit:(NSUInteger)limit {
    return [self selectFrom:entity where:predicate orderBy:nil ascending:NO limit:limit];
}

- (NSArray *)selectFrom:(NSString *)entity where:(NSPredicate *)predicate orderBy:(NSString *)key {
    return [self selectFrom:entity where:predicate orderBy:key ASC limit:0];
}

- (NSArray *)selectFrom:(NSString *)entity where:(NSPredicate *)predicate orderBy:(NSString *)key ascending:(BOOL)ascending {
    return [self selectFrom:entity where:predicate orderBy:key ascending:ascending limit:0];
}

- (NSArray *)selectFrom:(NSString *)entity where:(NSPredicate *)predicate orderBy:(NSString *)key limit:(NSUInteger)limit {
    return [self selectFrom:entity where:predicate orderBy:key ASC limit:limit];
}

- (NSArray *)selectFrom:(NSString *)entity where:(NSPredicate *)predicate orderBy:(NSString *)key ascending:(BOOL)ascending limit:(NSUInteger)limit {
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:entity];
    if (key && ![key isEqualToString:@""]) {
        NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:key ascending:ascending];
        [request setSortDescriptors:@[sortDescriptor]];
    }
    request.predicate = predicate;
    [request setFetchLimit:limit];
    NSError *error = nil;
    NSArray *entities = [self.managedObjectContext executeFetchRequest:request error:&error];
    if (error) {
        NSLog(@"Unresolved error %@, %@", [error localizedDescription], [error userInfo]);
    }
    return entities;
}


- (void)requestRemoteInsertAllObjectsForEntity:(nonnull NSString *)entityName {
    if (self.sessionActivated) {
        [[WCSession defaultSession] sendMessage:@{@"DataManager remote" : @"InsertAllObjectsForEntity",
                                                  @"EntityName" : entityName} replyHandler:^(NSDictionary<NSString *,id> * _Nonnull replyMessage) {
                                                      NSLog(@"DataManager remote : InsertAllObjectsForEntity : %@", replyMessage);
                                                  } errorHandler:^(NSError * _Nonnull error) {
                                                      NSLog(@"DataManager remote : InsertAllObjectsForEntity : Error : %@", [error localizedDescription]);
                                                  }];
    }
}

- (void)requestRemoteSetRelationsForEntity:(nonnull NSString *)entityName {
    if (self.sessionActivated) {
        [[WCSession defaultSession] sendMessage:@{@"DataManager remote" : @"RemoteSetRelationsForEntity",
                                                  @"EntityName" : entityName} replyHandler:^(NSDictionary<NSString *,id> * _Nonnull replyMessage) {
                                                      NSLog(@"DataManager remote : RemoteSetRelationsForEntity : %@", replyMessage);
                                                  } errorHandler:^(NSError * _Nonnull error) {
                                                      NSLog(@"DataManager remote : RemoteSetRelationsForEntity : Error : %@", [error localizedDescription]);
                                                  }];
    }
}

- (BOOL)sessionActivated {
    if (!sessionActivationInProgress && (sessionActivationState != WCSessionActivationStateActivated)) {
        sessionActivationInProgress = YES;
        [[WCSession defaultSession] activateSession];
    }
    if (sessionActivationInProgress) {
        [sessionActivationCondition lock];
        while (sessionActivationInProgress) {
            [sessionActivationCondition wait];
        }
        [sessionActivationCondition unlock];
    }
    if (sessionActivationState == WCSessionActivationStateActivated) {
        return YES;
    } else {
        NSLog(@"ERROR: cannot send message: WCSession not activate");
        return NO;
    }
}

- (void)session:(WCSession *)session didReceiveMessage:(NSDictionary<NSString *,id> *)message replyHandler:(void (^)(NSDictionary<NSString *,id> * _Nonnull))replyHandler {
    NSString *command = [message objectForKey:@"DataManager remote"];
    if (command) {
        if ([command isEqualToString:@"InsertAllObjectsForEntity"]) {
            NSString *entityName = [message objectForKey:@"EntityName"];
            if (entityName) {
                @try {
                    NSArray <NSManagedObject <WCSynchronizableCDEntity> *> *allObjects = [self selectFrom:entityName];
                    for (NSManagedObject <WCSynchronizableCDEntity> *object in allObjects) {
                        [self remoteInsertObject:object];
                    }
                    replyHandler(@{@"Result" : @"OK"});
                } @catch (NSException *exception) {
                    replyHandler(@{@"Result"    : @"Exception",
                                   @"Exception" : [exception description] });
                }
            } else {
                replyHandler(@{@"Result" : @"Error",
                               @"Error"  : @"entityName not found in message"});
            }
            
        } else if ([command isEqualToString:@"RemoteSetRelationsForEntity"]) {
            NSString *entityName = [message objectForKey:@"EntityName"];
            if (entityName) {
                @try {
                    NSArray <NSManagedObject <WCSynchronizableCDRelatableEntity> *> *allObjects = [self selectFrom:entityName];
                    for (NSManagedObject <WCSynchronizableCDRelatableEntity> *object in allObjects) {
                        NSArray <NSManagedObject <WCSynchronizableCDEntity> *> *relatedObjects = [object getAllRelatedObjectsByEntityName:entityName];
                        for (NSManagedObject <WCSynchronizableCDEntity> *relatedObject in relatedObjects) {
                            [self setObject:object relatedToObject:relatedObject];
                        }
                    }
                    replyHandler(@{@"Result" : @"OK"});
                } @catch (NSException *exception) {
                    replyHandler(@{@"Result"    : @"Exception",
                                   @"Exception" : [exception description] });
                }
            } else {
                replyHandler(@{@"Result" : @"Error",
                               @"Error"  : @"entityName not found in message"});
            }
        }
    } else {
        if (_delegate && [_delegate respondsToSelector:@selector(didReceiveMessage:replyHandler:)]) {
            [_delegate didReceiveMessage:message replyHandler:replyHandler];
        }
    }
}


- (NSManagedObject *)insertTo:(NSString *)entity {
    NSManagedObject *object = nil;
    if (self.managedObjectContext) {
        object = [NSEntityDescription insertNewObjectForEntityForName:entity inManagedObjectContext:self.managedObjectContext];
        [self commit];        
        if ([NSClassFromString([[NSEntityDescription entityForName:entity inManagedObjectContext:self.managedObjectContext] managedObjectClassName]) conformsToProtocol:@protocol(WCSynchronizableCDEntity)]) {
            [self remoteInsertObject:(NSManagedObject <WCSynchronizableCDEntity> *)object];
        }
    }
    return object;
}

- (void)remoteInsertObject:(NSManagedObject <WCSynchronizableCDEntity> *)object {
    WCSyncCDRequest *request = [WCSyncCDRequest newRequestWithObject:(NSManagedObject <WCSynchronizableCDEntity> *)object handlerName:@"insertObjectWithKeyedInfo:"  includeProperties:YES];
    [syncQueue newRequest:request];
}

- (void)insertObjectWithKeyedInfo:(NSDictionary <NSString *, id> *)keyedInfo {
    NSManagedObject <WCSynchronizableCDEntity> *object = [self managedObjectByKeyedInfo:keyedInfo related:NO];
    if (!object) {
        object = [NSEntityDescription insertNewObjectForEntityForName:[keyedInfo objectForKey:WCSyncCDRequestEntityKey] inManagedObjectContext:self.managedObjectContext];
    }
    [object setProperties:[keyedInfo objectForKey:WCSyncCDRequestObjectPropertiesKey]];
    [object setArchivedOuterID:[keyedInfo objectForKey:WCSyncCDRequestObjectArchivedSelfIDKey]];
    [self commit];
    
    WCSyncCDRequest *request = [WCSyncCDRequest newRequestWithObject:object handlerName:@"insertReplyReciever:" includeProperties:NO];
    [syncQueue newRequest:request];
}

- (void)insertReplyReciever:(NSDictionary <NSString *, id> *)keyedInfo {
    NSURL *orignURL = [NSKeyedUnarchiver unarchiveObjectWithData:[keyedInfo objectForKey:WCSyncCDRequestObjectArchivedOuterIDKey]];
    NSManagedObject <WCSynchronizableCDEntity> *object = [self managedObjectByURL:orignURL];
    [object setArchivedOuterID:[keyedInfo objectForKey:WCSyncCDRequestObjectArchivedSelfIDKey]];
    [self commit];
}

- (void)updateObject:(NSManagedObject <WCSynchronizableCDEntity> *)object {
    if (object) {
        if ([object respondsToSelector:@selector(didUpdate)]) {
            [object didUpdate];
        }
        [self commit];
        
        WCSyncCDRequest *request = [WCSyncCDRequest newRequestWithObject:object handlerName:@"updateObjectWithKeyedInfo:" includeProperties:YES];
        [syncQueue newRequest:request];
    }
}

- (void)updateObjectWithKeyedInfo:(NSDictionary <NSString *, id> *)keyedInfo {
    NSManagedObject <WCSynchronizableCDEntity> *object = [self managedObjectByKeyedInfo:keyedInfo related:NO];
    if (object) {
        [object setProperties:[keyedInfo objectForKey:WCSyncCDRequestObjectPropertiesKey]];
        [self commit];
    } else {
        NSLog(@"ERROR: cannot update object with keyedInfo: %@", keyedInfo);
    }
}

- (void)deleteObject:(NSManagedObject *)object {
    if ([object.class conformsToProtocol:@protocol(WCSynchronizableCDEntity)]) {
        WCSyncCDRequest *request = [WCSyncCDRequest newRequestWithObject:(NSManagedObject <WCSynchronizableCDEntity> *)object handlerName:@"deleteObjectWithKeyedInfo:" includeProperties:NO];
        [syncQueue newRequest:request];
    }
    [self.managedObjectContext deleteObject:object];
    [self commit];
}

- (void)deleteObjectWithKeyedInfo:(NSDictionary <NSString *, id> *)keyedInfo {
    NSManagedObject <WCSynchronizableCDEntity> *object = [self managedObjectByKeyedInfo:keyedInfo related:NO];
    if (object) {
        [self.managedObjectContext deleteObject:object];
        [self commit];
    } else {
        NSLog(@"ERROR: cannot delete object with keyedInfo: %@", keyedInfo);
    }
}

- (void)setObject:(NSManagedObject <WCSynchronizableCDRelatableEntity> *)object relatedToObject:(NSManagedObject <WCSynchronizableCDEntity> *)relatedObject {
    [object setRelationToObject:relatedObject];
    [self commit];
    WCSyncCDRequest *request = [WCSyncCDRequest newRequestWithObject:object handlerName:@"setRelationWithKeyedInfo:" relatedObject:relatedObject];
    [syncQueue newRequest:request];
}

- (void)setRelationWithKeyedInfo:(NSDictionary <NSString *, id> *)keyedInfo {
    NSManagedObject <WCSynchronizableCDEntity> *object = [self managedObjectByKeyedInfo:keyedInfo related:NO];
    NSManagedObject <WCSynchronizableCDEntity> *relatedObject = [self managedObjectByKeyedInfo:keyedInfo related:YES];
    if (object && relatedObject) {
        if ([object conformsToProtocol:@protocol(WCSynchronizableCDRelatableEntity)]) {
            [(NSManagedObject <WCSynchronizableCDRelatableEntity> *)object setRelationToObject:relatedObject];
            [self commit];
        } else {
            NSLog(@"ERROR: object not conforms to protocol WCSynchronizableCDRelatedEntity! %@", object);
        }
    } else {
        NSLog(@"ERROR: database integrity constraint violation! setRelationWithKeyedInfo: %@", keyedInfo);
    }
}



- (NSManagedObject <WCSynchronizableCDEntity> *)managedObjectByKeyedInfo:(NSDictionary <NSString *, id> *)keyedInfo related:(BOOL)related {
    NSString *entityName = [keyedInfo objectForKey:related ? WCSyncCDRequestRelatedEntityKey : WCSyncCDRequestEntityKey];
    NSData *recievedArchivedSelfID = [keyedInfo objectForKey:related ? WCSyncCDRequestRelatedObjectArchivedSelfIDKey : WCSyncCDRequestObjectArchivedSelfIDKey];    
    NSEntityDescription *entity = [NSEntityDescription entityForName:entityName inManagedObjectContext:self.managedObjectContext];
    Class <WCSynchronizableCDEntity> SycronizableManagedObjectClass = NSClassFromString([entity managedObjectClassName]);
    NSString *predicateFormat = [NSString stringWithFormat:@"%@ == %%@", [SycronizableManagedObjectClass outerIDFieldName]];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:predicateFormat, recievedArchivedSelfID];
    NSArray <NSManagedObject <WCSynchronizableCDEntity> *> *objects = [self selectFrom:entityName where:predicate];
    if (objects.count == 1) {
        return objects[0];
    } else {
        if (objects.count != 0) NSLog(@"ERROR: database integrity constraint violation! Check your WCSynchronizableCDEntity protocol implementation for Entity %@", entityName);
        return nil;
    }
}


- (NSManagedObject <WCSynchronizableCDEntity> *)managedObjectByURL:(NSURL *)URL {
    if (URL) {
        return [self.managedObjectContext objectWithID:[_persistentStoreCoordinator managedObjectIDForURIRepresentation:URL]];
    } else {
        return nil;
    }
    
}


- (void)session:(WCSession *)session didReceiveApplicationContext:(nonnull NSDictionary<NSString *,id> *)applicationContext {
    NSLog(@"%s", __FUNCTION__);
    WCSyncCDRequest *syncRequest;
    NSData *archivedQueue = [applicationContext objectForKey:NSStringFromClass(syncQueue.class)];
    if (archivedQueue) {
        syncQueue.recieved = ((NSDictionary *)[NSKeyedUnarchiver unarchiveObjectWithData:archivedQueue]).mutableCopy;
        [self syncronizationStarted:syncQueue.recieved.count];
        while ((syncRequest = [syncQueue nextRequest])) {
            SEL selector = NSSelectorFromString(syncRequest.handlerName);
            if ([self respondsToSelector:selector]) {
                //[self performSelector:selector withObject:syncRequest.keyedInfo]; //this spawns warning. workaround:
                IMP imp = [self methodForSelector:selector];
                void (*func)(id, SEL, NSDictionary <NSString *, id> *) = (void *)imp;
                func(self, selector, syncRequest.keyedInfo);
            } else {
                NSLog(@"ERROR: %@ not responds to selector %@", self.class, syncRequest.handlerName);
            }
        }
        [syncQueue sendLastRecievedRequest];
        [self syncronizationOver];
    } else {
        if ([syncQueue didReceiveApplicationContext:applicationContext]) {
            //Nothing to do.. yet
        } else {
            if (_delegate && [_delegate respondsToSelector:@selector(session:didReceiveApplicationContext:)]) {
                [_delegate didReceiveApplicationContext:applicationContext];
            }
        }
    }
}

- (void)syncronizationStarted:(NSUInteger)requestsCount {
    syncronizationStartedDate = [NSDate date];
    dispatch_async(dispatch_get_main_queue(), ^{
        [syncTimer invalidate];
    });
    if (!_syncroniztionInProgress) {
        _syncroniztionInProgress = YES;
        if (_delegate && [_delegate respondsToSelector:@selector(syncronizationStarted:)]) {
            [self.delegate syncronizationStarted:requestsCount];
        }
    }
}

- (void)syncronizationOver {
    if (_syncroniztionInProgress) {
        if ([[NSDate date] timeIntervalSinceDate:syncronizationStartedDate] >= synchroniztionTimeout) {
            _syncroniztionInProgress = NO;
            if (self.delegate && [self.delegate respondsToSelector:@selector(syncronizationOver)]) {
                [self.delegate syncronizationOver];
            }
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                syncTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(syncronizationOver) userInfo:nil repeats:NO];
            });
            
        }
    }
}

#pragma mark WCSessionDelegate
- (void)sessionReachabilityDidChange:(nonnull WCSession *)session {
    if ([session isReachable]) {
        [syncQueue sendQueue];
    }
    if (_delegate && [_delegate respondsToSelector:@selector(sessionReachabilityDidChange:)]) {
        [_delegate sessionReachabilityDidChange:session];
    }
    //NSLog(@"%@", session.isReachable ? @"session is reachable" : @"session unreachable");
}
- (void)session:(nonnull WCSession *)session didReceiveMessage:(nonnull NSDictionary<NSString *, id> *)message {
    if (_delegate && [_delegate respondsToSelector:@selector(didReceiveMessage:)]) {
        [_delegate didReceiveMessage:message];
    }
}
- (void)session:(nonnull WCSession *)session didReceiveMessageData:(nonnull NSData *)messageData {
    if (_delegate && [_delegate respondsToSelector:@selector(didReceiveMessageData:)]) {
        [_delegate didReceiveMessageData:messageData];
    }
}

- (void)session:(nonnull WCSession *)session didReceiveMessageData:(NSData *)messageData replyHandler:(void(^)(NSData *replyMessageData))replyHandler {
    if (_delegate && [_delegate respondsToSelector:@selector(didReceiveMessageData:replyHandler:)]) {
        [_delegate didReceiveMessageData:messageData replyHandler:replyHandler];
    }
}

#pragma mark - Core Data stack

@synthesize managedObjectContext = _managedObjectContext;
@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;
@synthesize managedObjectModel = _managedObjectModel;

+ (NSURL *)applicationDocumentsDirectory {
    // The directory the application uses to store the Core Data store file. This code uses a directory named "com.academmedia.Record_Guard" in the application's documents directory.
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

- (NSManagedObjectModel *)managedObjectModel {
    // The managed object model for the application. It is a fatal error for the application not to be able to find and load its model.
    if (!_managedObjectModel) {
        if (self.dataSource) {
            _managedObjectModel = [self.dataSource managedObjectModel];
        } else {
            NSLog(@"Error: dataSource %@", self.dataSource);
        }
    }
    return _managedObjectModel;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator {
    if (coreDataInitializationInProgress) {
        [coreDataInitializationCondition lock];
        while (coreDataInitializationInProgress) {
            [coreDataInitializationCondition wait];
        }
        [coreDataInitializationCondition unlock];
    }
    
    // The persistent store coordinator for the application. This implementation creates and returns a coordinator, having added the store for the application to it.
    if (!self.managedObjectModel || _persistentStoreCoordinator != nil) {
        return _persistentStoreCoordinator;
    }
    coreDataInitializationInProgress = YES;

    
    // Create the coordinator and store
    
    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:self.managedObjectModel];
    NSURL *storeURL = [[DataManager applicationDocumentsDirectory] URLByAppendingPathComponent:sqliteFilename];
    NSError *error = nil;
    if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:nil error:&error]) {
        // Report any error we got.
        //        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        //        dict[NSLocalizedDescriptionKey] = NSLocalizedString(@"Failed to initialize the application's saved data", nil);
        //        dict[NSLocalizedFailureReasonErrorKey] = NSLocalizedString(@"There was an error creating or loading the application's saved data.", nil);
        //        dict[NSUnderlyingErrorKey] = error;
        //        error = [NSError errorWithDomain:@"com.anobisoft" code:1025 userInfo:dict];
        // Replace this with code to handle the error appropriately.
        // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
        NSLog(@"Unresolved error %@, %@", error, [error localizedDescription]);
        abort();
    }
    
    coreDataInitializationInProgress = NO;
    [coreDataInitializationCondition signal];


    
    return _persistentStoreCoordinator;
}


- (NSManagedObjectContext *)managedObjectContext {
    // Returns the managed object context for the application (which is already bound to the persistent store coordinator for the application.)
    if (_managedObjectContext != nil) {
        return _managedObjectContext;
    } else {
        NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
        if (!coordinator) {
            return nil;
        }
        _managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        [_managedObjectContext setPersistentStoreCoordinator:coordinator];
        WCSession *session = nil;
        if ([WCSession isSupported]) {
            session = [WCSession defaultSession];
            session.delegate  = self;
            [session activateSession];
        }
        return _managedObjectContext;
    }
}


#pragma mark - Core Data Saving support

- (void)commit {
    NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
    if (managedObjectContext != nil) {
        NSError *error = nil;
        if ([managedObjectContext hasChanges] && ![managedObjectContext save:&error]) {
            // Replace this implementation with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog(@"Unresolved error %@, %@", [error localizedDescription], [error userInfo]);
            abort();
        }
    }
}

- (void)rollback {
    [self.managedObjectContext rollback];
}

@end
