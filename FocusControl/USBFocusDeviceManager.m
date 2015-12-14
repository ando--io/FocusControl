/*
 FocusControl

 
 Copyright (C) 2015  ando.io
 
 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
 
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#import "USBFocusDeviceManager.h"
#import "USBFocusDeviceImpl.h"
#import "USBUtil.h"
#import <ORSSerial/ORSSerialPort.h>

static USBFocusDeviceManager *gSharedInstance;

@implementation USBFocusDeviceManager {
   dispatch_queue_t backgroundQueue_;
   NSMutableArray * devices_;
   
}

+(USBFocusDeviceManager *) sharedUSBFocusDeviceManager {
   static dispatch_once_t onceToken;
   dispatch_once(&onceToken, ^{
      if (gSharedInstance == nil)
         gSharedInstance = [(USBFocusDeviceManager *)[super allocWithZone:NULL] init];
   });
   return gSharedInstance;
}

- (instancetype)init
{
   self = [super init];
   if (self) {
      devices_ = [NSMutableArray new];
      backgroundQueue_ = dispatch_queue_create("bg", DISPATCH_QUEUE_SERIAL);
   }
   return self;
}

-(NSObject<USBFocusDevice>*) deviceAtPath:(NSString *) path {
   USBFocusDevice * d= [[USBFocusDevice alloc] initWithPort:[[ORSSerialPort alloc]initWithPath:path] queue:backgroundQueue_];
   [devices_ addObject:d];
   return d;
}

-(void)stopAllMoves {
   [devices_ enumerateObjectsUsingBlock:^(id<USBFocusDevice> device, NSUInteger idx, BOOL * _Nonnull stop) {
      [device stop];
   }];
}

-(NSArray *)availableDevices {
   return devices_;
}

@end
