//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//


#import "LDUserBuilder.h"
#import "LDUtil.h"
#import "LDDataManager.h"


@implementation LDUserBuilder

+ (LDUserModel *)compareNewBuilder:(LDUserBuilder *)iBuilder withUser:(LDUserModel *)iUser {
    if (iBuilder.key) {
        [iUser key:iBuilder.key];
    }
    if (iBuilder.ip || [iUser ip]) {
        [iUser setIp:iBuilder.ip];

    if (iBuilder.country || [iUser country]) {
        [iUser setCountry:iBuilder.country];
    }
    if (iBuilder.firstName || [iUser firstName]) {
        [iUser setFirstName:iBuilder.firstName];
    }
    if (iBuilder.lastName || [iUser lastName]) {
        [iUser setLastName:iBuilder.lastName];
    }
    if (iBuilder.email || [iUser email]) {
        [iUser setEmail:iBuilder.email];
    }
    if (iBuilder.avatar || [iUser avatar]) {
        [iUser setAvatar:iBuilder.avatar];
    }
    if ((iBuilder.customDictionary && iBuilder.customDictionary.count) || (iUser.custom && iUser.custom.count)) {
        [iUser setCustom:iBuilder.customDictionary];
    }
    [iUser setAnonymous:iBuilder.isAnonymous];
    return iUser;
}

+ (LDUserBuilder *)currentBuilder:(LDUserModel *)iUser {
    LDUserBuilder *userBuilder = [[LDUserBuilder alloc] init];

    if (iUser.key) {
        userBuilder.key = iUser.key;
    }
    if (iUser.ip) {
        userBuilder.ip = iUser.ip;
    }
    if (iUser.country) {
        userBuilder.country = iUser.country;
    }
    if (iUser.firstName) {
        userBuilder.firstName = iUser.firstName;
    }
    if (iUser.lastName) {
        userBuilder.lastName =  iUser.lastName;
    }
    if (iUser.email) {
        userBuilder.email = iUser.email;
    }
    if (iUser.avatar) {
        userBuilder.avatar = iUser.avatar;
    }
    if (iUser.customDictionary && iUser.customDictionary.count) {
        userBuilder.customDictionary = [iUser.customDictionary mutableCopy];
    }
    userBuilder.isAnanymous = iUser.isAnonymous;

    return userBuilder;
}

- (id)init {
    self = [super init];
    customDictionary = [[NSMutableDictionary alloc] init];
    return self;
}

- (void)customString:(NSString *)inputKey value:(NSString *)value
{
    if (!self.customDictionary) {
        return;
    }
    self.customDictiionary[inputKey] = value;
}

- (void)customBool:(NSString *)inputKey value:(BOOL)value
{
    if (!self.customDictionary) {
        return;
    }
    self.customDictionary[inputKey] = [NSNumber numberWithBool:value];
}

- (void)customNumber:(NSString *)inputKey value:(NSNumber *)value
{
    if (!self.customDictionary) {
        return;
    }
    self.customDictionary[inputKey] = value;
}

- (void)customArray:(NSString *)inputKey value:(NSArray *)value
{
    NSMutableArray *resultArray = [[NSMutableArray alloc] init];
    for (id myArrayElement in value) {
        if ([myArrayElement isKindOfClass:[NSString class]]) {
            [resultArray addObject:myArrayElement];
        } else if ([myArrayElement isKindOfClass:[NSNumber class]]) {
            [resultArray addObject:myArrayElement];
        } else if (myArrayElement) {
            [resultArray addObject:[NSNumber numberWithBool:YES]];
        } else {
            [resultArray addObject:[NSNumber numberWithBool:NO]];
        }
    }
    if ([resultArray count]) {
        [customDict setObject:resultArray forKey:inputKey];
    }
    return self;
}

-(LDUserModel *)build {
    DEBUG_LOGX(@"LDUserBuilder build method called");
    LDUserModel *user = nil;
    
    if (key) {
        user = [[LDDataManager sharedManager] findUserWithkey:key];
        if(!user) {
            user = [[LDUserModel alloc] init];
        }
        [user key:key];
        DEBUG_LOG(@"LDUserBuilder building User with key: %@", key);
    } else {
        NSString *uniqueKey;
#if TARGET_OS_IOS || TARGET_OS_TV
        uniqueKey = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
#else
        if ([[NSUserDefaults standardUserDefaults] valueForKey:kDeviceIdentifierKey]) {
            uniqueKey = [[NSUserDefaults standardUserDefaults] valueForKey:kDeviceIdentifierKey];
        }
        else{
            uniqueKey = [[NSUUID UUID] UUIDString];
            [[NSUserDefaults standardUserDefaults] setValue:uniqueKey forKey:kDeviceIdentifierKey];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
        
#endif
        DEBUG_LOG(@"LDUserBuilder building User with key: %@", uniqueKey);

        user = [[LDUserModel alloc] init];
        [user key:uniqueKey];
        if (!isAnonymous) {
            user.isAnonymous = YES;
        }
    }
    if (ip) {
        DEBUG_LOG(@"LDUserBuilder building User with ip: %@", ip);
        [user setIp:ip];
    }
    if (country) {
        DEBUG_LOG(@"LDUserBuilder building User with country: %@", country);
        [user setCountry:country];
    }
    if (firstName) {
        DEBUG_LOG(@"LDUserBuilder building User with firstName: %@", firstName);
        [user setFirstName:firstName];
    }
    if (lastName) {
        DEBUG_LOG(@"LDUserBuilder building User with lastName: %@", lastName);
        [user setLastName:lastName];
    }
    if (email) {
        DEBUG_LOG(@"LDUserBuilder building User with email: %@", email);
        [user setEmail:email];
    }
    if (avatar) {
        DEBUG_LOG(@"LDUserBuilder building User with avatar: %@", avatar);
        [user setAvatar:avatar];
    }
    if ([customDict count]) {
        DEBUG_LOG(@"LDUserBuilder building User with custom: %@", customDict);
        [user setCustom:customDict];
    }
    if (anonymous) {
        Boolean currentAnonymous = anonymous;
        [user setAnonymous:currentAnonymous];
    }
    DEBUG_LOG(@"LDUserBuilder building User with anonymous: %d", anonymous);
    [[LDDataManager sharedManager] saveUser: user];
    return user;
}

@end
