//
//  ConfigEntity+CoreDataProperties.h
//  
//
//  Created by Constantinos Mavromoustakos on 11/10/15.
//
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "ConfigEntity.h"

NS_ASSUME_NONNULL_BEGIN

@interface ConfigEntity (CoreDataProperties)

@property (nullable, nonatomic, retain) id featuresJsonDictionary;
@property (nullable, nonatomic, retain) NSNumber *pollTimeInSeconds;
@property (nullable, nonatomic, retain) UserEntity *user;

@end

NS_ASSUME_NONNULL_END
