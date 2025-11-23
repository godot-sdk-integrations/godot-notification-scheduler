//
// © 2024-present https://github.com/cengiz-pz
//

import java.util.Properties
import java.io.FileInputStream

val commonProperties = Properties().apply {
	load(FileInputStream("${rootDir}/../common/config.properties"))
}

val iosProperties = Properties().apply {
	load(FileInputStream("${rootDir}/../ios/config/config.properties"))
}

extra.apply {
	// Plugin details
	set("pluginNodeName", commonProperties.getProperty("pluginNodeName"))
	set("pluginName", "${get("pluginNodeName")}Plugin")
	set("pluginPackageName", "org.godotengine.plugin.android.notification")
	set("resultActivityClassPath", "${get("pluginPackageName")}.ResultActivity")
	set("notificationReceiverClassPath", "${get("pluginPackageName")}.NotificationReceiver")
	set("cancelReceiverClassPath", "${get("pluginPackageName")}.CancelNotificationReceiver")
	set("pluginVersion", commonProperties.getProperty("pluginVersion"))
	set("pluginArchive", "${get("pluginName")}-Android-v${get("pluginVersion")}.zip")

	// Godot
	set("godotVersion", commonProperties.getProperty("godotVersion"))
	set("releaseType", commonProperties.getProperty("godotReleaseType"))
	set("godotAarUrl", "https://github.com/godotengine/godot-builds/releases/download/${get("godotVersion")}-${get("releaseType")}/godot-lib.${get("godotVersion")}.${get("releaseType")}.template_release.aar")
	set("godotAarFile", "godot-lib-${get("godotVersion")}.${get("releaseType")}.aar")

	// Demo
	set("demoAddOnsDirectory", "../../demo/addons")
	set("demoAssetsDirectory", "../../demo/assets")

	// Godot resources
	set("templateDirectory", "../../addon")
	set("assetsDirectory", "../assets")

	// iOS
	set("iosPlatformVersion", iosProperties.getProperty("platform_version"))
	set("iosFrameworks", iosProperties.getProperty("frameworks"))
	set("iosEmbeddedFrameworks", iosProperties.getProperty("embedded_frameworks"))
	set("iosLinkerFlags", iosProperties.getProperty("flags"))
}
