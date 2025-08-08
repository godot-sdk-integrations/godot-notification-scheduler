//
// © 2024-present https://github.com/cengiz-pz
//

#ifndef nsp_converter_h
#define nsp_converter_h

#import <Foundation/Foundation.h>
#include "core/string/ustring.h"
#include "core/object/class_db.h"


@interface NSPConverter : NSObject

// From Godot
+ (NSString*) toNsString:(String) godotString;
+ (NSNumber*) toNsNumber:(Variant) v;


// To Godot
+ (String)nsStringToGodotString:(NSString *)nsString;
+ (Dictionary) nsDictionaryToGodotDictionary:(NSDictionary*) nsDictionary;
+ (Dictionary) nsUrlToGodotDictionary:(NSURL*) status;

@end

#endif /* nsp_converter_h */
