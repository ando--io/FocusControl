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

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, sign_t) {
   negativeSign,
   positiveSign
};

typedef NS_ENUM(NSInteger, step_t) {
   fullStepMode,
   halfStepMode
};

typedef NS_ENUM(NSInteger, rotation_t) {
   clockwiseRotation,
   anticlockwiseRotation
};

typedef NS_ENUM(NSInteger, speed_t) {
   speed_2 = 2,
   speed_3,
   speed_4,
   speed_5,
   speed_6,
   speed_7,
   speed_8,
   speed_9
};

@protocol USBFocusDevice <NSObject>

-(void)connect;
-(void)disconnect;

-(void)readPosition:(dispatch_block_t) completion;
-(void)readTemperature:(dispatch_block_t) completion;
-(void)readSettings:(dispatch_block_t) completion;

@property (nonatomic, readonly, getter=isConnected) BOOL connected;
@property (nonatomic, readonly) float temperature;
@property (nonatomic, readonly) NSUInteger position;
@property (nonatomic, readonly) NSInteger firmwareVersion;

@property (nonatomic, readwrite) NSUInteger maxPosition;
@property (nonatomic, readwrite) speed_t motorSpeed;
@property (nonatomic, readwrite) rotation_t motorRotation;
@property (nonatomic, readwrite) step_t motorStepmode;
@property (nonatomic, readwrite) float temperatureCoefficient;
@property (nonatomic, readwrite) float temperatureCompensationMini;

-(void)moveIn:(NSUInteger) step;
-(void)moveOut:(NSUInteger) step;

-(void) stop;
-(void) reset;

@end
