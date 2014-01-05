#import "App.h"

int main(int argc, const char* argv[])
{
    if (setuid(0) != 0) {
        NSLog(@"run it as root");
        exit(1);
    }

    @autoreleasepool {
        App* app = [App new];
        [app watch];
        [[NSRunLoop currentRunLoop] run];
    }

    return 0;
}
