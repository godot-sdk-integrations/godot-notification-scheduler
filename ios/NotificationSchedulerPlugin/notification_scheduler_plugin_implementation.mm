//
// © 2024-present https://github.com/cengiz-pz
//

#import <Foundation/Foundation.h>
#import <UserNotifications/UserNotifications.h>
#import <UIKit/UIKit.h>

#include "core/config/project_settings.h"
#include "core/error/error_macros.h"
#import "notification_scheduler_plugin_implementation.h"
#import "nsp_converter.h"
#import "channel_data.h"

String const INITIALIZATION_COMPLETED = "initialization_completed";
String const NOTIFICATION_OPENED_SIGNAL = "notification_opened";
String const NOTIFICATION_DISMISSED_SIGNAL = "notification_dismissed";
String const PERMISSION_GRANTED_SIGNAL = "permission_granted";
String const PERMISSION_DENIED_SIGNAL = "permission_denied";

NotificationSchedulerPlugin* NotificationSchedulerPlugin::instance = NULL;

void NotificationSchedulerPlugin::_bind_methods() {
    ClassDB::bind_method(D_METHOD("initialize"), &NotificationSchedulerPlugin::initialize);
    ClassDB::bind_method(D_METHOD("has_post_notifications_permission"), &NotificationSchedulerPlugin::has_post_notifications_permission);
    ClassDB::bind_method(D_METHOD("request_post_notifications_permission"), &NotificationSchedulerPlugin::request_post_notifications_permission);
    ClassDB::bind_method(D_METHOD("create_notification_channel"), &NotificationSchedulerPlugin::create_notification_channel);
    ClassDB::bind_method(D_METHOD("schedule"), &NotificationSchedulerPlugin::schedule);
    ClassDB::bind_method(D_METHOD("cancel"), &NotificationSchedulerPlugin::cancel);
    ClassDB::bind_method(D_METHOD("set_badge_count"), &NotificationSchedulerPlugin::set_badge_count);
    ClassDB::bind_method(D_METHOD("get_notification_id"), &NotificationSchedulerPlugin::get_notification_id);
    ClassDB::bind_method(D_METHOD("open_app_info_settings"), &NotificationSchedulerPlugin::open_app_info_settings);

    ADD_SIGNAL(MethodInfo(INITIALIZATION_COMPLETED));
    ADD_SIGNAL(MethodInfo(NOTIFICATION_OPENED_SIGNAL, PropertyInfo(Variant::INT, "notification_id")));
    ADD_SIGNAL(MethodInfo(NOTIFICATION_DISMISSED_SIGNAL, PropertyInfo(Variant::INT, "notification_id")));
    ADD_SIGNAL(MethodInfo(PERMISSION_GRANTED_SIGNAL, PropertyInfo(Variant::STRING, "permission_name")));
    ADD_SIGNAL(MethodInfo(PERMISSION_DENIED_SIGNAL, PropertyInfo(Variant::STRING, "permission_name")));
}

Error NotificationSchedulerPlugin::initialize() {
    NSLog(@"NotificationSchedulerPlugin initialize");
    if (is_initialized) {
        NSLog(@"NotificationSchedulerPlugin: ERROR: Already initialized");
        return ERR_ALREADY_IN_USE;
    }

    // Restore persisted notifications
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *allDefaults = [defaults dictionaryRepresentation];
    for (NSString *key in allDefaults) {
        if ([key hasPrefix:@"NSPNotification_"]) {
            NSDictionary *notificationDict = [defaults objectForKey:key];
            NotificationData *notificationData = [[NotificationData alloc] init];
            notificationData.notificationId = [notificationDict[@"notificationId"] intValue];
            notificationData.title = notificationDict[@"title"];
            notificationData.content = notificationDict[@"content"];
            notificationData.channelId = notificationDict[@"channelId"];
            notificationData.delay = [notificationDict[@"delay"] doubleValue];
            notificationData.interval = [notificationDict[@"interval"] intValue];
            notificationData.badgeCount = [notificationDict[@"badgeCount"] intValue];

            // Validate repeatInterval
            if (notificationData.interval > 0 && notificationData.interval < 60) {
                NSLog(@"NotificationSchedulerPlugin: WARNING: Skipping restoration of notification %@ due to invalid repeatInterval %ld", notificationDict[@"notificationId"], (long)notificationData.interval);
                [defaults removeObjectForKey:key];
                continue;
            }

            NSLog(@"NotificationSchedulerPlugin: Restoring notification ID: %@ with repeatInterval: %ld", notificationDict[@"notificationId"], (long)notificationData.interval);
            notifications[notificationDict[@"notificationId"]] = notificationData;

            // Reschedule repeating notifications if needed
            if (notificationData.interval >= 60) {
                NSLog(@"NotificationSchedulerPlugin: Rescheduling repeating notification ID: %@", notificationDict[@"notificationId"]);
                schedule_repeating_notification(notificationData);
            }
        }
    }
    [defaults synchronize];

    _process_queued_notifications();

    is_initialized = true;
    call_deferred("emit_signal", INITIALIZATION_COMPLETED);

    return OK;
}

