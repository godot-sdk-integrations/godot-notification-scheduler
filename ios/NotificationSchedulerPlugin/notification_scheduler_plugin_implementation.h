//
// © 2024-present https://github.com/cengiz-pz
//

#ifndef notification_scheduler_plugin_implementation_h
#define notification_scheduler_plugin_implementation_h

#include "core/object/object.h"
#include "core/object/class_db.h"

#import "nsp_notification.h"
#import "nsp_delegate.h"


extern String const NOTIFICATION_OPENED_SIGNAL;
extern String const NOTIFICATION_DISMISSED_SIGNAL;
extern String const PERMISSION_GRANTED_SIGNAL;
extern String const PERMISSION_DENIED_SIGNAL;

extern String const NSP_DATA_KEY_ID;
extern String const NSP_DATA_KEY_TITLE;
extern String const NSP_DATA_KEY_CONTENT;
extern String const NSP_DATA_KEY_CATEGORY_ID;


class NotificationSchedulerPlugin : public Object {
	GDCLASS(NotificationSchedulerPlugin, Object);

private:

	static NotificationSchedulerPlugin* instance;

	int lastReceivedNotificationId;

	UNAuthorizationStatus authorizationStatus;
	NSPDelegate* delegate;
	NSMutableDictionary<NSString*, NSPNotification*>* notifications;

	static void _bind_methods();
	
public:
	
	bool has_post_notifications_permission();
	Error request_post_notifications_permission();

	Error create_notification_channel(Dictionary dict);

	Error schedule(Dictionary notificationData);
	Error cancel(int notificationId);
	int get_notification_id(int defaultValue);
	void open_app_info_settings();

	void handle_completion(NSString* notificationId);

	static NotificationSchedulerPlugin* get_singleton();

	NotificationSchedulerPlugin();
	~NotificationSchedulerPlugin();
};

#endif /* notification_scheduler_plugin_implementation_h */
