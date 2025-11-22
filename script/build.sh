#!/bin/bash
#
# © 2024-present https://github.com/cengiz-pz
#

set -e
trap "sleep 1; echo" EXIT

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(realpath $SCRIPT_DIR/..)
ANDROID_DIR=$ROOT_DIR/android
IOS_DIR=$ROOT_DIR/ios
DEST_DIR=$ROOT_DIR/release
DEMO_DIR=$ROOT_DIR/demo

COMMON_CONFIG_FILE=$ROOT_DIR/common/config.properties

PLUGIN_NODE_NAME=$($SCRIPT_DIR/get_config_property.sh -f $COMMON_CONFIG_FILE pluginNodeName)
PLUGIN_NAME="${PLUGIN_NODE_NAME}Plugin"
PLUGIN_VERSION=$($SCRIPT_DIR/get_config_property.sh -f $COMMON_CONFIG_FILE pluginVersion)
PLUGIN_MODULE_NAME=$($SCRIPT_DIR/get_config_property.sh -f $COMMON_CONFIG_FILE pluginModuleName)

do_clean=false
do_build_android=false
do_build_ios=false
gradle_build_task="assembleDebug"
do_create_archive=false
do_create_multiplatform_archive=false
do_uninstall=false
do_install=false
do_full_release=false


function display_help()
{
	echo
	$SCRIPT_DIR/echocolor.sh -y "The " -Y "$0 script" -y " builds the plugin and creates a zip file containing all"
	echo_yellow "libraries and configuration."
	echo
	$SCRIPT_DIR/echocolor.sh -Y "Syntax:"
	echo_yellow "	$0 [-a|c|h|i|r|R|z|Z]"
	echo
	$SCRIPT_DIR/echocolor.sh -Y "Options:"
	echo_yellow "	a	build plugin for the Android platform"
	echo_yellow "	c	remove existing Android build"
	echo_yellow "	d	uninstall plugin from demo app"
	echo_yellow "	D	install plugin to demo app"
	echo_yellow "	h	display usage information"
	echo_yellow "	i	build plugin for the iOS platform"
	echo_yellow "	r	build Android plugin with release build variant"
	echo_yellow "	R	build and create all release archives (assumes Godot is already downloaded)"
	echo_yellow "	z	create Android zip archive"
	echo_yellow "	Z	create multi-platform zip archive"
	echo
	$SCRIPT_DIR/echocolor.sh -Y "Examples:"
	echo_yellow "	* clean existing build, do a release build for Android, and create archive"
	echo_yellow "		$> $0 -carz"
	echo
	echo_yellow "	* clean existing build, do a debug build for Android"
	echo_yellow "		$> $0 -ca"
	echo
	echo_yellow "	* clean existing iOS build, remove godot, and rebuild all"
	echo_yellow "		$> $0 -i -- -cgA"
	echo_yellow "		$> $0 -i -- -cgpGHPbz"
	echo
	echo_yellow "	* clean existing iOS build and rebuild"
	echo_yellow "		$> $0 -i -- -ca"
	echo
	echo_yellow "	* display all options for the iOS build"
	echo_yellow "		$> $0 -i -- -h"
	echo
	echo_yellow "	* clean existing build, do a debug build for Android, & then do an iOS build"
	echo_yellow "		$> $0 -cai -- -ca"
	echo
	echo_yellow "	* create multi-platform release archive."
	echo_yellow "	(Requires both plugin variants to have been installed in demo app.)"
	echo_yellow "		$> $0 -Z"
	echo
}


function echo_yellow()
{
	$SCRIPT_DIR/echocolor.sh -y "$1"
}


function echo_green()
{
	$SCRIPT_DIR/echocolor.sh -g "$1"
}


function display_status()
{
	echo
	$SCRIPT_DIR/echocolor.sh -c "********************************************************************************"
	$SCRIPT_DIR/echocolor.sh -c "* $1"
	$SCRIPT_DIR/echocolor.sh -c "********************************************************************************"
	echo
}


function display_step()
{
	echo
	echo_green "* $1"
	echo
}


function display_error()
{
	$SCRIPT_DIR/echocolor.sh -r "$1"
}


function display_warning()
{
	echo_yellow "* $1"
	echo
}


function run_android_gradle_task()
{
	local gradle_task="$1"

	display_step "Running gradle task $gradle_task"

	pushd $ANDROID_DIR
	$ANDROID_DIR/gradlew $gradle_task
	popd
}


function run_ios_build()
{
	local build_arguments="$1"

	display_step "Running iOS build script with opts: $build_arguments"

	$SCRIPT_DIR/build_ios.sh "$build_arguments"
}