bool NotificationSchedulerPlugin::has_post_notifications_permission() {
    if (!is_initialized) {
        NSLog(@"NotificationSchedulerPlugin: ERROR: Plugin not initialized");
        return false;
    }
    NSLog(@"NotificationSchedulerPlugin has_post_notifications_permission");
    bool has_authorization = false;
    switch(authorizationStatus) {
        case UNAuthorizationStatusAuthorized:
        case UNAuthorizationStatusProvisional:
        case UNAuthorizationStatusEphemeral:
            has_authorization = true;
            break;
        case UNAuthorizationStatusDenied:
        case UNAuthorizationStatusNotDetermined:
            has_authorization = false;
            break;
        default:
            has_authorization = false;
    }
    return has_authorization;
}

Error NotificationSchedulerPlugin::request_post_notifications_permission() {
    if (!is_initialized) {
        NSLog(@"NotificationSchedulerPlugin: ERROR: Plugin not initialized");
        return ERR_UNCONFIGURED;
    }
    NSLog(@"NotificationSchedulerPlugin request_post_notifications_permission");
    UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
    [center requestAuthorizationWithOptions:(UNAuthorizationOptionSound | UNAuthorizationOptionAlert | UNAuthorizationOptionBadge)
                completionHandler: ^(BOOL granted, NSError * _Nullable error) {
        if (error) {
            NSLog(@"ERROR: Unable to request notification authorization: %@", error.localizedDescription);
        } else {
            if (granted) {
                this->authorizationStatus = UNAuthorizationStatusAuthorized;
                this->call_deferred("emit_signal", PERMISSION_GRANTED_SIGNAL, "");
            } else {
                this->authorizationStatus = UNAuthorizationStatusDenied;
                this->call_deferred("emit_signal", PERMISSION_DENIED_SIGNAL, "");
            }
        }
    }];
    return OK;
}

Error NotificationSchedulerPlugin::create_notification_channel(Dictionary dict) {
    if (!is_initialized) {
        NSLog(@"NotificationSchedulerPlugin: ERROR: Plugin not initialized");
        return ERR_UNCONFIGURED;
    }
    NSLog(@"NotificationSchedulerPlugin create_notification_channel");
    ChannelData* channelData = [[ChannelData alloc] initWithDictionary:dict];
    if (@available(iOS 11.0, *)) {
        UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
        UNNotificationCategory* newCategory = [UNNotificationCategory categoryWithIdentifier: channelData.channelId
                    actions: [NSArray array] intentIdentifiers: [NSArray array] options: UNNotificationCategoryOptionHiddenPreviewsShowTitle];
        [center setNotificationCategories: [NSSet setWithObjects:(UNNotificationCategory*) newCategory, nil]];
    } else {
        NSLog(@"ERROR: NotificationSchedulerPlugin failed to create channel. iOS 11 is required.");
    }
    return OK;
}

Error NotificationSchedulerPlugin::schedule(Dictionary dict) {
    if (!is_initialized) {
        NSLog(@"NotificationSchedulerPlugin: ERROR: Plugin not initialized");
        return ERR_UNCONFIGURED;
    }
    NSLog(@"NotificationSchedulerPlugin schedule");
    NotificationData* notificationData = [[NotificationData alloc] initWithDictionary:dict];
    
    // Validate repeatInterval
    if (notificationData.interval > 0 && notificationData.interval < 60) {
        NSLog(@"NotificationSchedulerPlugin: ERROR: repeatInterval must be at least 60 seconds for repeating notifications");
        return ERR_INVALID_PARAMETER;
    }

    schedule_notification(notificationData);
    notifications[[NSString stringWithFormat:@"%ld", (long)notificationData.notificationId]] = notificationData;

    // Persist notification data to NSUserDefaults
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *notificationDict = [NSMutableDictionary dictionary];
    notificationDict[@"notificationId"] = @(notificationData.notificationId);
    notificationDict[@"title"] = notificationData.title;
    notificationDict[@"content"] = notificationData.content;
    notificationDict[@"channelId"] = notificationData.channelId;
    notificationDict[@"delay"] = @(notificationData.delay);
    notificationDict[@"interval"] = @(notificationData.interval);
    notificationDict[@"badgeCount"] = @(notificationData.badgeCount);

    NSString *key = [NSString stringWithFormat:@"NSPNotification_%ld", (long)notificationData.notificationId];
    [defaults setObject:notificationDict forKey:key];
    [defaults synchronize];

    return OK;
}

