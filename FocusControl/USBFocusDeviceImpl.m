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

#import "USBFocusDeviceImpl.h"
#import <ReactiveCocoa/ReactiveCocoa.h>
#import <ORSSerial/ORSSerialPort.h>
#import <ORSSerial/ORSSerialRequest.h>
#import <ORSSerial/ORSSerialPacketDescriptor.h>
#import "USBUtil.h"

#define GET_POSITION_CMD @"FPOSRO"
#define GET_TEMPERATURE_CMD @"FTMPRO"
#define GET_SETTINGS_CMD @"SGETAL"
#define GET_SIGN_CMD @"FTxxxA"

#define SET_STEPMODE_H_CMD @"SMSTPD"
#define SET_STEPMODE_F_CMD @"SMSTPF"

#define SET_ROTATION_CW_CMD @"SMROTH"
#define SET_ROTATION_ACW_CMD @"SMROTT"

#define SET_SPEED_CMD @"SMO00"
#define SET_MAXPOS_CMD @"M"

#define MOVE_IN_CMD @"I"
#define MOVE_OUT_CMD @"O"

#define SET_TMPCOEF_CMD @"FLX"
#define SET_TMPCOEFSIGN_CMD @"FZSIG"
#define SET_TMPCOEFTHR_CMD @"SMA"

#define STOP_CMD @"FQUITx"

#define DEFAULT_TIMEOUT 1.f

typedef void (^act_t)(NSString * response, BOOL timeout);

@interface USBFocusDevice() <ORSSerialPortDelegate>
@property (nonatomic, readonly) ORSSerialPort * port;
@property (nonatomic, readwrite) BOOL connected;
@property (nonatomic, readwrite) NSUInteger position;
@property (nonatomic, readwrite) NSInteger firmwareVersion;
@property (nonatomic, readwrite) float temperature;

@end

@implementation USBFocusDevice {
   dispatch_queue_t backgroundQueue_;
   dispatch_source_t timer_;
}
@synthesize connected;
@synthesize position;
@synthesize temperature;
@synthesize maxPosition = maxPosition_;
@synthesize motorSpeed = motorSpeed_;
@synthesize motorRotation = motorRotation_;
@synthesize motorStepmode = motorStepmode_;
@synthesize firmwareVersion;
@synthesize temperatureCompensationMini = tempCompMini_;
@synthesize temperatureCoefficient = tempCoeff_;

@synthesize port = port_;

-(instancetype)initWithPort:(ORSSerialPort *)port queue:(dispatch_queue_t) background {
   self = [super init];
   if (self) {
      port_ = port;
      backgroundQueue_ = background;
      
      @weakify(self);
      
      timer_= dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, backgroundQueue_);
      dispatch_source_set_timer(timer_, dispatch_time(DISPATCH_TIME_NOW, 100 * NSEC_PER_MSEC), 100 * NSEC_PER_MSEC, 50 * NSEC_PER_MSEC);
      
      dispatch_source_set_event_handler(timer_, ^{
         @strongify(self);
         if (self.isConnected) {
            [self readPosition:nil];
            [self readTemperature:nil];
         }
      });
      dispatch_resume(timer_);
      
   }
   return self;
}

-(void)connect {
   self.port.baudRate = @(9600);
   self.port.parity = ORSSerialPortParityNone;
   self.port.numberOfStopBits = 1;
   
   self.port.delegate = self;
   
   [self.port open];
}

-(void)disconnect {
   
   dispatch_source_cancel(timer_);
   
   if (self.port.isOpen) {
      [self.port close];
   }
   resetUSBDeviceWithBSDPath((__bridge CFStringRef)(self.port.path));
}

-(void)doHandshake {
   [self readPosition:nil];
   [self readTemperature:nil];
   [self readSettings:^{
      self.connected = YES;
   }];
}

-(void)readPosition:(dispatch_block_t) completion {
   @weakify(self);
   NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:@"[P][=]([0-9]{5})[\n][\r]" options:0 error:nil];
   ORSSerialPacketDescriptor * descriptor = [[ORSSerialPacketDescriptor alloc] initWithMaximumPacketLength:9 userInfo:nil responseEvaluator:^BOOL(NSData * _Nullable inputData) {
      @strongify(self);
      NSString * response = [[NSString alloc] initWithData:inputData encoding:NSASCIIStringEncoding];
      NSTextCheckingResult * match =[regex firstMatchInString:response options:0 range:NSMakeRange(0, response.length)];
      if (match && [match numberOfRanges]>0) {
         self.position = [[response substringWithRange:[match rangeAtIndex:1]] integerValue];
         if (completion) completion();
         return YES;
      }
      return NO;
   }];
   ORSSerialRequest * request = [[ORSSerialRequest alloc]initWithDataToSend:[GET_POSITION_CMD dataUsingEncoding:NSASCIIStringEncoding]
                                                                   userInfo:nil
                                                            timeoutInterval:DEFAULT_TIMEOUT
                                                         responseDescriptor:descriptor];
   
   [self.port sendRequest: request];
}

