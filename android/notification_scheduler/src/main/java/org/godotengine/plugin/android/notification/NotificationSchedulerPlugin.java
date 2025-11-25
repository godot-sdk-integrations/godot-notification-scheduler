//
// © 2024-present https://github.com/cengiz-pz
//

package org.godotengine.plugin.android.notification;

import static android.content.Context.ALARM_SERVICE;
import static android.content.Context.NOTIFICATION_SERVICE;

import android.Manifest;
import android.app.Activity;
import android.app.AlarmManager;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.icu.util.Calendar;
import android.os.Build;
import android.os.Bundle;
import android.util.Log;
import android.view.View;
import android.provider.Settings;
import android.net.Uri;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.RequiresApi;
import androidx.collection.ArraySet;
import androidx.core.app.ActivityCompat;
import androidx.core.app.NotificationManagerCompat;

import org.godotengine.godot.Dictionary;
import org.godotengine.godot.Godot;
import org.godotengine.godot.error.Error;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;
import org.godotengine.plugin.android.notification.model.ChannelData;
import org.godotengine.plugin.android.notification.model.NotificationData;

import java.util.Set;

public class NotificationSchedulerPlugin extends GodotPlugin {
	public static final String LOG_TAG = "godot::" + NotificationSchedulerPlugin.class.getSimpleName();

	static NotificationSchedulerPlugin instance;

	private static final SignalInfo INITIALIZATION_COMPLETED_SIGNAL = new SignalInfo("initialization_completed");

	private static final SignalInfo PERMISSION_GRANTED_SIGNAL = new SignalInfo("permission_granted", String.class);
	private static final SignalInfo PERMISSION_DENIED_SIGNAL = new SignalInfo("permission_denied", String.class);
	private static final SignalInfo NOTIFICATION_OPENED_SIGNAL = new SignalInfo("notification_opened", Dictionary.class);
	private static final SignalInfo NOTIFICATION_DISMISSED_SIGNAL = new SignalInfo("notification_dismissed", Dictionary.class);

	private static final int POST_NOTIFICATIONS_PERMISSION_REQUEST_CODE = 11803;

	private Activity activity;
	private boolean isInitialized;

	public NotificationSchedulerPlugin(Godot godot) {
		super(godot);
		isInitialized = false;
	}

	/**
	 * Initializes plugin.
	 */
	@UsedByGodot
	public void initialize() {
		isInitialized = true;

		// Nothing to do on Android version (implemented for platform parity)
		emitSignal(getGodot(), getPluginName(), INITIALIZATION_COMPLETED_SIGNAL);
	}

	/**
	 * Creates a notification channel with given ID. If a channel already exists with the given ID,
	 * then the call will be ignored.
	 *
	 * @param data dictionary containing channel ID, channel name, and channel description
	 */
	@RequiresApi(api = Build.VERSION_CODES.O)
	@UsedByGodot
	public int create_notification_channel(Dictionary data) {
		if (!isInitialized) {
			Log.e(LOG_TAG, "create_notification_channel(): plugin is not initialized!");
			return Error.ERR_UNCONFIGURED.toNativeValue();
		}

		ChannelData channelData = new ChannelData(data);
		if (channelData.isValid()) {
			NotificationManager manager = (NotificationManager) activity.getSystemService(NOTIFICATION_SERVICE);

			// Check if channel already exists
			if (manager.getNotificationChannel(channelData.getId()) == null) {
				NotificationChannel channel = new NotificationChannel(channelData.getId(), channelData.getName(),
						channelData.getImportance());
				channel.setDescription(channelData.getDescription());
				channel.setShowBadge(channelData.getBadgeEnabled());
				manager.createNotificationChannel(channel);
				Log.d(LOG_TAG, String.format("%s():: channel id: %s, name: %s, description: %s",
						"create_notification_channel", channelData.getId(), channelData.getName(), channelData.getDescription()));
			} else {
				Log.d(LOG_TAG, String.format("%s():: channel id: %s already exists",
						"create_notification_channel", channelData.getId()));
				return Error.ERR_ALREADY_EXISTS.toNativeValue();
			}
		} else {
			Log.e(LOG_TAG, "create_notification_channel(): invalid channel data object");
			return Error.ERR_INVALID_DATA.toNativeValue();
		}

		return Error.OK.toNativeValue();
	}

