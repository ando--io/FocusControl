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

@protocol ParameterHistory;

@protocol USBFocusDeviceViewModel <NSObject>

@property (nonatomic, readonly, assign) BOOL connected;
@property (nonatomic, readonly, assign) NSUInteger position;
@property (nonatomic, readonly, assign) float temperature;
@property (nonatomic, readonly, assign) BOOL stepmode;
@property (nonatomic, readonly, assign) BOOL clockwize;
@property (nonatomic, readonly, assign) float temperatureStep;
@property (nonatomic, readonly, assign) float temperatureThreshold;
@property (nonatomic, readonly, assign) NSUInteger maxPosition;
@property (nonatomic, readonly, assign) NSUInteger firmware;
@property (nonatomic, readonly, assign) NSUInteger speed;

@property (nonatomic, readonly, strong) NSObject<ParameterHistory>* positionHistory;
@property (nonatomic, readonly, strong) NSObject<ParameterHistory>* temperatureHistory;

-(void) moveToPosition:(NSUInteger) position;
-(void) moveIn:(NSUInteger) delta;
-(void) moveOut:(NSUInteger) delta;

@end
