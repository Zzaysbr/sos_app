#import "FlutterNearbyConnectionsPlugin.h"
#import <flutter_nearby_connections_plus/flutter_nearby_connections_plus-Swift.h>

@implementation FlutterNearbyConnectionsPlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    [SwiftFlutterNearbyConnectionsPlugin registerWithRegistrar:registrar];
}

@end