	/**
	 * Schedule single, non-repeating notification
	 *
	 * @param data dictionary containing notification data, including delaySeconds that specifies
	 *				how many seconds from now to schedule the notification.
	 */
	@UsedByGodot
	public int schedule(Dictionary data) {
		if (!isInitialized) {
			Log.e(LOG_TAG, "schedule(): plugin is not initialized!");
			return Error.ERR_UNCONFIGURED.toNativeValue();
		}

		NotificationData notificationData = new NotificationData(data);
		Log.d(LOG_TAG, "schedule():: notification id: " + notificationData.getId());

		if (notificationData.isValid()) {
			if (notificationData.hasInterval()) {
				scheduleRepeatingNotification(activity, notificationData);
			} else {
				scheduleNotification(activity, notificationData);
			}
		} else {
			Log.e(LOG_TAG, "schedule(): invalid notification data object");
			return Error.ERR_INVALID_DATA.toNativeValue();
		}

		return Error.OK.toNativeValue();
	}

	/**
	 * Cancel notification with given ID
	 *
	 * @param notificationId ID of notification to cancel
	 */
	@UsedByGodot
	public int cancel(int notificationId) {
		if (!isInitialized) {
			Log.e(LOG_TAG, "cancel(): plugin is not initialized!");
			return Error.ERR_UNCONFIGURED.toNativeValue();
		}

		cancelNotification(activity, notificationId);
		Log.d(LOG_TAG, "cancel():: notification id: " + notificationId);

		return Error.OK.toNativeValue();
	}

	@UsedByGodot
	public int set_badge_count(int badgeCount) {
		if (!isInitialized) {
			Log.e(LOG_TAG, "set_badge_count(): plugin is not initialized!");
			return Error.ERR_UNCONFIGURED.toNativeValue();
		}

		Log.e(LOG_TAG, "set_badge_count(): method not supported on Android");
		return Error.ERR_UNAVAILABLE.toNativeValue();
	}

	/**
	 * Return notification ID if it exists in current intent, else return {@code defaultValue}
	 *
	 * @param defaultValue value to return if notification ID does not exist
	 */
	@UsedByGodot
	public int get_notification_id(int defaultValue) {
		if (!isInitialized) {
			Log.e(LOG_TAG, "get_notification_id(): plugin is not initialized!");
			return defaultValue;
		}

		int notificationId = defaultValue;
		Activity activity = getActivity();
		if (activity != null) {
			Intent intent = getActivity().getIntent();
			if (intent.hasExtra(NotificationData.DATA_KEY_ID)) {
				notificationId = intent.getIntExtra(NotificationData.DATA_KEY_ID, defaultValue);
				Log.i(LOG_TAG, "get_notification_id():: intent with notification id: " + notificationId);
			} else {
				Log.i(LOG_TAG, "get_notification_id():: notification id not found");
			}
		}
		return notificationId;
	}

	/**
	 * Returns true if app has already been granted POST_NOTIFICATIONS permissions
	 */
	@UsedByGodot
	public boolean has_post_notifications_permission() {
		if (!isInitialized) {
			Log.e(LOG_TAG, "has_post_notifications_permission(): plugin is not initialized!");
			return false;
		}

		boolean result = false;
		if (Build.VERSION.SDK_INT > Build.VERSION_CODES.S_V2) {
			if (NotificationManagerCompat.from(activity.getApplicationContext()).areNotificationsEnabled()) {
				result = true;
			}
		} else {
			result = true;
			Log.d(LOG_TAG, "has_post_notifications_permission():: API level is " + Build.VERSION.SDK_INT);
		}
		return result;
	}

