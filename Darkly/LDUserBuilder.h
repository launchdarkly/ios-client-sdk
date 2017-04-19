//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//


#import "LDUserModel.h"

@interface LDUserBuilder : NSObject {
    
}

+ (LDUserModel *)compareNewBuilder:(LDUserBuilder *)iBuilder withUser:(LDUserModel *)iUser;
+ (LDUserBuilder *)retrieveCurrentBuilder:(LDUserModel *)iUser;

/**
 * Provide a key to the user builder to identify the user. If this key
 * is not provided, one will be auto-generated. (Optional)
 *
 * @param key    the key for the user
 * @return the user builder
 */
- (LDUserBuilder *)withKey:(NSString *)key;
/**
 * Provide the ip address of the user. (Optional)
 *
 * @param ip    the ip of the user
 * @return the user builder
 */
- (LDUserBuilder *)withIp:(NSString *)ip;
/**
 * Provide the country of the user. (Optional)
 *
 * @param country    the country of the user
 * @return the user builder
 */
- (LDUserBuilder *)withCountry:(NSString *)country;
/**
 * Provide the first name of the user. (Optional)
 *
 * @param firstName    the firstName of the user
 * @return the user builder
 */
- (LDUserBuilder *)withFirstName:(NSString *)firstName;
/**
 * Provide the last name of the user. (Optional)
 *
 * @param lastName    the lastName of the user
 * @return the user builder
 */
- (LDUserBuilder *)withLastName:(NSString *)lastName;
/**
 * Provide the email address of the user. (Optional)
 *
 * @param email    the email of the user
 * @return the user builder
 */
- (LDUserBuilder *)withEmail:(NSString *)email;
/**
 * Provide the avatar of the user. (Optional)
 *
 * @param avatar    the avatar of the user
 * @return the user builder
 */
- (LDUserBuilder *)withAvatar:(NSString *)avatar;
/**
 * Provide custom String data for the dictionary associated with
 * the user. (Optional)
 *
 * @param inputKey    key for the data
 * @param value    value for the data
 * @return the user builder
 */
- (LDUserBuilder *)withCustomString:(NSString *)inputKey value:(NSString *)value;
/**
 * Provide custom BOOL data for the dictionary associated with
 * the user. (Optional)
 *
 * @param inputKey    key for the data
 * @param value    value for the data
 * @return the user builder
 */
- (LDUserBuilder *)withCustomBool:(NSString *)inputKey value:(BOOL)value;
/**
 * Provide custom NSNumber data for the dictionary associated with
 * the user. (Optional)
 *
 * @param inputKey    key for the data
 * @param value    value for the data
 * @return the user builder
 */
- (LDUserBuilder *)withCustomNumber:(NSString *)inputKey value:(NSNumber *)value;
/**
 * Provide custom NSArray data for the dictionary associated with
 * the user. (Optional)
 *
 * @param inputKey    key for the data
 * @param value    value for the data
 * @return the user builder
 */
- (LDUserBuilder *)withCustomArray:(NSString *)inputKey value:(NSArray *)value;
/**
 * Provide custom NSMutableDictionary data for the dictionary associated with
 * the user. (Optional)
 *
 * @param inputDictionary Dictionary to associated with the user
 * @return the user builder
 */
- (LDUserBuilder *)withCustomDictionary:(NSMutableDictionary *)inputDictionary;
/**
 * Provide whether the user is anonymous. Note, if a key is
 * auto-generated for the user, then anonymous is set to YES. Default
 * is NO. (Optional)
 *
 * @param anonymous    whether user is anonymous
 * @return the user builder
 */
- (LDUserBuilder *)withAnonymous:(BOOL)anonymous;

-(id)build;

@end
