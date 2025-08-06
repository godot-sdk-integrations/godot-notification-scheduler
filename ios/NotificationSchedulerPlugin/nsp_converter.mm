//
// © 2024-present https://github.com/cengiz-pz
//

#import "nsp_converter.h"

@implementation NSPConverter


// FROM GODOT

+ (NSString*) toNsString:(String) godotString {
	return [NSString stringWithUTF8String:godotString.utf8().get_data()];
}

+ (NSNumber*) toNsNumber:(Variant) v {
	if (v.get_type() == Variant::FLOAT) {
		return [NSNumber numberWithDouble:(double) v];
	} else if (v.get_type() == Variant::INT) {
		return [NSNumber numberWithLongLong:(long)(int) v];
	} else if (v.get_type() == Variant::BOOL) {
		return [NSNumber numberWithBool:BOOL((bool) v)];
	}
	WARN_PRINT(String("toNsNumber::Could not convert unsupported type: '" + Variant::get_type_name(v.get_type()) + "'").utf8().get_data());
	return NULL;
}


// TO GODOT

+ (Dictionary) nsDictionaryToGodotDictionary:(NSDictionary*) nsDictionary {
	Dictionary dictionary = Dictionary();

	for (NSObject* keyObject in [nsDictionary allKeys]) {
		if (keyObject && [keyObject isKindOfClass:[NSString class]]) {
			NSString* key = (NSString*) keyObject;

			NSObject* valueObject = [nsDictionary objectForKey:key];
			if (valueObject) {
				if ([valueObject isKindOfClass:[NSString class]]) {
					NSString* value = (NSString*) valueObject;
					dictionary[[key UTF8String]] = (value) ? [value UTF8String] : "";
				}
				else if ([valueObject isKindOfClass:[NSNumber class]]) {
					NSNumber* value = (NSNumber*) valueObject;
					if (strcmp([value objCType], @encode(BOOL)) == 0) {
						dictionary[[key UTF8String]] = (int) [value boolValue];
					} else if (strcmp([value objCType], @encode(char)) == 0) {
						dictionary[[key UTF8String]] = (int) [value charValue];
					} else if (strcmp([value objCType], @encode(int)) == 0) {
						dictionary[[key UTF8String]] = [value intValue];
					} else if (strcmp([value objCType], @encode(unsigned int)) == 0) {
						dictionary[[key UTF8String]] = (int) [value unsignedIntValue];
					} else if (strcmp([value objCType], @encode(long long)) == 0) {
						dictionary[[key UTF8String]] = (int) [value longValue];
					} else if (strcmp([value objCType], @encode(float)) == 0) {
						dictionary[[key UTF8String]] = [value floatValue];
					} else if (strcmp([value objCType], @encode(double)) == 0) {
						dictionary[[key UTF8String]] = (float) [value doubleValue];
					}
				}
				else if ([valueObject isKindOfClass:[NSDictionary class]]) {
					NSDictionary* value = (NSDictionary*) valueObject;
					dictionary[[key UTF8String]] = [NSPConverter nsDictionaryToGodotDictionary:value];
				}
			}
		}
	}

	return dictionary;
}

+ (Dictionary) nsUrlToGodotDictionary:(NSURL*) url {
	Dictionary dictionary;

	dictionary["scheme"] = [url.scheme UTF8String];
	dictionary["user"] = [url.user UTF8String];
	dictionary["password"] = [url.password UTF8String];
	dictionary["host"] = [url.host UTF8String];
	dictionary["port"] = [url.port intValue];
	dictionary["path"] = [url.path UTF8String];
	dictionary["pathExtension"] = [url.pathExtension UTF8String];
	dictionary["pathComponents"] = url.pathComponents;
	dictionary["parameterString"] = [url.parameterString UTF8String];
	dictionary["query"] = [url.query UTF8String];
	dictionary["fragment"] = [url.fragment UTF8String];

	return dictionary;
}

@end
