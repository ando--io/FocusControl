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

#import "USBFocusViewController.h"
#import "USBFocusDeviceViewModel.h"

#import <ReactiveCocoa/ReactiveCocoa.h>
#import <ORSSerial/ORSSerialPort.h>
#import <ORSSerial/ORSSerialPortManager.h>
#import "USBFocusDeviceViewModelImpl.h"

#import "USBFocusDeviceManager.h"

@interface USBFocusViewController ()

@property (nonatomic, readonly) ORSSerialPortManager * serialPortManager;

@property (assign, readwrite) NSString * selelectedPortPath;
@property (weak) IBOutlet NSArrayController * cont;
@property (assign) NSInteger wantedPosition;
@property (assign) NSUInteger stepWidthIndex;
@property (weak) IBOutlet NSTextField *positionTextField;
@property (weak) IBOutlet NSTextField *maxPositionTextField;
@property (weak) IBOutlet NSTextField *temperatureTextField;
@property (weak) IBOutlet NSTextField *deltaTempTextField;
@property (weak) IBOutlet NSTextField *thresholdTextField;
@property (weak) IBOutlet NSTextField *wantedPositionTextField;
@property (weak) IBOutlet NSButton *revertCheckBox;
@property (weak) IBOutlet NSButton *halfStepCheckBox;
@property (weak) IBOutlet NSTextField *firmwareTextField;

@property (weak) IBOutlet NSPopUpButton *stepPopup;
@property (weak) IBOutlet NSPopUpButton *speedPopup;

@property (weak) IBOutlet NSButton *moveToButton;
@property (weak) IBOutlet NSButton *moveInButton;
@property (weak) IBOutlet NSButton *moveOutButton;
@property (assign) NSUInteger speedIndex;
@property (nonatomic, strong) RACSubject * cancelObserver;

@property (nonatomic, readwrite, strong) NSObject<USBFocusDeviceViewModel>* viewModel;

@end

@implementation USBFocusViewController {
   RACSubject * connected_;
}
@synthesize viewModel = viewModel_;
@dynamic serialPortManager;

- (void)dealloc {
   [self.cancelObserver sendCompleted];
}

