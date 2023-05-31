//
//  ViewController.m
//  RunloopDemo
//
//  Created by 曹素洋 on 2023/5/31.
//

#import "ViewController.h"

@interface ViewController () {
    /// dispatch_semaphore，用于线程同步
    dispatch_semaphore_t semaphore;
    /// 观察者runLoopObs
    CFRunLoopObserverRef runLoopObs;
    /// 主线程RunLoop活动状态obsActivity
    CFRunLoopActivity obsActivity;
}
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
//    [self threadLive];
    
//    [self fixTimerStop];
    
//    [self monitorKaton];
    
    [self gcdTimer];
}

/// 控制线程生命周期（线程保活）
- (void)threadLive {
    __weak typeof(self) weakSelf =self;
    NSThread *thread = [[NSThread alloc] initWithBlock:^{
        [weakSelf performSelector:@selector(performSel) withObject:weakSelf afterDelay:2.0];
        [[NSRunLoop currentRunLoop] addPort:[NSPort port] forMode:NSDefaultRunLoopMode];
        [[NSRunLoop currentRunLoop] run];
    }];
    [thread start];
}

- (void)performSel {
    NSLog(@"ViewController performSel");
}

/// 解决NSTimer在滑动时停止工作的问题
- (void)fixTimerStop {
    NSTimer *timer = [NSTimer timerWithTimeInterval:1.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
        NSLog(@"ViewController fixTimerStop block");
    }];
    [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
}

/// 监控应用卡顿
- (void)monitorKaton {
    [self startMonitor];
}

- (void)startMonitor {
    if (runLoopObs) return;
    // 1. 创建一个dispatch_semaphore，用于线程同步
    semaphore = dispatch_semaphore_create(0);
    // 2. 创建一个CFRunLoopObserverContext观察者
    CFRunLoopObserverContext cxt = {0, (__bridge void *)(self), NULL, NULL};
    runLoopObs = CFRunLoopObserverCreate(kCFAllocatorDefault, kCFRunLoopAllActivities, YES, 0, &runLoopObserverCallBack, &cxt);
    // 3. 将创建好的观察者runLoopObs添加到主线程kCFRunLoopCommonModes模式下观察
    CFRunLoopAddObserver(CFRunLoopGetMain(), runLoopObs, kCFRunLoopCommonModes);
    // 4. 创建一个子线程用来监控主线程RunLoop活动状态obsActivity
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        // 5. 子线程开启一个持续的loop用来进行监控
        while (YES) {
            // 6. 设置触发卡顿的时间阈值NSEC_PER_SEC * 3，即3秒
            long wait = dispatch_semaphore_wait(self->semaphore, dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 3));
            // 7. 判断是否发生超时
            if (wait != 0) {
                if (!self->runLoopObs) {
                    self->semaphore = 0;
                    self->obsActivity = 0;
                    return;
                }
                // 8. 判断是否处于进入睡眠前kCFRunLoopBeforeSources状态，或者唤醒后kCFRunLoopAfterWaiting状态
                if (self->obsActivity == kCFRunLoopBeforeSources || self->obsActivity == kCFRunLoopAfterWaiting) {
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                        // 9. dump 出堆栈的信息
                        [self dumpStackInfo];
                    });
                }
            }
        }
    });
}

/// RunLoop监听回调
/// - Parameters:
///   - observer: 观察者runLoopObs
///   - activity: 主线程RunLoop活动状态obsActivity
///   - info: RunLoop监听器对象
static void runLoopObserverCallBack(CFRunLoopObserverRef observer, CFRunLoopActivity activity, void *info) {
    ViewController *monitor = (__bridge ViewController *)(info);
    monitor->obsActivity = activity;
    
    dispatch_semaphore_t semaphore = monitor->semaphore;
    dispatch_semaphore_signal(semaphore);
}

- (void)endMonitor {
    if (!runLoopObs) return;
    // 1. 将创建好的观察者runLoopObs从主线程kCFRunLoopCommonModes模式下移出观察
    CFRunLoopRemoveObserver(CFRunLoopGetMain(), runLoopObs, kCFRunLoopCommonModes);
    // 2. 将创建好的观察者runLoopObs释放
    CFRelease(runLoopObs);
    // 3. 将创建好的观察者runLoopObs置为空值
    runLoopObs = NULL;
}


/// todo: dump 出堆栈的信息
- (void)dumpStackInfo {
    NSLog(@"ViewController dumpStackInfo");
}

/// 性能优化
- (void)fixKaton {
    // 参考：AsyncDisplayKit
}

/// NSTimer依赖于RunLoop，如果RunLoop的任务过于繁重，可能会导致NSTimer不准时。而GCD的定时器会更加准时
- (void)gcdTimer {
    // 1. 不耗时ui操作放主队列
    dispatch_queue_t queue = dispatch_get_main_queue();
    // 2. 耗时操作放全局队列
    dispatch_queue_t queue2 = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    // 3. 创建一个定时器
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue2);
    // 4. 设置时间
    dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), (int64_t)(2.0 * NSEC_PER_SEC), 0);
    // 5. 设置回调
    dispatch_source_set_event_handler(timer, ^{
        NSLog(@"dispatch_source_set_event_handler 回调");
    });
    // 6. 启动定时器
    dispatch_resume(timer);
}
@end
