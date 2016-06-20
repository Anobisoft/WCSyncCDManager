
#import <CoreData/CoreData.h>

@protocol WCSynchronizableCDEntity <NSObject>
@required
- (nonnull NSDictionary <NSString *, id> *)keyedProperties;
- (void)setProperties:(nonnull NSDictionary <NSString *, id> *)keyedProperties;

//outerID - field for archived NSManagedObject instance objectID. Needed for linking managed objects.
+ (nonnull NSString *)outerIDFieldName;
- (nonnull NSData *)archivedOuterID;
- (void)setArchivedOuterID:(nonnull NSData *)outerID;

@optional
- (void)didUpdate;
@end


@protocol WCSynchronizableCDRelatableEntity <WCSynchronizableCDEntity>
@required
- (nullable NSArray <NSManagedObject <WCSynchronizableCDEntity> *> *)getAllRelatedObjectsByEntityName:(NSString *)entity;
- (void)setRelationToObject:(nonnull NSManagedObject <WCSynchronizableCDEntity> *)object;
@end



@interface NSManagedObject (WCSyncronizable)

- (nonnull NSData *)archivedSelfID;

@end