- (void)viewDidLoad {
   [super viewDidLoad];
   
   self.cancelObserver = [[RACSubject alloc]init];
   
   @weakify(self);
   
   [[[RACSignal combineLatest:@[[NSNotificationCenter.defaultCenter rac_addObserverForName:ORSSerialPortsWereConnectedNotification object:nil],
                                [NSNotificationCenter.defaultCenter rac_addObserverForName:ORSSerialPortsWereDisconnectedNotification object:nil]]
     ] takeUntil:self.cancelObserver] subscribeNext:^(id foo) {
      @strongify(self);
      [self.cont willChangeValueForKey:@"arrangedObjects"];
      [self.cont didChangeValueForKey:@"arrangedObjects"];
   }];
   
   connected_ = [RACSubject new];
   
   RAC(self.positionTextField, enabled) = connected_;
   RAC(self.maxPositionTextField, enabled) = connected_;
   RAC(self.thresholdTextField, enabled) = connected_;
   RAC(self.deltaTempTextField, enabled) = connected_;
   RAC(self.halfStepCheckBox, enabled) = connected_;
   RAC(self.revertCheckBox, enabled) = connected_;
   RAC(self.stepPopup, enabled) = connected_;
   RAC(self.speedPopup, enabled) = connected_;
   RAC(self.wantedPositionTextField, enabled) = connected_;
   
   RACSignal * wantedPositionOK = [[self.wantedPositionTextField rac_textSignal] map:^id(NSString * text) {
      @strongify(self);
      NSNumber * n = [[[NSNumberFormatter alloc] init] numberFromString: text];
      if (n != nil) {
         NSInteger pos = [n integerValue];
         if (pos>=0 && pos <= 65535) {
            self.wantedPosition = pos;
            return @(YES);
         }
      }
      return @(NO);
   }];
   
   self.moveToButton.rac_command = [[RACCommand alloc] initWithEnabled:
                                    [RACSignal combineLatest:@[connected_, wantedPositionOK]
                                                      reduce:^(NSNumber * connected, NSNumber * wantedPositionOK){
                                                         return @([connected boolValue] && [wantedPositionOK boolValue]);
                                                      }]
                                                           signalBlock:^RACSignal *(id input) {
                                                              @strongify(self);
                                                              [self.viewModel moveToPosition:self.wantedPosition];
                                                              return [RACSignal empty];
                                                           }];
   
   self.moveInButton.rac_command = [[RACCommand alloc] initWithEnabled:connected_
                                                           signalBlock:^RACSignal *(id input) {
                                                              @strongify(self);
                                                              [self.viewModel moveIn:pow(10, self.stepWidthIndex+1)];
                                                              return [RACSignal empty];
                                                           }];
   
   self.moveOutButton.rac_command = [[RACCommand alloc] initWithEnabled:connected_
                                                            signalBlock:^RACSignal *(id input) {
                                                               @strongify(self);
                                                               [self.viewModel moveOut:pow(10, self.stepWidthIndex+1)];
                                                               return [RACSignal empty];
                                                            }];
   
   [RACObserve(self, selelectedPortPath) subscribeNext:^(NSString * selectedPath) {
      NSLog(@"Selected a new path %@", selectedPath);
      @strongify(self)
      if (selectedPath) {
         
            id<USBFocusDevice> device = [[USBFocusDeviceManager sharedUSBFocusDeviceManager] deviceAtPath:selectedPath];
         
            self.viewModel = [[USBFocusDeviceViewModel alloc] initWithDevice: device];
      } else
         self.viewModel = nil;
   }];
   
   [RACObserve(self, viewModel) subscribeNext:^(id<USBFocusDeviceViewModel> vm) {
      if (vm) {
         [RACObserve(vm, connected) subscribeNext:^(id x) {
            [connected_ sendNext: x];
         }];

         [RACObserve(vm, position) subscribeNext:^(NSNumber * value) {
            @strongify(self);
            NSUInteger pos = [value unsignedIntegerValue];
            self.positionTextField.stringValue = [NSString stringWithFormat:@"%lu", (unsigned long)pos];
         }];
         
         [RACObserve(vm, firmware) subscribeNext:^(NSNumber * value) {
            @strongify(self);
            NSUInteger fw = [value unsignedIntegerValue];
            if (fw)
               self.firmwareTextField.stringValue = [NSString stringWithFormat:@"Firmware revision %lu", (unsigned long)fw];
            else
               self.firmwareTextField.stringValue = [NSString stringWithFormat:@""];
         }];
         
         [RACObserve(vm, temperature) subscribeNext:^(NSNumber * value) {
            @strongify(self);
            float pos = [value floatValue];
            self.temperatureTextField.stringValue = [NSString stringWithFormat:@"%.1f °C", pos];
         }];
         
         {
            RACChannelTerminal *lt = [self.maxPositionTextField rac_channelToBinding:@"value"];
            RACChannelTerminal *ft = RACChannelTo(vm, maxPosition);
            [lt subscribe: ft];
            [ft subscribe: lt];
         }
         {
            RACChannelTerminal *lt = [self.thresholdTextField rac_channelToBinding:@"value"];
            RACChannelTerminal *ft = RACChannelTo(vm, temperatureThreshold);
            [lt subscribe: ft];
            [ft subscribe: lt];
         }
         {
            RACChannelTerminal *lt = [self.deltaTempTextField rac_channelToBinding:@"value"];
            RACChannelTerminal *ft = RACChannelTo(vm, temperatureStep);
            [lt subscribe: ft];
            [ft subscribe: lt];
         }
         {
            RACChannelTerminal *lt = [self.halfStepCheckBox rac_channelToBinding:@"value"];
            RACChannelTerminal *ft = RACChannelTo(vm, stepmode);
            [lt subscribe: ft];
            [ft subscribe: lt];
         }
         {
            RACChannelTerminal *lt = [self.revertCheckBox rac_channelToBinding:@"value"];
            RACChannelTerminal *ft = RACChannelTo(vm, clockwize);
            [lt subscribe: ft];
            [ft subscribe: lt];
         }
         {
            RACChannelTerminal *lt = RACChannelTo(self, speedIndex);
            RACChannelTerminal *ft = RACChannelTo(vm, speed);
            [[lt map:^id(id value) { return @(([value intValue]+1)*2);}] subscribe: ft];
            [[ft map:^id(id value) { return @(([value intValue]/2)-1);}] subscribe: lt];
         }
      } else {
         [connected_ sendNext: @(NO)];
      }
   }];
}
-(ORSSerialPortManager *)serialPortManager {
   return [ORSSerialPortManager sharedSerialPortManager];
}

@end
