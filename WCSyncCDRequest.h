
#define WCSyncCDRequestEntityKey @"Entity"
#define WCSyncCDRequestObjectPropertiesKey @"Properties"
#define WCSyncCDRequestObjectArchivedSelfIDKey @"ArchivedID"
#define WCSyncCDRequestObjectArchivedOuterIDKey @"OuterID"

#define WCSyncCDRequestRelatedEntityKey @"RelatedEntity"
#define WCSyncCDRequestRelatedObjectArchivedSelfIDKey @"RelatedArchivedID"

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "NSManagedObject+WCSyncronizable.h"


@interface WCSyncCDRequest : NSObject <NSCoding>

@property (nonatomic, strong, nonnull) NSString *handlerName;
@property (nonatomic, strong, nonnull) NSDictionary <NSString *, id<NSCoding>> *keyedInfo;


+ (instancetype _Nonnull)newRequestWithObject:(nonnull NSManagedObject <WCSynchronizableCDEntity> *)object
                                  handlerName:(nonnull NSString *)handlerName
                            includeProperties:(BOOL)includeProperties;
+ (instancetype _Nonnull)newRequestWithObject:(nonnull NSManagedObject <WCSynchronizableCDEntity> *)object
                                  handlerName:(nonnull NSString *)handlerName
                                relatedObject:(nonnull NSManagedObject <WCSynchronizableCDEntity> *)relatedObject;
+ (nonnull NSDictionary <NSString *, id<NSCoding>> *)keyedInfoSynchronizableObject:(nonnull NSManagedObject <WCSynchronizableCDEntity> *)object;

@end



