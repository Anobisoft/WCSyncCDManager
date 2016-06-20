
#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import <WatchConnectivity/WatchConnectivity.h>
#import "WCSyncCDRequestQueue.h"

#define ASC ascending:YES
#define DESC ascending:NO

@protocol DataManagerDelegate <NSObject>

@optional
- (void)syncronizationStarted:(NSUInteger)requestsCount;
- (void)syncronizationOver;

#pragma mark WCSessionDelegate
- (void)didReceiveApplicationContext:(nonnull NSDictionary<NSString *,id> *)applicationContext;
- (void)sessionReachabilityDidChange:(nonnull WCSession *)session;
- (void)didReceiveMessage:(nonnull NSDictionary<NSString *, id> *)message;
- (void)didReceiveMessageData:(nonnull NSData *)messageData;
- (void)didReceiveMessage:(nonnull NSDictionary<NSString *, id> *)message replyHandler:(nullable void(^)(NSDictionary<NSString *, id> * _Nonnull replyMessage))replyHandler;
- (void)didReceiveMessageData:(nonnull NSData *)messageData replyHandler:(nonnull void(^)(NSData * _Nonnull replyMessageData))replyHandler;

@end

@protocol DataManagerDataSource <NSObject>
@required
- (NSManagedObjectModel * _Nonnull)managedObjectModel;
- (NSString * _Nonnull)sqliteFilename;
@end

@interface DataManager : NSObject <WCSessionDelegate>

@property (readonly, strong, nonatomic, nullable) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, weak, nullable) id <DataManagerDelegate> delegate;
@property (nonatomic, weak, nullable) id <DataManagerDataSource> dataSource;
@property (nonatomic, assign) BOOL syncroniztionInProgress;


+ (nonnull instancetype)sharedInstance;
+ (nonnull NSURL *)applicationDocumentsDirectory;

- (nonnull NSArray *)selectFrom:(nonnull NSString *)entity;
- (nonnull NSArray *)selectFrom:(nonnull NSString *)entity limit:(NSUInteger)limit;
- (nonnull NSArray *)selectFrom:(nonnull NSString *)entity orderBy:(nullable NSString *)key;
- (nonnull NSArray *)selectFrom:(nonnull NSString *)entity orderBy:(nullable NSString *)key ascending:(BOOL)ascending;
- (nonnull NSArray *)selectFrom:(nonnull NSString *)entity orderBy:(nullable NSString *)key limit:(NSUInteger)limit;
- (nonnull NSArray *)selectFrom:(nonnull NSString *)entity orderBy:(nullable NSString *)key ascending:(BOOL)ascending limit:(NSUInteger)limit;

- (nonnull NSArray *)selectFrom:(nonnull NSString *)entity where:(nullable NSPredicate *)predicate;
- (nonnull NSArray *)selectFrom:(nonnull NSString *)entity where:(nullable NSPredicate *)predicate limit:(NSUInteger)limit;
- (nonnull NSArray *)selectFrom:(nonnull NSString *)entity where:(nullable NSPredicate *)predicate orderBy:(nullable NSString *)key;
- (nonnull NSArray *)selectFrom:(nonnull NSString *)entity where:(nullable NSPredicate *)predicate orderBy:(nullable NSString *)key ascending:(BOOL)ascending;
- (nonnull NSArray *)selectFrom:(nonnull NSString *)entity where:(nullable NSPredicate *)predicate orderBy:(nullable NSString *)key limit:(NSUInteger)limit;
- (nonnull NSArray *)selectFrom:(nonnull NSString *)entity where:(nullable NSPredicate *)predicate orderBy:(nullable NSString *)key ascending:(BOOL)ascending limit:(NSUInteger)limit;

- (nonnull NSManagedObject *)insertTo:(nonnull NSString *)entity;
- (void)updateObject:(nonnull NSManagedObject <WCSynchronizableCDEntity> *)object;
- (void)deleteObject:(nonnull NSManagedObject *)object;
- (void)setObject:(nonnull NSManagedObject <WCSynchronizableCDRelatableEntity> *)object relatedToObject:(nonnull NSManagedObject <WCSynchronizableCDEntity> *)relatedObject;

- (void)remoteInsertObject:(nonnull NSManagedObject <WCSynchronizableCDEntity> *)object;
- (void)requestRemoteInsertAllObjectsForEntity:(nonnull NSString *)entityName;
- (void)requestRemoteSetRelationsForEntity:(nonnull NSString *)entityName;

- (void)commit;
- (void)rollback;

- (nonnull NSManagedObject <WCSynchronizableCDEntity> *)managedObjectByKeyedInfo:(nonnull NSDictionary <NSString *, id> *)keyedInfo related:(BOOL)related;

//- (NSManagedObjectContext *) getCurrentContext;




@end
