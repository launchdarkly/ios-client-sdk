//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//


#import "User.h"

@interface LDUserBuilder : NSObject {
    
}

+ (User *)compareNewBuilder:(LDUserBuilder *)iBuilder withUser:(User *)iUser;
+ (LDUserBuilder *)retrieveCurrentBuilder:(User *)iUser;

- (LDUserBuilder *)withKey:(NSString *)key;
- (LDUserBuilder *)withIp:(NSString *)ip;
- (LDUserBuilder *)withCountry:(NSString *)country;
- (LDUserBuilder *)withFirstName:(NSString *)firstName;
- (LDUserBuilder *)withLastName:(NSString *)lastName;
- (LDUserBuilder *)withEmail:(NSString *)email;
- (LDUserBuilder *)withAvatar:(NSString *)avatar;
- (LDUserBuilder *)withCustomString:(NSString *)inputKey value:(NSString *)value;
- (LDUserBuilder *)withCustomBool:(NSString *)inputKey value:(BOOL)value;
- (LDUserBuilder *)withCustomNumber:(NSString *)inputKey value:(NSNumber *)value;
- (LDUserBuilder *)withCustomArray:(NSString *)inputKey value:(NSArray *)value;
- (LDUserBuilder *)withCustomDictionary:(NSMutableDictionary *)inputDictionary;
- (LDUserBuilder *)withAnonymous:(BOOL)anonymous;

-(id)build;

@end