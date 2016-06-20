
#import "WCSyncCDRequest.h"

@implementation WCSyncCDRequest

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _handlerName = [coder decodeObjectForKey:@"handler"];
        _keyedInfo = [coder decodeObjectForKey:@"keyedInfo"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_handlerName forKey:@"handler"];
    [coder encodeObject:_keyedInfo forKey:@"keyedInfo"];
}

+ (NSDictionary <NSString *, NSData *> *)maxDataRemovedFromRequest:(WCSyncCDRequest *)request {
    NSDictionary <NSString *, id> * properties = (NSDictionary <NSString *, id> *)[request.keyedInfo objectForKey:WCSyncCDRequestObjectPropertiesKey];
    NSMutableDictionary <NSString *, id> *infoProperties = [NSMutableDictionary new];
    NSString *maxKey;
    NSData *maxData;
    for (NSString *key in properties.allKeys) {
        id object = [properties objectForKey:key];
        if ([object isKindOfClass:[NSData class]]) {
            NSData *dataObject = object;
            if (maxKey == nil) {
                maxKey = key;
                maxData = dataObject;
            } else {
                if (dataObject.length > maxData.length) {
                    [infoProperties setObject:maxData forKey:maxKey];
                    maxKey = key;
                    maxData = dataObject;
                }
            }
        } else {
            [infoProperties setObject:object forKey:key];
        }
    }
    NSMutableDictionary <NSString *, id> *tmpInfo = request.keyedInfo.mutableCopy;
    [tmpInfo setObject:infoProperties.copy forKey:WCSyncCDRequestObjectPropertiesKey];
    request.keyedInfo = tmpInfo.copy;
    return @{maxKey : maxData};
}

- (NSDictionary <NSString *, id> *)filterProperties:(NSDictionary <NSString *, id> *)properties {
    NSMutableDictionary <NSString *, id> *infoProperties = [NSMutableDictionary new];
    NSMutableDictionary <NSString *, id> *dataProperties = [NSMutableDictionary new];
    for (NSString *key in properties.allKeys) {
        id object = [properties objectForKey:key];
        if ([object isKindOfClass:[NSData class]] && ((NSData *)object).length > 200000) {
            [dataProperties setObject:object forKey:key];
        } else {
            [infoProperties setObject:object forKey:key];
        }
    }
//    self.keyedData = dataProperties.copy;
	    return infoProperties.copy;
}

+ (instancetype)newRequestWithObject:(NSManagedObject <WCSynchronizableCDEntity> *)object
                         handlerName:(NSString *)handlerName
                   includeProperties:(BOOL)includeProperties {
    WCSyncCDRequest *instance = [self new];
    instance.handlerName = handlerName;
    
    if (includeProperties) {
        NSDictionary <NSString *, id> * properties = [instance filterProperties:[object keyedProperties]];
        instance.keyedInfo = @{WCSyncCDRequestEntityKey : object.entity.name,
                               WCSyncCDRequestObjectPropertiesKey : properties,
                               WCSyncCDRequestObjectArchivedSelfIDKey : [object archivedSelfID],
                               WCSyncCDRequestObjectArchivedOuterIDKey : [object archivedOuterID],
                               };
    } else {
        instance.keyedInfo = @{WCSyncCDRequestEntityKey : object.entity.name,
                               WCSyncCDRequestObjectArchivedSelfIDKey : [object archivedSelfID],
                               WCSyncCDRequestObjectArchivedOuterIDKey : [object archivedOuterID],
                               };

    }
    return instance;
}

+ (instancetype)newRequestWithObject:(NSManagedObject<WCSynchronizableCDEntity> *)object
                         handlerName:(NSString *)handlerName
                       relatedObject:(NSManagedObject<WCSynchronizableCDEntity> *)relatedObject {
    WCSyncCDRequest *instance = [self new];
    instance.handlerName = handlerName;
    instance.keyedInfo = @{WCSyncCDRequestEntityKey : object.entity.name,
                           WCSyncCDRequestObjectArchivedSelfIDKey : [object archivedSelfID],
                           WCSyncCDRequestRelatedEntityKey : relatedObject.entity.name,
                           WCSyncCDRequestRelatedObjectArchivedSelfIDKey : [relatedObject archivedSelfID],
                           };
    return instance;
}

+ (NSDictionary <NSString *, id<NSCoding>> *)keyedInfoSynchronizableObject:(NSManagedObject <WCSynchronizableCDEntity> *)object {
    return @{WCSyncCDRequestEntityKey : object.entity.name,
             WCSyncCDRequestObjectArchivedSelfIDKey : [object archivedSelfID],
             WCSyncCDRequestObjectArchivedOuterIDKey : [object archivedOuterID],
             };
}

@end