-(void)readTemperature:(dispatch_block_t) completion {
   @weakify(self);
   NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:@"[T][=]([+-][0-9]{2}[.][0-9]{2})[\n][\r]" options:0 error:nil];
   ORSSerialPacketDescriptor * descriptor = [[ORSSerialPacketDescriptor alloc] initWithMaximumPacketLength:10 userInfo:nil responseEvaluator:^BOOL(NSData * _Nullable inputData) {
      @strongify(self);
      NSString * response = [[NSString alloc] initWithData:inputData encoding:NSASCIIStringEncoding];
      NSTextCheckingResult * match =[regex firstMatchInString:response options:0 range:NSMakeRange(0, response.length)];
      if (match && [match numberOfRanges]>0) {
         self.temperature = [[response substringWithRange:[match rangeAtIndex:1]] floatValue];
         if (completion) completion();
         return YES;
      }
      return NO;
   }];
   ORSSerialRequest * request = [[ORSSerialRequest alloc]initWithDataToSend:[GET_TEMPERATURE_CMD dataUsingEncoding:NSASCIIStringEncoding]
                                                                   userInfo:nil
                                                            timeoutInterval:DEFAULT_TIMEOUT
                                                         responseDescriptor:descriptor];
   
   [self.port sendRequest: request];
}

-(void)readCoeffSign:(dispatch_block_t) completion {
   @weakify(self);
   NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:@"[A][=]([0-9])" options:0 error:nil];
   ORSSerialPacketDescriptor * descriptor = [[ORSSerialPacketDescriptor alloc] initWithMaximumPacketLength:9 userInfo:nil responseEvaluator:^BOOL(NSData * _Nullable inputData) {
      @strongify(self);
      NSString * response = [[NSString alloc] initWithData:inputData encoding:NSASCIIStringEncoding];
      NSTextCheckingResult * match =[regex firstMatchInString:response options:0 range:NSMakeRange(0, response.length)];
      if (match && [match numberOfRanges]>0) {
         NSInteger val = [[response substringWithRange:[match rangeAtIndex:1]] integerValue];
         [self willChangeValueForKey:@"temperatureCoefficient"];
         tempCoeff_ *= val==1 ? -1 : 1;
         [self didChangeValueForKey:@"temperatureCoefficient"];
         if (completion) completion();
         return YES;
      }
      return NO;
   }];
   
   ORSSerialRequest * request = [[ORSSerialRequest alloc]initWithDataToSend:[GET_SIGN_CMD dataUsingEncoding:NSASCIIStringEncoding]
                                                                   userInfo:nil
                                                            timeoutInterval:DEFAULT_TIMEOUT
                                                         responseDescriptor:descriptor];
   [self.port sendRequest: request];
}

-(void)readSettings:(dispatch_block_t) completion {
   @weakify(self);
   NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:@"[C][=]([0-9])[-]([0-9])[-]([0-9])[-]([0-9]{3})[-]([0-9]{3})[-]([0-9]{4})[-]([0-9]{5})[\n][\r]" options:0 error:nil];
   ORSSerialPacketDescriptor * descriptor = [[ORSSerialPacketDescriptor alloc] initWithMaximumPacketLength:28 userInfo:nil responseEvaluator:^BOOL(NSData * _Nullable inputData) {
      @strongify(self);
      NSString * response = [[NSString alloc] initWithData:inputData encoding:NSASCIIStringEncoding];
      NSArray<NSTextCheckingResult *> * match =[regex matchesInString:response options:0 range:NSMakeRange(0, response.length)];
      if (match && [match count]==1) {
         NSTextCheckingResult * result = match[0];
         if ([result numberOfRanges] == 8) {
            // Rotation
            // anticlockwise=1
            NSInteger val = [[response substringWithRange:[result rangeAtIndex:1]] integerValue];
            [self willChangeValueForKey:@"motorRotation"];
            motorRotation_ = (val == 1) ? anticlockwiseRotation : clockwiseRotation;
            [self didChangeValueForKey:@"motorRotation"];
            
            // stepmode
            // halfstep=1
            val = [[response substringWithRange:[result rangeAtIndex:2]] integerValue];
            [self willChangeValueForKey:@"motorStepmode"];
            motorStepmode_ = (val == 1) ? halfStepMode : fullStepMode;
            [self didChangeValueForKey:@"motorStepmode"];
            // speed
            val = [[response substringWithRange:[result rangeAtIndex:3]] integerValue];
            [self willChangeValueForKey:@"motorSpeed"];
            motorSpeed_ = val;
            [self didChangeValueForKey:@"motorSpeed"];
            // temp coeff
            val = [[response substringWithRange:[result rangeAtIndex:4]] integerValue];
            tempCoeff_ = val;  // take care not to trigger kvo as the complete coef is retrieved in two steps, see readcoeffsign 
            
            // temp coeff mini
            val = [[response substringWithRange:[result rangeAtIndex:5]] integerValue];
            [self willChangeValueForKey:@"temperatureCompensationMini"];
            tempCompMini_ = val;
            [self didChangeValueForKey:@"temperatureCompensationMini"];
            // firmware version
            val = [[response substringWithRange:[result rangeAtIndex:6]] integerValue];
            self.firmwareVersion = val;
            // firmware version
            val = [[response substringWithRange:[result rangeAtIndex:7]] integerValue];
            [self willChangeValueForKey:@"maxPosition"];
            maxPosition_ = val;
            [self didChangeValueForKey:@"maxPosition"];
            // avoid queueing request in the block
            [self performSelectorOnMainThread:@selector(readCoeffSign:)  withObject:completion waitUntilDone:NO];
            return YES;
         }
      }
      return NO;
   }];
   
   ORSSerialRequest * request = [[ORSSerialRequest alloc]initWithDataToSend:[GET_SETTINGS_CMD dataUsingEncoding:NSASCIIStringEncoding]
                                                                   userInfo:nil
                                                            timeoutInterval:DEFAULT_TIMEOUT
                                                         responseDescriptor:descriptor];
   
   [self.port sendRequest: request];
}

