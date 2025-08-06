//
// © 2024-present https://github.com/cengiz-pz
//

#import <UserNotifications/UserNotifications.h>

#import "notification_scheduler_plugin_implementation.h"
#import "nsp_converter.h"
#import "nsp_delegate.h"

@implementation NSPDelegate

- (void) userNotificationCenter:(UNUserNotificationCenter*) center
			didReceiveNotificationResponse:(UNNotificationResponse*) response
			withCompletionHandler:(void (^)()) completionHandler {
	if ([response.actionIdentifier isEqualToString:UNNotificationDismissActionIdentifier]) {
		// User dismissed the notification without taking action
		NotificationSchedulerPlugin::get_singleton()->emit_signal(NOTIFICATION_DISMISSED_SIGNAL, [response.notification.request.identifier intValue]);
		NotificationSchedulerPlugin::get_singleton()->handle_completion(response.notification.request.identifier);
	}
	else if ([response.actionIdentifier isEqualToString:UNNotificationDefaultActionIdentifier]) {
		// User launched the app
		NotificationSchedulerPlugin::get_singleton()->emit_signal(NOTIFICATION_OPENED_SIGNAL, [response.notification.request.identifier intValue]);
		NotificationSchedulerPlugin::get_singleton()->handle_completion(response.notification.request.identifier);
	}
	else {
		NSLog(@"ERROR: Unexpected action identifier: %@", response.actionIdentifier);
	}
}

- (void) userNotificationCenter:(UNUserNotificationCenter*) center
			willPresentNotification:(UNNotification*) notification
			withCompletionHandler:(void (^)(UNNotificationPresentationOptions options)) completionHandler {
	completionHandler(UNNotificationPresentationOptionSound);
	NotificationSchedulerPlugin::get_singleton()->emit_signal(NOTIFICATION_OPENED_SIGNAL, [notification.request.identifier intValue]);
	NotificationSchedulerPlugin::get_singleton()->handle_completion(notification.request.identifier);
}

- (void) userNotificationCenter:(UNUserNotificationCenter*) center openSettingsForNotification:(UNNotification*) notification {

}

@end