	/**
	 * Sends a request to acquire POST_NOTIFICATIONS permission for the app
	 */
	@UsedByGodot
	public int request_post_notifications_permission() {
		if (!isInitialized) {
			Log.e(LOG_TAG, "request_post_notifications_permission(): plugin is not initialized!");
			return Error.ERR_UNCONFIGURED.toNativeValue();
		}

		try {
			if (Build.VERSION.SDK_INT > Build.VERSION_CODES.S_V2) {
				ActivityCompat.requestPermissions(activity, new String[]{ Manifest.permission.POST_NOTIFICATIONS },
						POST_NOTIFICATIONS_PERMISSION_REQUEST_CODE);
			} else {
				Log.i(LOG_TAG, "request_post_notifications_permission():: can't request permission, because SDK version is " + Build.VERSION.SDK_INT);
			}
		} catch (Exception e) {
			Log.e(LOG_TAG, "request_post_notifications_permission():: Failed to request permission due to " + e.getMessage());
		}

		return Error.OK.toNativeValue();
	}

	/**
	 * Opens APP INFO settings screen
	 */
	@UsedByGodot
	public int open_app_info_settings() {
		if (!isInitialized) {
			Log.e(LOG_TAG, "open_app_info_settings(): plugin is not initialized!");
			return Error.ERR_UNCONFIGURED.toNativeValue();
		}

		Log.d(LOG_TAG, "open_app_info_settings()");

		try {
			Intent intent = new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS);
			intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
			Uri uri = Uri.fromParts("package", activity.getPackageName(), null);
			intent.setData(uri);
			activity.startActivity(intent);
		} catch (Exception e) {
			Log.e(LOG_TAG, "open_app_info_settings():: Failed due to "+ e.getMessage());
		}