-(void)setMotorStepmode:(step_t)motorStepmode {
   if (!self.connected) return;
   NSString * cmd = motorStepmode == halfStepMode ? SET_STEPMODE_H_CMD : SET_STEPMODE_F_CMD;
   ORSSerialRequest * request = [[ORSSerialRequest alloc]initWithDataToSend:[cmd dataUsingEncoding:NSASCIIStringEncoding]
                                                                   userInfo:nil
                                                            timeoutInterval:DEFAULT_TIMEOUT
                                                         responseDescriptor:nil];
   
   [self.port sendRequest: request];
   [self readSettings:nil];
}

-(void)setMotorRotation:(rotation_t)motorRotation {
   if (!self.connected) return;
   NSString * cmd = motorRotation == clockwiseRotation ? SET_ROTATION_CW_CMD : SET_ROTATION_ACW_CMD;
   ORSSerialRequest * request = [[ORSSerialRequest alloc]initWithDataToSend:[cmd dataUsingEncoding:NSASCIIStringEncoding]
                                                                   userInfo:nil
                                                            timeoutInterval:DEFAULT_TIMEOUT
                                                         responseDescriptor:nil];
   
   [self.port sendRequest: request];
   [self readSettings:nil];
}

-(void)setMotorSpeed:(speed_t)motorSpeed {
   if (!self.connected) return;
   NSString * cmd = [NSString stringWithFormat:@"%@%u", SET_SPEED_CMD, (unsigned)motorSpeed];
   NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:@"[D][O][N][E][\n][\r]" options:0 error:nil];
   ORSSerialPacketDescriptor * descriptor = [[ORSSerialPacketDescriptor alloc] initWithRegularExpression:regex maximumPacketLength:6 userInfo:nil];
   ORSSerialRequest * request = [[ORSSerialRequest alloc]initWithDataToSend:[cmd dataUsingEncoding:NSASCIIStringEncoding]
                                                                   userInfo:nil
                                                            timeoutInterval:DEFAULT_TIMEOUT
                                                         responseDescriptor:descriptor];
   
   [self.port sendRequest: request];
   [self readSettings:nil];
}

-(void)setMaxPosition:(NSUInteger)maxPosition {
   if (!self.connected) return;
   NSString * cmd = [NSString stringWithFormat:@"%@%05u", SET_MAXPOS_CMD, (unsigned)maxPosition];
   NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:@"[D][O][N][E][\n][\r]" options:0 error:nil];
   ORSSerialPacketDescriptor * descriptor = [[ORSSerialPacketDescriptor alloc] initWithRegularExpression:regex maximumPacketLength:6 userInfo:nil];
   ORSSerialRequest * request = [[ORSSerialRequest alloc]initWithDataToSend:[cmd dataUsingEncoding:NSASCIIStringEncoding]
                                                                   userInfo:nil
                                                            timeoutInterval:DEFAULT_TIMEOUT
                                                         responseDescriptor:descriptor];
   
   [self.port sendRequest: request];
   [self readSettings:nil];
}


