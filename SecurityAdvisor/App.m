#import "App.h"

@implementation App

typedef struct kinfo_proc kinfo_proc;

static OSStatus KeychainLockedCallback(SecKeychainEvent event, SecKeychainCallbackInfo* info, void* context)
{
    NSArray* filter = [[NSArray alloc] initWithObjects:@"ssh-agent", nil];
    KillProcessByFilter(filter);

    return 0;
}

static NSArray* GetProcessList(NSArray* filters)
{
    static const int name[] = { CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0 };
    size_t length;
    int err;
    u_long procCount;
    kinfo_proc* procList;
    NSArray* result;
    
    err = sysctl((int*)name, (sizeof(name) / sizeof(*name)) - 1, NULL, &length, NULL, 0);
    if ( (err == 0) && ((procList = malloc(length)) != NULL) ) {
        err = sysctl((int*)name, (sizeof(name) / sizeof(*name)) - 1, procList, &length, NULL, 0);
        if (err == 0) {
            procCount = length / sizeof(kinfo_proc);
            NSMutableArray* processes = [[NSMutableArray alloc] initWithCapacity:procCount];
            for (int i = 0; i < procCount; i++) {
                struct kinfo_proc* proc = &procList[i];
                NSNumber* processID = [NSNumber numberWithInt:proc->kp_proc.p_pid];
                NSString* processName = [[NSString alloc] initWithFormat: @"%s", proc->kp_proc.p_comm];
                if (processID && processName) {
                    for (NSString* filter in filters) {
                        if ([processName isEqualToString:filter]) {
                            [processes addObject:processID];
                            break;
                        }
                    }
                }
            }
            result = [processes copy];
        }
    }
    
    if (procList != NULL)
        free(procList);
    
    return result;
}

static void KillProcessByFilter(NSArray* filter)
{
    NSArray* ps = GetProcessList(filter);
    if (ps) {
        for (NSNumber* pid in ps) {
            if (kill((pid_t)[pid intValue], SIGTERM) != 0)
                NSLog(@"can't send SIGTERM to pid: %@", pid);
        }
    }
}

- (void) watch
{
    NSNotificationCenter* nc = [[NSWorkspace sharedWorkspace] notificationCenter];
    [nc addObserver: self
           selector: @selector(receiveSleepNote:)
               name: NSWorkspaceWillSleepNotification object: nil];
    [nc addObserver: self
           selector: @selector(receiveSleepNote:)
               name: NSWorkspaceDidWakeNotification object: nil];
    [nc addObserver: self
           selector: @selector(receiveSleepNote:)
               name: NSWorkspaceScreensDidSleepNotification object: nil];
    [nc addObserver: self
           selector: @selector(receiveSleepNote:)
               name: NSWorkspaceScreensDidWakeNotification object: nil];

    SecKeychainAddCallback(&KeychainLockedCallback, kSecLockEventMask, nil);
}


- (void) receiveSleepNote: (NSNotification*)note
{
    NSArray* filter = [[NSArray alloc] initWithObjects:@"ssh", @"ssh-agent", nil];
    KillProcessByFilter(filter);
}

@end