		return Error.OK.toNativeValue();
	}

	@NonNull
	@Override
	public String getPluginName() {
		return this.getClass().getSimpleName();
	}

	@NonNull
	@Override
	public Set<SignalInfo> getPluginSignals() {
		Set<SignalInfo> signals = new ArraySet<>();
		signals.add(INITIALIZATION_COMPLETED_SIGNAL);
		signals.add(NOTIFICATION_OPENED_SIGNAL);
		signals.add(NOTIFICATION_DISMISSED_SIGNAL);
		signals.add(PERMISSION_GRANTED_SIGNAL);
		signals.add(PERMISSION_DENIED_SIGNAL);
		return signals;
	}

	@Nullable
	@Override
	public View onMainCreate(Activity activity) {
		this.activity = activity;
		instance = this;
		return super.onMainCreate(activity);
	}

	@Override
	public void onGodotSetupCompleted() {
		super.onGodotSetupCompleted();
		if (this.activity != null) {
			if (Build.VERSION.SDK_INT > Build.VERSION_CODES.S_V2) {
				if (NotificationManagerCompat.from(this.activity.getApplicationContext()).areNotificationsEnabled()) {
					Log.i(LOG_TAG, "onGodotSetupCompleted():: POST_NOTIFICATIONS permission has already been granted");
				}
			}

			NotificationData notificationData = new NotificationData(this.activity.getIntent());
			if (notificationData.isValid()) {
				handleNotificationOpened(notificationData);
			}
		} else {
			Log.e(LOG_TAG, "onGodotSetupCompleted():: activity is null!");
		}
	}

	@Override
	public void onMainDestroy() {
		instance = null;
		super.onMainDestroy();
	}

	@Override
	public void onMainRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
		super.onMainRequestPermissionsResult(requestCode, permissions, grantResults);

		if (Build.VERSION.SDK_INT > Build.VERSION_CODES.S_V2) {
			if (requestCode == POST_NOTIFICATIONS_PERMISSION_REQUEST_CODE) {
				// If request is cancelled, the result arrays are empty.
				if (grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
					Log.d(LOG_TAG, "onMainRequestPermissionsResult():: permission request granted");
					emitSignal(getGodot(), getPluginName(), PERMISSION_GRANTED_SIGNAL, Manifest.permission.POST_NOTIFICATIONS);
				} else {
					Log.d(LOG_TAG, "onMainRequestPermissionsResult():: permission request denied");
					emitSignal(getGodot(), getPluginName(), PERMISSION_DENIED_SIGNAL, Manifest.permission.POST_NOTIFICATIONS);
				}
			}
		} else {
			Log.e(LOG_TAG, "onMainRequestPermissionsResult():: can't check permission result, because SDK version is " + Build.VERSION.SDK_INT);
		}
	}

	static void handleNotificationOpened(NotificationData notificationData) {
		if (instance != null) {
			instance.emitSignal(instance.getGodot(), instance.getPluginName(), NOTIFICATION_OPENED_SIGNAL, notificationData.getRawData());
		} else {
			Log.e(LOG_TAG, String.format("%s():: Plugin instance not found!.", "handleNotificationOpened"));
		}
	}

	static void handleNotificationDismissed(NotificationData notificationData) {
		if (instance != null) {
			instance.emitSignal(instance.getGodot(), instance.getPluginName(), NOTIFICATION_DISMISSED_SIGNAL, notificationData.getRawData());
		} else {
			Log.e(LOG_TAG, String.format("%s():: Plugin instance not found!.", "handleNotificationDismissed"));
		}
	}

	private long calculateTimeAfterDelay(int delaySeconds) {
		Calendar calendar = Calendar.getInstance();
		calendar.add(Calendar.SECOND, delaySeconds);
		return calendar.getTimeInMillis();
	}

	private void scheduleNotification(Activity activity, NotificationData notificationData) {
		@SuppressWarnings("ConstantConditions") int notificationId = notificationData.getId();

		Intent intent = new Intent(activity.getApplicationContext(), NotificationReceiver.class);
		notificationData.populateIntent(intent);

		AlarmManager alarmManager = (AlarmManager) activity.getSystemService(ALARM_SERVICE);
		long timeAfterDelay = calculateTimeAfterDelay(notificationData.getDelay());
		alarmManager.set(AlarmManager.RTC_WAKEUP, timeAfterDelay,
				PendingIntent.getBroadcast(activity.getApplicationContext(), notificationId, intent,
						PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE));
		Log.i(LOG_TAG, String.format("Scheduled notification '%d' to be delivered at %d.", notificationId, timeAfterDelay));
	}

	private void scheduleRepeatingNotification(Activity activity, NotificationData notificationData) {
		@SuppressWarnings("ConstantConditions") int notificationId = notificationData.getId();

		Intent intent = new Intent(activity.getApplicationContext(), NotificationReceiver.class);
		notificationData.populateIntent(intent);

		AlarmManager alarmManager = (AlarmManager) activity.getSystemService(ALARM_SERVICE);
		long timeAfterDelay = calculateTimeAfterDelay(notificationData.getDelay());
		int intervalSeconds = notificationData.getInterval();
		alarmManager.setRepeating(AlarmManager.RTC_WAKEUP, timeAfterDelay, intervalSeconds*1000L,
				PendingIntent.getBroadcast(activity.getApplicationContext(), notificationId, intent,
						PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE));
		Log.i(LOG_TAG, String.format("Scheduled notification '%d' to be delivered at %d with %ds interval.", notificationId, timeAfterDelay, intervalSeconds));
	}

	private void cancelNotification(Activity activity, int notificationId) {
		Context context = activity.getApplicationContext();

		// cancel alarm
		AlarmManager alarmManager = (AlarmManager) activity.getSystemService(ALARM_SERVICE);
		Intent intent = new Intent(context, NotificationReceiver.class);
		intent.putExtra(NotificationData.DATA_KEY_ID, notificationId);
		alarmManager.cancel(PendingIntent.getBroadcast(activity.getApplicationContext(), notificationId, intent,
				PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE));

		// cancel notification
		NotificationManagerCompat.from(context).cancel(notificationId);
	}

}