void NotificationSchedulerPlugin::schedule_notification(NotificationData* notificationData) {
    UNTimeIntervalNotificationTrigger* trigger = [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:notificationData.delay
                repeats:NO];
    
    UNNotificationRequest* request = [UNNotificationRequest requestWithIdentifier:[NSString stringWithFormat:@"%ld", (long)notificationData.notificationId]
                                                                        content:notificationData.notificationContent
                                                                        trigger:trigger];

    UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
    [center addNotificationRequest:request withCompletionHandler:^(NSError* _Nullable error) {
        if (error != nil) {
            NSLog(@"ERROR: Unable to add notification request: %@", error.localizedDescription);
        } else {
            NSLog(@"NotificationSchedulerPlugin: Successfully scheduled notification with ID: %ld, badge count: %ld", (long)notificationData.notificationId, (long)notificationData.badgeCount);
        }
    }];
}

void NotificationSchedulerPlugin::schedule_repeating_notification(NotificationData* notificationData) {
    if (notificationData.interval < 60) {
        NSLog(@"NotificationSchedulerPlugin: ERROR: repeatInterval must be at least 60 seconds for repeating notifications, got %ld", (long)notificationData.interval);
        return;
    }

    NSLog(@"NotificationSchedulerPlugin: Scheduling repeating notification with ID: %ld, interval: %ld, badge count: %ld", (long)notificationData.notificationId, (long)notificationData.interval, (long)notificationData.badgeCount);
    UNTimeIntervalNotificationTrigger* trigger = [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:notificationData.interval
                                                repeats:YES];
    UNNotificationRequest* request = [UNNotificationRequest requestWithIdentifier:[NSString stringWithFormat:@"%ld", (long)notificationData.notificationId]
                                                                        content:notificationData.notificationContent
                                                                        trigger:trigger];

    UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
    [center addNotificationRequest:request withCompletionHandler:^(NSError* _Nullable error) {
        if (error != nil) {
            NSLog(@"NotificationSchedulerPlugin: ERROR: Unable to add notification request: %@", error.localizedDescription);
        } else {
            NSLog(@"NotificationSchedulerPlugin: Successfully scheduled repeating notification with ID: %ld", (long)notificationData.notificationId);
        }
    }];
}

Error NotificationSchedulerPlugin::cancel(int notificationId) {
    if (!is_initialized) {
        NSLog(@"NotificationSchedulerPlugin: ERROR: Plugin not initialized");
        return ERR_UNCONFIGURED;
    }
    NSLog(@"NotificationSchedulerPlugin cancel");
    NSString* key = [NSString stringWithFormat:@"%d", notificationId];
    NotificationData* notificationData = [notifications objectForKey:key];
    if (notificationData == nil) {
        NSLog(@"NotificationSchedulerPlugin::cancel: ERROR: Notification with ID '%d' not found!", notificationId);
        return FAILED;
    } else {
        UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
        [center removePendingNotificationRequestsWithIdentifiers:@[key]];
        [center removeDeliveredNotificationsWithIdentifiers:@[key]];
        [notifications removeObjectForKey:key];

        // Remove persisted data from NSUserDefaults
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSString *persistKey = [NSString stringWithFormat:@"NSPNotification_%@", key];
        [defaults removeObjectForKey:persistKey];
        [defaults synchronize];
    }
    return OK;
}

void NotificationSchedulerPlugin::set_badge_count(int badgeCount) {
    if (!is_initialized) {
        NSLog(@"NotificationSchedulerPlugin: ERROR: Plugin not initialized");
        return;
    }

    NSLog(@"NotificationSchedulerPlugin set_badge_count(%d)", badgeCount);

    UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
    [center setBadgeCount: (NSInteger) badgeCount withCompletionHandler:^(NSError* _Nullable error) {
        if (error != nil) {
            NSLog(@"ERROR: Unable to set badge count: %@", error.localizedDescription);
        } else {
            NSLog(@"DEBUG: badge count has been successfully set to %d.", badgeCount);
        }
    }];
}

int NotificationSchedulerPlugin::get_notification_id(int defaultValue) {
    if (!is_initialized) {
        NSLog(@"NotificationSchedulerPlugin: ERROR: Plugin not initialized");
        return defaultValue;
    }
    if (lastReceivedNotificationId) {
        return lastReceivedNotificationId;
    } else {
        return defaultValue;
    }
}

