/*
 USBTelescopeController
 
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

#include <stdio.h>
#include "USBUtil.h"

#include <IOKit/serial/IOSerialKeys.h>
#include <IOKit/serial/ioss.h>
#include <sys/param.h>
#include <sys/filio.h>
#include <sys/ioctl.h>
#include <mach/mach_port.h>
#include <IOKit/IOBSD.h>
#include <IOKit/usb/IOUSBLib.h>
#include <IOKit/IODataQueueShared.h>
#include <IOKit/IODataQueueClient.h>
#include <IOKit/IOCFPlugIn.h>

io_object_t lookForDeviceWithBSDPath(CFStringRef path) {
   io_iterator_t portIterator = 0;
   CFMutableDictionaryRef matchingDict = NULL;
   kern_return_t err;
   io_object_t port = 0;
   
   matchingDict = IOServiceMatching(kIOSerialBSDServiceValue);
   CFDictionaryAddValue(matchingDict, CFSTR(kIOSerialBSDTypeKey), CFSTR(kIOSerialBSDAllTypes));
   err = IOServiceGetMatchingServices(kIOMasterPortDefault, matchingDict, &portIterator);
   if (err) return 0;
   
   int found = 0;
   while (!found && (port = IOIteratorNext(portIterator))) {
      CFStringRef iocallout  = (CFStringRef)IORegistryEntryCreateCFProperty(port,CFSTR(kIOCalloutDeviceKey),kCFAllocatorDefault,0);
      CFStringRef iodialin  = (CFStringRef)IORegistryEntryCreateCFProperty(port,CFSTR(kIODialinDeviceKey),kCFAllocatorDefault,0);
      
      found = ( CFStringCompare(path, iocallout, 0)== kCFCompareEqualTo) ||  ( CFStringCompare(path, iodialin, 0)== kCFCompareEqualTo);
      
      CFRelease(iocallout);
      CFRelease(iodialin);
      
      if (!found) IOObjectRelease(port);
   }
   IOObjectRelease(portIterator);
   return port;
}

IOUSBDeviceInterface187 ** usbDeviceAtLocation(UInt32 lid) {
   mach_port_t masterPort;
   CFMutableDictionaryRef matchingDict;
   kern_return_t kr;
   
   //Create a master port for communication with the I/O Kit
   
   kr = IOMasterPort (MACH_PORT_NULL, &masterPort);
   if (kr || !masterPort) {
      return NULL;
   }
   
   //Set up matching dictionary for class IOUSBDevice and its subclasses
   matchingDict = IOServiceMatching (kIOUSBDeviceClassName);
   if (!matchingDict)
   {
      mach_port_deallocate(mach_task_self(), masterPort);
      return NULL;
   }
   
   io_iterator_t iterator;
   IOServiceGetMatchingServices (kIOMasterPortDefault, matchingDict, &iterator);
   io_service_t usbDevice;
   
   int found = 0;
   IOUSBDeviceInterface187 **dev = NULL;
   while (!found && (usbDevice = IOIteratorNext (iterator))) {
      
      IOCFPlugInInterface**plugInInterface = NULL;
      SInt32 theScore;
      
      kr = IOCreatePlugInInterfaceForService(usbDevice, kIOUSBDeviceUserClientTypeID, kIOCFPlugInInterfaceID, &plugInInterface, &theScore);
      
      (*plugInInterface)->QueryInterface(plugInInterface, CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID), (LPVOID *)&dev);
      
      UInt32 locationId;
      (*dev)->GetLocationID(dev, &locationId);
      found = locationId == lid;
      
      IOObjectRelease(usbDevice);
      (*plugInInterface)->Release(plugInInterface);
      if (!found)
         (*dev)->Release(dev);
   }

   mach_port_deallocate(mach_task_self(), masterPort);
   
   masterPort = 0;
   return dev;
}

void resetUSBDeviceWithBSDPath(CFStringRef path) {
   CFTypeRef cf_property;
   io_object_t ioport = lookForDeviceWithBSDPath(path), ioparent;
   
   if (ioport) {
      IORegistryEntryGetParentEntry(ioport, kIOServicePlane, &ioparent);
      IOObjectRelease(ioport);
      
      cf_property = IORegistryEntrySearchCFProperty(ioparent,kIOServicePlane,
                                                    CFSTR("locationID"), kCFAllocatorDefault,
                                                    kIORegistryIterateRecursively | kIORegistryIterateParents);
      
      if (cf_property) {
         UInt32 locID = 0;
         CFNumberGetValue((CFNumberRef)cf_property, kCFNumberSInt32Type, &locID);
         CFRelease(cf_property);
         
         IOUSBDeviceInterface187 ** dev = usbDeviceAtLocation(locID);
         if (dev && *dev) {
            (*dev)->USBDeviceOpen(dev);
            (*dev)->ResetDevice(dev);
            (*dev)->USBDeviceReEnumerate(dev, 0);
            (*dev)->USBDeviceClose(dev);
         }
         (*dev)->Release(dev);
      }
   }
}
