//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//


#import "LDUserModel.h"

@interface LDUserBuilder : NSObject

/**
 * A key to the user builder to identify the user. If this key
 * is not provided, one will be auto-generated. (Optional)
 */
@property (nonatomic, copy, nullable) NSString *key;

/**
 * The IP address of the user. (Optional)
 */
@property (nonatomic, copy, nullable) NSString *ip;

/**
 * The country of the user. (Optional)
 */
@property (nonatomic, copy, nullable) NSString *country;

/**
 * The first name of the user. (Optional)
 */
@property (nonatomic, copy, nullable) NSString *firstName;

/**
 * The last name of the user. (Optional)
 */
@property (nonatomic, copy, nullable) NSString *lastName;

/**
 * The email address of the user. (Optional)
 */
@property (nonatomic, copy, nullable) NSString *email;

/**
 * The avatar of the user. (Optional)
 */
@property (nonatomic, copy, nullable) NSString *avatar;

/**
 * The custom NSMutableDictionary data for the dictionary associated with
 * the user. (Optional)
 */
@property (nonatomic, strong, nullable) NSMutableDictionary *customDictionary;

/**
 * Provide whether the user is anonymous. Note, if a key is
 * auto-generated for the user, then anonymous is set to YES. Default
 * is NO. (Optional)
 */
@property (nonatomic) BOOL isAnonymous;

/**
 * Provide custom String data for the dictionary associated with
 * the user. (Optional)
 *
 * @param inputKey    key for the data
 * @param value    value for the data
 */
- (void)customString:(nonnull NSString *)inputKey value:(nonnull NSString *)value;

/**
 * Provide custom BOOL data for the dictionary associated with
 * the user. (Optional)
 *
 * @param inputKey    key for the data
 * @param value    value for the data
 */
- (void)customBool:(nonnull NSString *)inputKey value:(BOOL)value;

/**
 * Provide custom NSNumber data for the dictionary associated with
 * the user. (Optional)
 *
 * @param inputKey    key for the data
 * @param value    value for the data
 */
- (void)customNumber:(nonnull NSString *)inputKey value:(nonnull NSNumber *)value;

/**
 * Provide custom NSArray data for the dictionary associated with
 * the user. (Optional)
 *
 * @param inputKey    key for the data
 * @param value    value for the data
 */
- (void)customArray:(nonnull NSString *)inputKey value:(nonnull NSArray *)value;


-(nonnull LDUserModel *)build;

+ (nonnull LDUserModel *)compareNewBuilder:(nonnull LDUserBuilder *)iBuilder withUser:(nonnull LDUserModel *)iUser;
+ (nonnull LDUserBuilder *)currentBuilder:(nonnull LDUserModel *)iUser;

@end
