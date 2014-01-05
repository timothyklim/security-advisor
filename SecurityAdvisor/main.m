#include <ctype.h>
#include <stdlib.h>
#include <stdio.h>

#include <mach/mach_port.h>
#include <mach/mach_interface.h>
#include <mach/mach_init.h>

#include <sys/sysctl.h>

#include <IOKit/pwr_mgt/IOPMLib.h>
#include <IOKit/IOMessage.h>
#include <Foundation/Foundation.h>

typedef struct kinfo_proc kinfo_proc;

void CallBack(void* refCon, io_service_t service, natural_t messageType, void* messageArgument)
{
    NSLog(@"messageType %08lx, arg %08lx\n",
          (long unsigned int)messageType,
          (long unsigned int)messageArgument);
    
    switch ( messageType )
    {
        case kIOMessageSystemWillSleep:
            break;
            
        case kIOMessageSystemWillPowerOn:
            break;
            
        case kIOMessageSystemHasPoweredOn:
            break;
            
            //        default:
            //            break;
            
    }
}

void RegisterPowerEvents()
{
    IONotificationPortRef  notificationPort;
    io_object_t            notification;
    io_connect_t powerPort;

    powerPort = IORegisterForSystemPower(NULL, &notificationPort, CallBack, &notification);
    if (powerPort == 0) {
        NSLog(@"IORegisterForSystemPower failed\n");
        exit(1);
    }
    CFRunLoopAddSource(CFRunLoopGetCurrent(), IONotificationPortGetRunLoopSource(notificationPort),
                       kCFRunLoopCommonModes);
    IOObjectRelease(powerPort);
    
}

void RegisterDisplayEvents()
{
    IONotificationPortRef notificationPort;
    io_object_t notification;
    io_service_t displayPort;

    displayPort = IOServiceGetMatchingService(kIOMasterPortDefault,
                                              IOServiceNameMatching("IODisplayWrangler"));
    if (displayPort == 0) {
        NSLog(@"IOServiceGetMatchingService failed\n");
        exit(1);
    }
    notificationPort = IONotificationPortCreate(kIOMasterPortDefault);
    IOServiceAddInterestNotification(notificationPort, displayPort, kIOGeneralInterest,
                                     CallBack, NULL, &notification);
    CFRunLoopAddSource (CFRunLoopGetCurrent(), IONotificationPortGetRunLoopSource(notificationPort),
                        kCFRunLoopDefaultMode);
    IOObjectRelease(displayPort);
}

int main(int argc, const char* argv[])
{
    //    if (setuid(0) != 0) {
    //        NSLog(@"run it as root");
    //        exit(1);
    //    }
    
    @autoreleasepool {
        RegisterPowerEvents();
        RegisterDisplayEvents();
        
        CFRunLoopRun();
    }
    
    return 0;
}
