//
// © 2024-present https://github.com/cengiz-pz
//

#ifndef nsp_notification_h
#define nsp_notification_h

#import <UserNotifications/UserNotifications.h>

#import "notification_data.h"


@interface NSPNotification : NSObject

@property (nonatomic,strong) NSString* notificationId;
@property (nonatomic,strong) UNMutableNotificationContent* content;
@property (nonatomic,assign) int repeatInterval;


- (instancetype) initWithId:(int) id;
- (void) schedule:(NotificationData*) notificationData;
- (void) scheduleRepeating;

@end

#endif /* nsp_notification_h */