-(void)setTemperatureCoefficient:(float)temperatureCoefficient {
   if (!self.connected) return;
   
   NSString * cmd = [NSString stringWithFormat:@"%@%03u", SET_TMPCOEF_CMD, (unsigned)fabs(temperatureCoefficient)];
   NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:@"[D][O][N][E][\n][\r]" options:0 error:nil];
   ORSSerialPacketDescriptor * descriptor = [[ORSSerialPacketDescriptor alloc] initWithRegularExpression:regex maximumPacketLength:6 userInfo:nil];
   ORSSerialRequest * request = [[ORSSerialRequest alloc]initWithDataToSend:[cmd dataUsingEncoding:NSASCIIStringEncoding]
                                                                   userInfo:nil
                                                            timeoutInterval:DEFAULT_TIMEOUT
                                                         responseDescriptor:descriptor];
   
   [self.port sendRequest: request];
   
   cmd = [NSString stringWithFormat:@"%@%@", SET_TMPCOEFSIGN_CMD, temperatureCoefficient < 0 ? @"1" : @"0"];
   regex = [NSRegularExpression regularExpressionWithPattern:@"[D][O][N][E][\n][\r]" options:0 error:nil];
   descriptor = [[ORSSerialPacketDescriptor alloc] initWithRegularExpression:regex maximumPacketLength:6 userInfo:nil];
   request = [[ORSSerialRequest alloc]initWithDataToSend:[cmd dataUsingEncoding:NSASCIIStringEncoding]
                                                userInfo:nil
                                         timeoutInterval:DEFAULT_TIMEOUT
                                      responseDescriptor:descriptor];
   
   [self.port sendRequest: request];
   
   [self readSettings:nil];
}

-(void)setTemperatureCompensationMini:(float)temperatureCompensationMini {
   if (!self.connected) return;
   NSString * cmd = [NSString stringWithFormat:@"%@%03u", SET_TMPCOEFTHR_CMD, (unsigned)temperatureCompensationMini];
   NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:@"[D][O][N][E][\n][\r]" options:0 error:nil];
   ORSSerialPacketDescriptor * descriptor = [[ORSSerialPacketDescriptor alloc] initWithRegularExpression:regex maximumPacketLength:6 userInfo:nil];
   ORSSerialRequest * request = [[ORSSerialRequest alloc]initWithDataToSend:[cmd dataUsingEncoding:NSASCIIStringEncoding]
                                                                   userInfo:nil
                                                            timeoutInterval:DEFAULT_TIMEOUT
                                                         responseDescriptor:descriptor];
   
   [self.port sendRequest: request];
   [self readSettings:nil];
}

-(void)reset {
   
}

-(void)stop {
   if (!self.connected) return;
   [self.port cancelAllQueuedRequests];
   ORSSerialRequest * request = [[ORSSerialRequest alloc]initWithDataToSend:[STOP_CMD dataUsingEncoding:NSASCIIStringEncoding]
                                                                   userInfo:nil
                                                            timeoutInterval:DEFAULT_TIMEOUT
                                                         responseDescriptor:nil];
   [self.port sendRequest: request];
}

-(void)moveIn:(NSUInteger) step {
   if (!self.connected) return;
   NSString * cmd = [NSString stringWithFormat:@"%@%05u", MOVE_IN_CMD, (unsigned)step];
   ORSSerialRequest * request = [[ORSSerialRequest alloc]initWithDataToSend:[cmd dataUsingEncoding:NSASCIIStringEncoding]
                                                                   userInfo:nil
                                                            timeoutInterval:DEFAULT_TIMEOUT
                                                         responseDescriptor:nil];
   [self.port sendRequest: request];
}

-(void)moveOut:(NSUInteger) step {
   if (!self.connected) return;
   NSString * cmd = [NSString stringWithFormat:@"%@%05u", MOVE_OUT_CMD, (unsigned)step];
   ORSSerialRequest * request = [[ORSSerialRequest alloc]initWithDataToSend:[cmd dataUsingEncoding:NSASCIIStringEncoding]
                                                                   userInfo:nil
                                                            timeoutInterval:DEFAULT_TIMEOUT
                                                         responseDescriptor:nil];
   [self.port sendRequest: request];
}

#pragma - ORSSerial Delegate
- (void)serialPortWasRemovedFromSystem:(ORSSerialPort *)serialPort {
   NSLog(@"serialPortWasRemovedFromSystem");
}

- (void)serialPort:(ORSSerialPort *)serialPort requestDidTimeout:(ORSSerialRequest *)request {
   NSLog(@"requestDidTimeout %@", [[NSString alloc] initWithData:request.dataToSend encoding:NSASCIIStringEncoding]);
}

- (void)serialPort:(ORSSerialPort *)serialPort didEncounterError:(NSError *)error {
   NSLog(@"Error serial %@", error);
}

- (void)serialPortWasOpened:(ORSSerialPort *)serialPort {
   NSLog(@"serialPortWasOpened");
   [self doHandshake];
}

- (void)serialPortWasClosed:(ORSSerialPort *)serialPort {
   NSLog(@"disconnected");
   self.connected = NO;
}

@end