function create_multi_platform_archive()
{
	display_step "Creating multi-platform release archive"

	if [[ -d "$DEMO_DIR" ]]
	then
		if [[ ! -d "$DEST_DIR" ]]
		then
			mkdir -p $DEST_DIR
		fi

		local zip_file_name="$PLUGIN_NAME-Multi-v$PLUGIN_VERSION.zip"

		if [[ -e "$DEST_DIR/$zip_file_name" ]]
		then
			display_warning "deleting existing $zip_file_name file..."
			rm $DEST_DIR/$zip_file_name
		fi

		local tmp_directory=$(mktemp -d)

		display_step "preparing staging directory $tmp_directory..."

		mkdir -p $tmp_directory/addons/$PLUGIN_NAME
		pushd $DEMO_DIR/addons/$PLUGIN_NAME > /dev/null
		find . -type f ! -name "*.uid" -exec rsync --relative {} $tmp_directory/addons/$PLUGIN_NAME \;
		popd > /dev/null

		mkdir -p $tmp_directory/ios/plugins
		cp -r $DEMO_DIR/ios/plugins/* $tmp_directory/ios/plugins

		# Check if the directory exists AND find can locate at least one entry inside
		if [ -d "$DEMO_DIR/ios/framework" ] && find "$DEMO_DIR/ios/framework" -mindepth 1 -print -quit 2>/dev/null | grep -q .; then
			mkdir -p $tmp_directory/ios/framework
			cp -r "$DEMO_DIR/ios/framework/"* "$tmp_directory/ios/framework"
		else
			display_warning "Skipping copy: $DEMO_DIR/ios/framework is empty or does not exist."
		fi

		display_step "creating $zip_file_name file in $DEST_DIR..."
		pushd $tmp_directory > /dev/null
		zip -yr $DEST_DIR/$zip_file_name ./*
		popd > /dev/null

		echo ; display_warning "removing staging directory $tmp_directory..."
		rm -rf $tmp_directory
	else
		display_error "Error: '$DEMO_DIR' not found."
		exit 1
	fi
}


function uninstall_plugin_from_demo()
{
	display_status "Uninstalling plugin from demo app"
	if [[ -d "$DEMO_DIR/addons/$PLUGIN_NAME" ]]; then
		echo_yellow "Removing $DEMO_DIR/addons/$PLUGIN_NAME"
		rm -rf $DEMO_DIR/addons/$PLUGIN_NAME
	fi

	if [[ -d "$DEMO_DIR/ios/plugins/$PLUGIN_NAME.debug.xcframework" ]]; then
		echo_yellow "Removing $DEMO_DIR/ios/plugins/$PLUGIN_NAME.debug.xcframework"
		rm -rf $DEMO_DIR/ios/plugins/$PLUGIN_NAME.debug.xcframework
	fi

	if [[ -d "$DEMO_DIR/ios/plugins/$PLUGIN_NAME.release.xcframework" ]]; then
		echo_yellow "Removing $DEMO_DIR/ios/plugins/$PLUGIN_NAME.release.xcframework"
		rm -rf $DEMO_DIR/ios/plugins/$PLUGIN_NAME.release.xcframework
	fi

	if [[ -f "$DEMO_DIR/ios/plugins/$PLUGIN_NAME.gdip" ]]; then
		echo_yellow "Removing $DEMO_DIR/ios/plugins/$PLUGIN_NAME.gdip"
		rm -rf $DEMO_DIR/ios/plugins/$PLUGIN_NAME.gdip
	fi
}


function install_plugin_to_demo()
{
	display_status "Installing plugin to demo app"
	if [[ -f "$IOS_DIR/build/release/$PLUGIN_NAME-iOS-v$PLUGIN_VERSION.zip" ]]; then
		$SCRIPT_DIR/install.sh -t $DEMO_DIR -z $IOS_DIR/build/release/$PLUGIN_NAME-iOS-v$PLUGIN_VERSION.zip
	else
		display_error "Error: Cannot install to demo. '$IOS_DIR/build/release/$PLUGIN_NAME-iOS-v$PLUGIN_VERSION.zip' not found!"
	fi
}


while getopts "acdDhirRzZ" option; do
	case $option in
		h)
			display_help
			exit;;
		a)
			do_build_android=true
			;;
		c)
			do_clean=true
			;;
		d)
			do_uninstall=true
			;;
		D)
			do_install=true
			;;
		i)
			do_build_ios=true
			;;
		r)
			gradle_build_task="assembleRelease"
			;;
		R)
			do_full_release=true
			;;
		z)
			do_create_archive=true
			;;
		Z)
			do_create_multiplatform_archive=true
			;;
		\?)
			display_error "Error: invalid option"
			echo
			display_help
			exit;;
	esac
done


# Shift away the processed options
shift $((OPTIND - 1))


if [[ "$do_uninstall" == true ]]
then
	uninstall_plugin_from_demo
fi

if [[ "$do_clean" == true ]]
then
	display_status "Cleaning build"
	run_android_gradle_task clean
fi

if [[ "$do_build_android" == true ]]
then
	display_status "Building Android"
	run_android_gradle_task $gradle_build_task
fi

if [[ "$do_create_archive" == true ]]
then
	display_status "Creating Android archive"
	run_android_gradle_task "packageDistribution"
fi

if [[ "$do_build_ios" == true ]]
then
	run_ios_build "$@"
fi

if [[ "$do_create_multiplatform_archive" == true ]]
then
	display_status "Creating multi-platform archive"
	create_multi_platform_archive
fi

if [[ "$do_full_release" == true ]]
then
	uninstall_plugin_from_demo

	display_status "Creating all archives"
	run_android_gradle_task "assembleDebug"
	run_android_gradle_task "assembleRelease"
	run_android_gradle_task "packageDistribution"

	run_ios_build -cHpPbz

	install_plugin_to_demo

	rm -rf $DEST_DIR

	create_multi_platform_archive

	display_step "Copying Android release archive"
	cp $ANDROID_DIR/${PLUGIN_MODULE_NAME}/build/dist/$PLUGIN_NAME-Android-v$PLUGIN_VERSION.zip $DEST_DIR

	display_step "Copying iOS release archive"
	cp $ROOT_DIR/ios/build/release/$PLUGIN_NAME-iOS-v$PLUGIN_VERSION.zip $DEST_DIR
fi


if [[ "$do_install" == true ]]
then
	install_plugin_to_demo
fi
