//
// © 2024-present https://github.com/cengiz-pz
//

#import <Foundation/Foundation.h>
#import "notification_scheduler_plugin.h"
#import "notification_scheduler_plugin_implementation.h"
#import "core/config/engine.h"

NotificationSchedulerPlugin *plugin;

void notification_scheduler_plugin_init() {
	NSLog(@"NotificationSchedulerPlugin: Initializing plugin at timestamp: %f", [[NSDate date] timeIntervalSince1970]);
	plugin = memnew(NotificationSchedulerPlugin);
	Engine::get_singleton()->add_singleton(Engine::Singleton("NotificationSchedulerPlugin", plugin));
	NSLog(@"NotificationSchedulerPlugin: Singleton registered");
}

void notification_scheduler_plugin_deinit() {
	NSLog(@"NotificationSchedulerPlugin: Deinitializing plugin");
	if (plugin) {
		memdelete(plugin);
		plugin = nullptr;
	}
}
