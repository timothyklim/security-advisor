#include <sys/sysctl.h>

#include <IOKit/pwr_mgt/IOPMLib.h>
#include <IOKit/IOMessage.h>
#include <Foundation/Foundation.h>

typedef struct kinfo_proc kinfo_proc;

OSStatus KeychainLockedCallback(SecKeychainEvent, SecKeychainCallbackInfo*, void*);
NSArray* GetProcessList(NSArray*);
void KillProcessByFilter(NSArray*);
void EventsCallback(void*, io_service_t, natural_t, void*);
void RegisterPowerEvents(void);
void RegisterDisplayEvents(void);


int main(int argc, const char* argv[])
{
    if (setuid(0) != 0) {
        NSLog(@"run it as root");
        exit(1);
    }

    @autoreleasepool {
        RegisterPowerEvents();
        RegisterDisplayEvents();

        SecKeychainAddCallback(&KeychainLockedCallback, kSecLockEventMask, NULL);

        CFRunLoopRun();
    }

    return 0;
}


NSArray* GetProcessList(NSArray* filters)
{
    static const int procCmdParams[] = { CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0 };
    static const int procCmdSize = (sizeof(procCmdParams) / sizeof(*procCmdParams)) - 1;
    static int* procCmd = (int*)procCmdParams;
    size_t length = 0;
    kinfo_proc* procList = NULL;
    NSArray* result = nil;

    if ( (sysctl(procCmd, procCmdSize, NULL, &length, NULL, 0) == 0) &&
        ((procList = malloc(length)) != NULL) &&
        (sysctl(procCmd, procCmdSize, procList, &length, NULL, 0) == 0) )
    {
        u_long procCount = length / sizeof(kinfo_proc);
        NSMutableArray* processes = [[NSMutableArray alloc] initWithCapacity:procCount];
        for (int i = 0; i < procCount; i++) {
            struct kinfo_proc* proc = &procList[i];
            NSNumber* processID = [[NSNumber alloc] initWithInt:proc->kp_proc.p_pid];
            NSString* processName = [[NSString alloc] initWithFormat: @"%s", proc->kp_proc.p_comm];
            if (processID && processName) {
                NSString* filter;
                for (int j = 0; j < [filters count]; j++) {
                    filter = [filters objectAtIndex: j];
                    if ([processName isEqualToString:filter]) {
                        [processes addObject:processID];
                        break;
                    }
                }
            }
        }
        result = [[NSArray alloc] initWithArray:processes];
    }

    if (procList != NULL)
        free(procList);

    return result;
}


void KillProcessByFilter(NSArray* filter)
{
    NSArray* ps = GetProcessList(filter);
    if (ps) {
        for (NSNumber* pid in ps)
            kill((pid_t)[pid intValue], SIGTERM);
    }
}


OSStatus KeychainLockedCallback(SecKeychainEvent event, SecKeychainCallbackInfo* info, void* context)
{
    NSArray* filter = [[NSArray alloc] initWithObjects:@"ssh-agent", nil];
    KillProcessByFilter(filter);

    return 0;
}


void EventsCallback(void* refCon, io_service_t service, natural_t messageType, void* messageArgument)
{
    switch (messageType)
    {
        case kIOMessageSystemWillSleep:
        case kIOMessageSystemWillPowerOn:
        case kIOMessageSystemHasPoweredOn:
        case kIOMessageDeviceWillPowerOff:
        case kIOMessageDeviceHasPoweredOn:
        {
            NSArray* filter = [[NSArray alloc] initWithObjects:@"ssh", @"ssh-agent", nil];
            KillProcessByFilter(filter);

            break;
        }
    }
}


void RegisterPowerEvents()
{
    IONotificationPortRef  notificationPort;
    io_object_t            notification;
    io_connect_t powerPort;

    powerPort = IORegisterForSystemPower(NULL, &notificationPort, EventsCallback, &notification);
    if (powerPort == 0) {
        NSLog(@"IORegisterForSystemPower failed");
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
        NSLog(@"IOServiceGetMatchingService failed");
        exit(1);
    }
    notificationPort = IONotificationPortCreate(kIOMasterPortDefault);
    IOServiceAddInterestNotification(notificationPort, displayPort, kIOGeneralInterest,
                                     EventsCallback, NULL, &notification);
    CFRunLoopAddSource (CFRunLoopGetCurrent(), IONotificationPortGetRunLoopSource(notificationPort),
                        kCFRunLoopDefaultMode);
    IOObjectRelease(displayPort);
}