void NotificationSchedulerPlugin::open_app_info_settings() {
    if (!is_initialized) {
        NSLog(@"NotificationSchedulerPlugin: ERROR: Plugin not initialized");
        return;
    }
    if (@available(iOS 15.4, *)) {
        NSURL *url = [[NSURL alloc] initWithString:UIApplicationOpenNotificationSettingsURLString];
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    } else {
        NSLog(@"NotificationSchedulerPlugin::open_app_info_settings: ERROR: iOS version 15.4 or greater is required!");
    }
}

void NotificationSchedulerPlugin::handle_completion(NSString* notificationId) {
    if (!is_initialized) {
        NSLog(@"NotificationSchedulerPlugin: ERROR: Plugin not initialized");
        return;
    }
    NSLog(@"NotificationSchedulerPlugin: handle_completion for ID: %@", notificationId);
    NotificationData* notificationData = [notifications objectForKey:notificationId];
    if (notificationData == nil) {
        NSLog(@"NotificationSchedulerPlugin: WARNING: Notification with ID '%@' not found in notifications dictionary!", notificationId);
    } else {
        NSLog(@"NotificationSchedulerPlugin: Found notification with ID: %@, repeatInterval: %ld", notificationId, (long)notificationData.interval);
        if (notificationData.interval >= 60) {
            NSLog(@"NotificationSchedulerPlugin: Rescheduling repeating notification for ID: %@", notificationId);
            schedule_repeating_notification(notificationData);
        } else {
            NSLog(@"NotificationSchedulerPlugin: Notification ID: %@ is not repeating (interval: %ld)", notificationId, (long)notificationData.interval);
        }
    }

    lastReceivedNotificationId = [notificationId intValue];
}

// Called at startup to process notifications queued while application was not running
void NotificationSchedulerPlugin::_process_queued_notifications() {
    NSLog(@"NotificationSchedulerPlugin _process_queued_notifications");
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *notificationId = [defaults objectForKey:@"PendingNotificationID"];
    NSString *actionIdentifier = [defaults objectForKey:@"PendingActionIdentifier"];
    
    if (notificationId && actionIdentifier) {
        NSLog(@"NotificationSchedulerPlugin: Processing queued notification ID: %@ with action: %@", notificationId, actionIdentifier);
        if ([actionIdentifier isEqualToString:UNNotificationDismissActionIdentifier]) {
            call_deferred("emit_signal", NOTIFICATION_DISMISSED_SIGNAL, [notificationId intValue]);
            call_deferred("handle_completion", [notificationId UTF8String]);
        } else if ([actionIdentifier isEqualToString:UNNotificationDefaultActionIdentifier]) {
            call_deferred("emit_signal", NOTIFICATION_OPENED_SIGNAL, [notificationId intValue]);
            call_deferred("handle_completion", [notificationId UTF8String]);
        } else {
            NSLog(@"NotificationSchedulerPlugin: WARNING: Unknown action identifier: %@", actionIdentifier);
        }
        // Clear queued notification
        [defaults removeObjectForKey:@"PendingNotificationID"];
        [defaults removeObjectForKey:@"PendingActionIdentifier"];
        [defaults synchronize];
        NSLog(@"NotificationSchedulerPlugin: Cleared queued notification data");
    } else {
        NSLog(@"NotificationSchedulerPlugin: No queued notifications found (ID: %@, Action: %@)", notificationId, actionIdentifier);
    }
}

NotificationSchedulerPlugin* NotificationSchedulerPlugin::get_singleton() {
    return instance;
}

NotificationSchedulerPlugin::NotificationSchedulerPlugin() {
    NSLog(@"NotificationSchedulerPlugin constructor - initializing");
    ERR_FAIL_COND(instance != NULL);
    is_initialized = false; // Initialize flag
    service = [NSPService shared];
    UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
    center.delegate = service;
    [center getNotificationSettingsWithCompletionHandler: ^(UNNotificationSettings * settings) {
        NSLog(@"NotificationSchedulerPlugin constructor - authorization status: %ld", (long) settings.authorizationStatus);
        this->authorizationStatus = settings.authorizationStatus;
    }];
    notifications = [NSMutableDictionary dictionaryWithCapacity:10];
    instance = this;
}

NotificationSchedulerPlugin::~NotificationSchedulerPlugin() {
    NSLog(@"NotificationSchedulerPlugin destructor");
    if (instance == this) {
        instance = NULL;
    }
}
