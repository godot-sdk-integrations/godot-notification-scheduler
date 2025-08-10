//
// © 2024-present https://github.com/cengiz-pz
//

#ifndef notification_scheduler_plugin_implementation_h
#define notification_scheduler_plugin_implementation_h

#include "core/object/object.h"
#include "core/object/class_db.h"

#import "notification_data.h"
#import "nsp_service.h"

extern String const INITIALIZATION_COMPLETED;
extern String const NOTIFICATION_OPENED_SIGNAL;
extern String const NOTIFICATION_DISMISSED_SIGNAL;
extern String const PERMISSION_GRANTED_SIGNAL;
extern String const PERMISSION_DENIED_SIGNAL;

class NotificationSchedulerPlugin : public Object {
	GDCLASS(NotificationSchedulerPlugin, Object);

private:
	static NotificationSchedulerPlugin* instance;
	int lastReceivedNotificationId;
	UNAuthorizationStatus authorizationStatus;
	NSPService* service;
	bool is_initialized; // Track initialization state

	static void _bind_methods();
	void _process_queued_notifications();
	void _remove_notification_from_cache(NotificationData* notificationData, NSString* notificationTypeDesc = @"");
	void _remove_notification_from_UNC(NotificationData* notificationData);
	void schedule_notification(NotificationData* notificationData);
	void schedule_repeating_sequence(NotificationData* notificationData, int count);

public:
	static NotificationSchedulerPlugin* get_singleton();

	// Plugin methods
	Error initialize();
	bool has_post_notifications_permission();
	Error request_post_notifications_permission();
	Error create_notification_channel(Dictionary dict);
	Error schedule(Dictionary notificationData);
	Error cancel(int notificationId);
	Error set_badge_count(int badgeCount);
	int get_notification_id(int defaultValue);
	Error open_app_info_settings();

	// Internal methods
	void handle_completion(NSString* notificationId);

	NotificationSchedulerPlugin();
	~NotificationSchedulerPlugin();
};

#endif /* notification_scheduler_plugin_implementation_h */
