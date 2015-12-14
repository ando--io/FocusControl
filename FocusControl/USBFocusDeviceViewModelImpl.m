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

#import "USBFocusDeviceViewModelImpl.h"
#import "USBFocusDevice.h"
#import <ReactiveCocoa/ReactiveCocoa.h>

@interface USBFocusDeviceViewModel()

@property (nonatomic, readwrite, assign) BOOL connected;
@property (nonatomic, readwrite, assign) NSUInteger position;
@property (nonatomic, readwrite, assign) float temperature;
@property (nonatomic, readwrite, assign) BOOL stepmode;
@property (nonatomic, readwrite, assign) BOOL clockwize;
@property (nonatomic, readwrite, assign) float temperatureStep;
@property (nonatomic, readwrite, assign) float temperatureThreshold;
@property (nonatomic, readwrite, assign) NSUInteger maxPosition;
@property (nonatomic, readonly, strong) id<USBFocusDevice> device;
@end

@implementation USBFocusDeviceViewModel

@synthesize connected;
@synthesize position;
@synthesize temperature;
@synthesize stepmode;
@synthesize clockwize;
@synthesize temperatureStep;
@synthesize temperatureThreshold;
@synthesize maxPosition;
@synthesize device = device_;
@synthesize positionHistory;
@synthesize temperatureHistory;
@synthesize firmware;
@synthesize speed;

-(instancetype)initWithDevice:(id<USBFocusDevice>) device {
   self = [super init];
   if (self) {
      device_ = device;
      
      RAC(self, position) = [RACObserve(device_, position) deliverOnMainThread] ;
      RAC(self, temperature) = [RACObserve(device_, temperature) deliverOnMainThread];
      RAC(self, connected) = [RACObserve(device_, connected) deliverOnMainThread];
      RAC(self, firmware) = [RACObserve(device_, firmwareVersion) deliverOnMainThread];
      
      {
         RACChannelTerminal *lt = RACChannelTo(device_, maxPosition);
         RACChannelTerminal *ft = RACChannelTo(self, maxPosition);
         [lt subscribe: ft];
         [ft subscribe: lt];
      }
      
      {
         RACChannelTerminal *lt = RACChannelTo(device_, motorSpeed);
         RACChannelTerminal *ft = RACChannelTo(self, speed);
         [lt subscribe: ft];
         [ft subscribe: lt];
      }
      
      {
         RACChannelTerminal *lt = RACChannelTo(device_, motorRotation);
         RACChannelTerminal *ft = RACChannelTo(self, clockwize);
         [[ft map:^id(id value) {return @(([value boolValue]) ? clockwiseRotation : anticlockwiseRotation);}] subscribe: lt];
         [[lt map:^id(id value) {return @(((rotation_t)[value intValue])==clockwiseRotation);}] subscribe: ft];
      }
      
      {
         RACChannelTerminal *lt = RACChannelTo(device_, motorStepmode);
         RACChannelTerminal *ft = RACChannelTo(self, stepmode);
         [[ft map:^id(id value) {return @(([value boolValue]) ? halfStepMode : fullStepMode);}] subscribe: lt];
         [[lt map:^id(id value) {return @(((step_t)[value intValue])==halfStepMode);}] subscribe: ft];
      }
      
      {
         RACChannelTerminal *lt = RACChannelTo(device_, temperatureCompensationMini);
         RACChannelTerminal *ft = RACChannelTo(self, temperatureThreshold);
         [lt subscribe: ft];
         [ft subscribe: lt];
      }
      
      {
         RACChannelTerminal *lt = RACChannelTo(device_, temperatureCoefficient);
         RACChannelTerminal *ft = RACChannelTo(self, temperatureStep);
         [lt subscribe: ft];
         [ft subscribe: lt];
      }
      
      [device_ connect];
   }
   return self;
}

- (void)dealloc
{
   [self.device disconnect];
}

-(void) moveToPosition:(NSUInteger) p {
   NSInteger delta = (NSInteger)self.position - (NSInteger)p;
   if (delta > 0) {
      [self.device moveIn: delta];
   } else {
      [self.device moveOut:-1 * delta];
   }
}

-(void) moveIn:(NSUInteger) delta {
   [self.device moveIn: delta];
}

-(void) moveOut:(NSUInteger) delta {
   [self.device moveOut: delta];
}

@end
