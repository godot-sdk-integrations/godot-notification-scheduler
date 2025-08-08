//
// © 2024-present https://github.com/cengiz-pz
//

#ifndef notification_data_h
#define notification_data_h

#import <Foundation/Foundation.h>
#import <UserNotifications/UserNotifications.h>

#include "core/object/class_db.h"

extern const String NOTIFICATION_ID_PROPERTY;
extern const String NOTIFICATION_CHANNEL_ID_PROPERTY;
extern const String NOTIFICATION_TITLE_PROPERTY;
extern const String NOTIFICATION_CONTENT_PROPERTY;
extern const String NOTIFICATION_SMALL_ICON_NAME_PROPERTY;
extern const String NOTIFICATION_DELAY_PROPERTY;
extern const String NOTIFICATION_DEEPLINK_PROPERTY;
extern const String NOTIFICATION_INTERVAL_PROPERTY;
extern const String NOTIFICATION_BADGE_COUNT_PROPERTY;
extern const String NOTIFICATION_RESTART_APP_PROPERTY;

@interface NotificationData : NSObject

@property (nonatomic) NSInteger notificationId;
@property (nonatomic, strong) NSString* channelId;
@property (nonatomic, strong) NSString* title;
@property (nonatomic, strong) NSString* content;
@property (nonatomic, strong) NSString* smallIconName;
@property (nonatomic) NSInteger delay;
@property (nonatomic, strong) NSString* deeplink;
@property (nonatomic) NSInteger interval;
@property (nonatomic) NSInteger badgeCount;
@property (nonatomic) BOOL restartApp;
@property (nonatomic, strong) UNMutableNotificationContent* notificationContent; // Renamed to avoid conflict

- (instancetype) initWithDictionary:(Dictionary) notificationData;

@end

#endif /* notification_data_h */
