
#import "NSManagedObject+WCSyncronizable.h"

@implementation NSManagedObject (WCSynchronizable)

- (NSData *)archivedSelfID {
    return [NSKeyedArchiver archivedDataWithRootObject:self.objectID.URIRepresentation];
}

@end
