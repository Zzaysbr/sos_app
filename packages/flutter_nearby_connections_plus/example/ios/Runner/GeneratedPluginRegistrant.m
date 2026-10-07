//
//  Generated file. Do not edit.
//

// clang-format off

#import "GeneratedPluginRegistrant.h"

#if __has_include(<device_info/FLTDeviceInfoPlugin.h>)
#import <device_info/FLTDeviceInfoPlugin.h>
#else
@import device_info;
#endif

#if __has_include(<flutter_nearby_connections_plus/FlutterNearbyConnectionsPlugin.h>)
#import <flutter_nearby_connections_plus/FlutterNearbyConnectionsPlugin.h>
#else
@import flutter_nearby_connections_plus;
#endif

#if __has_include(<flutter_udid/FlutterUdidPlugin.h>)
#import <flutter_udid/FlutterUdidPlugin.h>
#else
@import flutter_udid;
#endif

@implementation GeneratedPluginRegistrant

+ (void)registerWithRegistry:(NSObject<FlutterPluginRegistry>*)registry {
  [FLTDeviceInfoPlugin registerWithRegistrar:[registry registrarForPlugin:@"FLTDeviceInfoPlugin"]];
  [FlutterNearbyConnectionsPlugin registerWithRegistrar:[registry registrarForPlugin:@"FlutterNearbyConnectionsPlugin"]];
  [FlutterUdidPlugin registerWithRegistrar:[registry registrarForPlugin:@"FlutterUdidPlugin"]];
}

@end
