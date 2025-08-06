//
// © 2024-present https://github.com/cengiz-pz
//

#import "notification_data.h"

#import "nsp_converter.h"


const String NOTIFICATION_ID_PROPERTY = "notification_id";
const String NOTIFICATION_CHANNEL_ID_PROPERTY = "channel_id";
const String NOTIFICATION_TITLE_PROPERTY = "title";
const String NOTIFICATION_CONTENT_PROPERTY = "content";
const String NOTIFICATION_SMALL_ICON_NAME_PROPERTY = "small_icon_name";
const String NOTIFICATION_DELAY_PROPERTY = "delay";
const String NOTIFICATION_DEEPLINK_PROPERTY = "deeplink";
const String NOTIFICATION_INTERVAL_PROPERTY = "interval";
const String NOTIFICATION_RESTART_APP_PROPERTY = "restart_app";


@implementation NotificationData

- (instancetype) initWithDictionary:(Dictionary) notificationData {
	if ((self = [super init])) {
		self.notificationId = [NSPConverter toNsNumber:notificationData[NOTIFICATION_ID_PROPERTY]].integerValue;
		self.channelId = [NSPConverter toNsString:(String) notificationData[NOTIFICATION_CHANNEL_ID_PROPERTY]];
		self.title = [NSPConverter toNsString:(String) notificationData[NOTIFICATION_TITLE_PROPERTY]];
		self.content = [NSPConverter toNsString:(String) notificationData[NOTIFICATION_CONTENT_PROPERTY]];
		self.smallIconName = [NSPConverter toNsString:(String) notificationData[NOTIFICATION_SMALL_ICON_NAME_PROPERTY]];
		if (notificationData.has(NOTIFICATION_DELAY_PROPERTY)) {
			self.delay = [NSPConverter toNsNumber:notificationData[NOTIFICATION_DELAY_PROPERTY]].integerValue;;
		}
		else {
			self.delay = 0;
		}
		if (notificationData.has(NOTIFICATION_DEEPLINK_PROPERTY)) {
			self.deeplink = [NSPConverter toNsString:(String) notificationData[NOTIFICATION_DEEPLINK_PROPERTY]];
		}
		if (notificationData.has(NOTIFICATION_INTERVAL_PROPERTY)) {
			self.interval = [NSPConverter toNsNumber:notificationData[NOTIFICATION_INTERVAL_PROPERTY]].integerValue;;
		}
		else {
			self.interval = 0;
		}
		if (notificationData.has(NOTIFICATION_RESTART_APP_PROPERTY)) {
			self.restartApp = YES;
		}
		else {
			self.restartApp = NO;
		}
	}
	return self;
}

@end
