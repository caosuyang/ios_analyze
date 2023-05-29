```
1. iOS 崩溃千奇百怪，如何全面监控
2. 造成崩溃的情况有哪些，以及这些崩溃的日志都是如何捕获收集到的?
```
##  常见的崩溃情况

-   数组越界：在取数据索引时越界，App 会发生崩溃。还有一种情况，就是给数组添加了 nil 会崩溃。
-   多线程问题：在子线程中进行 UI 更新可能会发生崩溃。多个线程进行数据的读取操作，因为处理时机不一致，比如有一个线程在置空数据的同时另一个线程在读取这个数据，可能会出现崩溃情况。
-   主线程无响应：如果主线程超过系统规定的时间无响应，就会被 Watchdog 杀掉。这时，崩溃问题对应的异常编码是 0x8badf00d。关于这个异常编码，我还会在后文和你说明。
-   野指针：指针指向一个已删除的对象访问内存区域时，会出现野指针崩溃。野指针问题是需要我们重点关注的，因为它是导致 App 崩溃的最常见，也是最难定位的一种情况。关于野指针等内存相关问题，我会在第 14 篇文章“临近 OOM，如何获取详细内存分配信息，分析内存问题？”里和你详细说明。

程序崩溃了，你的 App 就不可用了，对用户的伤害也是最大的。因此，每家公司都会非常重视自家产品的崩溃率，并且会将崩溃率（也就是一段时间内崩溃次数与启动次数之比）作为优先级最高的技术指标，比如千分位是生死线，万分位是达标线等，去衡量一个 App 的高可用性。

而崩溃率等技术指标，一般都是由崩溃监控系统来搜集。同时，崩溃监控系统收集到的堆栈信息，也为解决崩溃问题提供了最重要的信息。

有些崩溃日志是可以通过信号捕获到的，而很多崩溃日志却是通过信号捕获不到的。KVO 问题、NSNotification 线程问题、数组越界、野指针等崩溃信息，是可以通过信号捕获的。但是，像后台任务超时、内存被打爆、主线程卡顿超阈值等信息，是无法通过信号捕捉到的。

## 我们先来看看信号可捕获的崩溃日志收集

收集崩溃日志最简单的方法，就是打开 Xcode 的菜单选择 Product -> Archive。

然后，在提交时选上“Upload your app’s symbols to receive symbolicated reports from Apple”，以后你就可以直接在 Xcode 的 Archive 里看到符号化后的崩溃日志了。

但是这种查看日志的方式，每次都是纯手工的操作，而且时效性较差。所以，目前很多公司的崩溃日志监控系统，都是通过[PLCrashReporter](https://www.plcrashreporter.org/) 这样的第三方开源库捕获崩溃日志，然后上传到自己服务器上进行整体监控的。

### 这类工具，是怎么知道 App 什么时候崩溃的？

EXC_BAD_ACCESS 这个异常会通过 SIGSEGV 信号发现有问题的线程。虽然信号的种类有很多，但是都可以通过注册 signalHandler 来捕获到。其实现代码，如下所示：

```objc
void registerSignalHandler(void) {

	signal(SIGSEGV, handleSignalException);
	
	signal(SIGFPE, handleSignalException);
	
	signal(SIGBUS, handleSignalException);
	
	signal(SIGPIPE, handleSignalException);
	
	signal(SIGHUP, handleSignalException);
	
	signal(SIGINT, handleSignalException);
	
	signal(SIGQUIT, handleSignalException);
	
	signal(SIGABRT, handleSignalException);
	
	signal(SIGILL, handleSignalException);

}

void handleSignalException(int signal) {

	NSMutableString *crashString = [[NSMutableString alloc]init];
	
	void* callstack[128];
	
	int i, frames = backtrace(callstack, 128);
	
	char** traceChar = backtrace_symbols(callstack, frames);
	
	for (i = 0; i <frames; ++i) {
	
	[crashString appendFormat:@"%s\n", traceChar[i]];
	
	}
	
	NSLog(crashString);

}
```

上面这段代码对各种信号都进行了注册，捕获到异常信号后，在处理方法 handleSignalException 里通过 backtrace_symbols 方法就能获取到当前的堆栈信息。堆栈信息可以先保存在本地，下次启动时再上传到崩溃监控服务器就可以了。

先将捕获到的堆栈信息保存在本地，是为了实现堆栈信息数据的持久化存储。那么，为什么要实现持久化存储呢？

这是因为，在保存完这些堆栈信息以后，App 就崩溃了，崩溃后内存里的数据也就都没有了。而将数据保存在本地磁盘中，就可以在 App 下次启动时能够很方便地读取到这些信息。

## 信号捕获不到的崩溃信息怎么收集？

1. 后台任务超时
2. 内存被打爆
3. 主线程卡顿超阈值

### 后台崩溃的原因

在你的程序退到后台以后，只有几秒钟的时间可以执行代码，接下来就会被系统挂起。进程挂起后所有线程都会暂停，不管这个线程是文件读写还是内存读写都会被暂停。但是，数据读写过程无法暂停只能被中断，中断时数据读写异常而且容易损坏文件，所以系统会选择主动杀掉 App 进程。

iOS 后台保活有 5 种方式：Background Mode、Background Fetch、Silent Push、PushKit、Background Task。Background Task 方式，是使用最多的。App 退后台后，默认都会使用这种方式。

Background Task 这种方式，就是系统提供了 beginBackgroundTaskWithExpirationHandler 方法来延长后台执行时间，可以解决你退后台后还需要一些时间去处理一些任务的诉求。

Background Task 方式的使用方法，如下面这段代码所示：

```
- (void)applicationDidEnterBackground:(UIApplication *)application {

	self.backgroundTaskIdentifier = [application beginBackgroundTaskWithExpirationHandler:^( void) {
	
	[self yourTask];
	
	}];

}
```

在这段代码中，yourTask 任务最多执行 3 分钟，3 分钟内 yourTask 运行完成，你的 App 就会挂起。 如果 yourTask 在 3 分钟之内没有执行完的话，系统会强制杀掉进程，从而造成崩溃，这就是为什么 App 退后台容易出现崩溃的原因。

后台崩溃造成的影响是未知的。持久化存储的数据出现了问题，就会造成你的 App 无法正常使用。

重要：写一段代码，在 App 退后台以后执行一段超过 3 分钟的任务，在临近 3 分钟时打印出线程堆栈。

### 如何避免后台崩溃

你知道了， App 退后台后，如果执行时间过长就会导致被系统杀掉。那么，如果我们要想避免这种崩溃发生的话，就需要严格控制后台数据的读写操作。比如，你可以先判断需要处理的数据的大小，如果数据过大，也就是在后台限制时间内或延长后台执行时间后也处理不完的话，可以考虑在程序下次启动或后台唤醒时再进行处理。

同时，App 退后台后，这种由于在规定时间内没有处理完而被系统强制杀掉的崩溃，是无法通过信号被捕获到的。这也说明了，随着团队规模扩大，要想保证 App 高可用的话，后台崩溃的监控就尤为重要了。

### 怎么去收集退后台后超过保活阈值而导致信号捕获不到的崩溃信息

采用 Background Task 方式时，我们可以根据 beginBackgroundTaskWithExpirationHandler 会让后台保活 3 分钟这个阈值，先设置一个计时器，在接近 3 分钟时判断后台程序是否还在执行。如果还在执行的话，我们就可以判断该程序即将后台崩溃，进行上报、记录，以达到监控的效果。

### 内存打爆

先要找到它们的阈值，然后在临近阈值时还在执行的后台程序，判断为将要崩溃，收集信息并上报。

关于内存阈值是怎么获取的，看第 14 篇文章“临近 OOM，如何获取详细内存分配信息，分析内存问题？”

### 主线程卡顿时间超过阈值被 watchdog 杀掉

先要找到它们的阈值，然后在临近阈值时还在执行的后台程序，判断为将要崩溃，收集信息并上报。

关于卡顿阈值是怎么获取的，看第 13 篇文章“如何利用 RunLoop 原理去监控卡顿？”

## 采集到崩溃信息后如何分析并解决崩溃问题

我们采集到的崩溃日志，主要包含的信息为：进程信息、基本信息、异常信息、线程回溯。

-   进程信息：崩溃进程的相关信息，比如崩溃报告唯一标识符、唯一键值、设备标识；
-   基本信息：崩溃发生的日期、iOS 版本；
-   异常信息：异常类型、异常编码、异常的线程；
-   线程回溯：崩溃时的方法调用栈。

通常情况下，我们分析崩溃日志时最先看的是异常信息，分析出问题的是哪个线程，在线程回溯里找到那个线程；然后，分析方法调用栈，符号化后的方法调用栈可以完整地看到方法调用的过程，从而知道问题发生在哪个方法的调用上。

方法调用栈顶，就是最后导致崩溃的方法调用。完整的崩溃日志里，除了线程方法调用栈还有异常编码。异常编码，就在异常信息里。

一些被系统杀掉的情况，我们可以通过异常编码来分析。你可以在维基百科上，查看[完整的异常编码](https://en.wikipedia.org/wiki/Hexspeak)。这里列出了 44 种异常编码，但常见的就是如下三种：

-   0x8badf00d，表示 App 在一定时间内无响应而被 watchdog 杀掉的情况。
-   0xdeadfa11，表示 App 被用户强制退出。
-   0xc00010ff，表示 App 因为运行造成设备温度太高而被杀掉。

0x8badf00d 这种情况是出现最多的。当出现被 watchdog 杀掉的情况时，我们就可以把范围控制在主线程被卡的情况。我会在第 13 篇文章“如何利用 RunLoop 原理去监控卡顿？”中，和你详细说明如何去监控这种情况来防范和快速定位到问题。

0xdeadfa11 的情况，是用户的主动行为，我们不用太关注。

0xc00010ff 这种情况，就要对每个线程 CPU 进行针对性的检查和优化。我会在第 18 篇文章“怎么减少 App 的电量消耗？”中，和你详细说明。

有了崩溃的方法调用堆栈后，大部分问题都能够通过方法调用堆栈，来快速地定位到具体是哪个方法调用出现了问题。有些问题仅仅通过这些堆栈还无法分析出来，这时就需要借助崩溃前用户相关行为和系统环境状况的日志来进行进一步分析。

关于日志如何收集协助分析问题，我会在第 15 篇文章“日志监控：怎样获取 App 中的全量日志？”中，和你详细说明。

## 项目收集崩溃日志

1. UncaughtExceptionHandler 信号捕获工具
2. [PLCrashReporter](https://www.plcrashreporter.org/) 第三方开源库

### UncaughtExceptionHandler 自定义工具类

代码如下所示：

```objc
//
//  UncaughtExceptionHandler.m
//  BWKOEM
//
//  Created by csy on 2022/12/7.
//  Copyright © 2022 com.banwokao. All rights reserved.
//

#import "UncaughtExceptionHandler.h"
#include <libkern/OSAtomic.h>
#include <execinfo.h>
#import "AFNetworking.h"

#define dispatch_main_async_safe(block)\
if ([NSThread isMainThread]) {\
block();\
} else {\
dispatch_async(dispatch_get_main_queue(), block);\
}

// NSException错误名称
NSString * const UncaughtExceptionHandlerSignalExceptionName = @"UncaughtExceptionHandlerSignalExceptionName";
// signal错误堆栈的条数
NSString * const UncaughtExceptionHandlerSignalKey = @"UncaughtExceptionHandlerSignalKey";
// 错误堆栈信息
NSString * const UncaughtExceptionHandlerAddressesKey = @"UncaughtExceptionHandlerAddressesKey";
// 初始化的错误条数
volatile int32_t UncaughtExceptionCount = 0;
// 错误最大的条数
const int32_t UncaughtExceptionMaximum = 10;
// 是否弹窗提示
static BOOL showAlertView = nil;
/// 接口地址
static NSString *_urlString = nil;
/// 唯一身份认证，登录成功后调用的所有接口都需要该参数
static NSString *_token = nil;
/// 设备的具体型号，不允许空
static NSString *_modelName = nil;

/// 异常处理
void HandleException(NSException *exception);
/// Signal类型错误信号处理
void SignalHandler(int signal);
/// 获取app信息
NSString *getAppInfo(void);

/// 注册 signalHandler
void registerSignalHandler(void);
/// 捕获信号异常
void handleSignalException(int signal);

@interface UncaughtExceptionHandler()
/// 判断程序是否继续执行
@property (nonatomic, assign) BOOL dismissed;
@end

@implementation UncaughtExceptionHandler

#pragma mark - Public Methods
+ (void)installUncaughtExceptionHandler:(BOOL)install showAlert:(BOOL)showAlert urlString:(NSString *)urlString token:(NSString *)token modelName:(NSString *)modelName {
    
    [[self alloc] setUrlString:urlString token:token modelName:modelName];
    [self installUncaughtExceptionHandler:install showAlert:showAlert];
}

+ (void)installUncaughtExceptionHandler:(BOOL)install showAlert:(BOOL)showAlert {
    
    if (install && showAlert) {
        [[self alloc] alertView:showAlert];
    }
    
    // 通过【NSSetUncaughtExceptionHandler】机制捕获处理app的异常
    NSSetUncaughtExceptionHandler(install ? HandleException : NULL);
    /**
     1、程序不可捕获、阻塞或忽略的信号有：SIGKILL、SIGSTOP
     2、不能恢复至默认动作的信号有：SIGILL、SIGTRAP
     3、默认会导致进程流产的信号有：SIGABRT、SIGBUS、SIGFPE、SIGILL、SIGIOT、SIGQUIT、SIGSEGV、SIGTRAP、SIGXCPU、SIGXFSZ
     4、默认会导致进程退出的信号有: SIGALRM、SIGHUP、SIGINT、SIGKILL、SIGPIPE、SIGPOLL、SIGPROF、SIGSYS、SIGTERM、SIGUSR1、SIGUSR2、SIGVTALRM
     5、默认会导致进程停止的信号有：SIGSTOP、SIGTSTP、SIGTTIN、SIGTTOU
     6、默认进程忽略的信号有：SIGCHLD、SIGPWR、SIGURG、SIGWINCH
     7、此外，SIGIO在SVR4是退出，在4.3BSD中是忽略；
     8、SIGCONT在进程挂起时是继续，否则是忽略，不能被阻塞。
     ————————————————
     版权声明：本文为CSDN博主「瓜子三百克」的原创文章，遵循CC 4.0 BY-SA版权协议，转载请附上原文出处链接及本声明。
     原文链接：https://blog.csdn.net/weixin_38633659/article/details/82496635
     */
    signal(SIGABRT, install ? SignalHandler : SIG_DFL);
    signal(SIGILL, install ? SignalHandler : SIG_DFL);
    signal(SIGSEGV, install ? SignalHandler : SIG_DFL);
    signal(SIGFPE, install ? SignalHandler : SIG_DFL);
    signal(SIGBUS, install ? SignalHandler : SIG_DFL);
    signal(SIGPIPE, install ? SignalHandler : SIG_DFL);
    signal(SIGSYS, install ? SignalHandler : SIG_DFL);
    signal(SIGTRAP, install ? SignalHandler : SIG_DFL);
    signal(SIGHUP, install ? SignalHandler : SIG_DFL);
    signal(SIGINT, install ? SignalHandler : SIG_DFL);
    signal(SIGQUIT, install ? SignalHandler : SIG_DFL);
    
    // 通过注册 signalHandler 来捕获到信号
//    registerSignalHandler();
}

#pragma mark - Private Methods
/// 设置添加错误日志所需要的参数
/// - Parameters:
///   - URLString: 接口地址
///   - token: 唯一身份认证，登录成功后调用的所有接口都需要该参数
///   - modelName: 设备的具体型号，不允许空
- (void)setUrlString:(NSString *)urlString token:(NSString *)token modelName:(NSString *)modelName {
    _urlString = urlString;
    _token = token;
    _modelName = modelName;
}

/// 设置是否弹窗提示
/// - Parameter show: 是否在发生异常时弹出alertView
- (void)alertView:(BOOL)show {
    showAlertView = show;
}

/// 专门针对Signal类型的错误获取堆栈信息
+ (NSArray *)backtrace {
    // 指针列表
    void* callstack[128];
    
    // backtrace用来获取当前线程的调用堆栈，获取的信息存放在这里的callstack中
    // 128用来指定当前的buffer中可以保存多少个void*元素
    // 返回值是实际获取的指针个数
    int frames = backtrace(callstack, 128);
    
    // backtrace_symbols将从backtrace函数获取的信息转化为一个字符串数组
    // 返回一个指向字符串数组的指针
    // 每个字符串包含了一个相对于callstack中对应元素的可打印信息，包括函数名、偏移地址、实际返回地址
    char **strs = backtrace_symbols(callstack, frames);
    
    int i;
    NSMutableArray *backtrace = [NSMutableArray arrayWithCapacity:frames];
    for (i = 0; i < frames; i++) {
        [backtrace addObject:[NSString stringWithUTF8String:strs[i]]];
    }
    free(strs);
    
    return backtrace;
}

/// 所有错误异常处理
- (void)handleException:(NSException *)exception {
    // 验证和保存错误数据
    NSString *exceptionInfo = [self validateAndSaveCriticalApplicationData:exception];

    // 添加错误日志
    [self loadApiLoginAppendErrorLogWithURLString:_urlString token:_token content:exceptionInfo];
    
    // 错误弹窗提示设置
    if (!showAlertView) {
        return;
    }
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    UIAlertView *alert =
    [[UIAlertView alloc]
     initWithTitle:@"出错啦"
     message:[NSString stringWithFormat:@"你可以尝试继续操作，但是应用可能无法正常运行.\n%@", exceptionInfo]
     delegate:self
     cancelButtonTitle:@"退出"
     otherButtonTitles:@"继续", nil];
    [alert show];
#pragma clang diagnostic pop
    
    CFRunLoopRef runLoop = CFRunLoopGetCurrent();
    CFArrayRef allModes = CFRunLoopCopyAllModes(runLoop);
    
    while (!self.dismissed) {
        // 点击继续
        for (NSString *mode in (__bridge NSArray *)allModes) {
            // 快速切换Mode
            CFRunLoopRunInMode((CFStringRef)mode, 0.001, false);
        }
    }
    
    // 点击退出
    CFRelease(allModes);
    
    NSSetUncaughtExceptionHandler(NULL);
    signal(SIGABRT, SIG_DFL);
    signal(SIGILL, SIG_DFL);
    signal(SIGSEGV, SIG_DFL);
    signal(SIGFPE, SIG_DFL);
    signal(SIGBUS, SIG_DFL);
    signal(SIGPIPE, SIG_DFL);
    signal(SIGSYS, SIG_DFL);
    signal(SIGTRAP, SIG_DFL);
    signal(SIGHUP, SIG_DFL);
    signal(SIGINT, SIG_DFL);
    signal(SIGQUIT, SIG_DFL);
    
    if ([[exception name] isEqual:UncaughtExceptionHandlerSignalExceptionName]) {
        kill(getpid(), [[[exception userInfo] objectForKey:UncaughtExceptionHandlerSignalKey] intValue]);
    } else {
        [exception raise];
    }
}

/// 点击退出
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
- (void)alertView:(UIAlertView *)anAlertView clickedButtonAtIndex:(NSInteger)anIndex {
#pragma clang diagnostic pop
    
    if (anIndex == 0) {
        self.dismissed = YES;
    }
}

/// 验证和保存错误数据
- (NSString *)validateAndSaveCriticalApplicationData:(NSException *)exception {
    // 报错信息
    NSString *exceptionInfo = [NSString stringWithFormat:@"\n--------Log Exception---------\nappInfo             :\n%@\n\nexception name      :%@\nexception reason    :%@\nexception userInfo  :%@\ncallStackSymbols    :%@\n\n--------End Log Exception-----", getAppInfo(),exception.name, exception.reason, exception.userInfo ? : @"no user info", [exception callStackSymbols]];
    NSLog(@"exceptionInfo: %@", exceptionInfo);
    // 写入文件
    [exceptionInfo writeToFile:[NSString stringWithFormat:@"%@/Documents/error.log",NSHomeDirectory()]  atomically:YES encoding:NSUTF8StringEncoding error:nil];
    return exceptionInfo;
}
/// 添加错误日志
/// - Parameters:
///   - URLString: 接口地址
///   - token: 唯一身份认证，登录成功后调用的所有接口都需要该参数
///   - content: 提交的内容
- (void)loadApiLoginAppendErrorLogWithURLString:(NSString *)URLString token:(NSString *)token content:(NSString *)content {
    if (token == nil || token.length == 0) {
        NSLog(@"唯一身份认证，登录成功后调用的所有接口都需要该参数，不允许空");
        return;
    }
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.responseSerializer = [AFHTTPResponseSerializer serializer];
    manager.requestSerializer = [AFJSONRequestSerializer serializerWithWritingOptions:NSJSONWritingPrettyPrinted];
    manager.responseSerializer.acceptableContentTypes = [NSSet setWithObjects:@"text/json",@"application/X-javascript",@"text/javascript",@"text/plain", @"text/html", @"application/json",@"text/css", nil];
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    // 错误日志内容
    [parameters setValue:content forKey:@"content"];
    // 登录成功后返回的token值
    [parameters setValue:token forKey:@"token"];
    NSMutableDictionary *headers = [NSMutableDictionary dictionary];
    [headers setValue:@"application/json" forKey:@"Content-Type"];
    NSLog(@"parameters: %@", parameters);
    NSLog(@"headers: %@", headers);
    NSLog(@"URLString: %@", URLString);
    [manager POST:URLString parameters:parameters headers:headers progress:^(NSProgress *_Nonnull uploadProgress) {
        NSLog(@"正在提交");
    } success:^(NSURLSessionDataTask *_Nonnull task,id _Nullable responseObject) {
        NSLog(@"提交成功");
        // responseObject: {length = 45, bytes = 0x7b22636f 6465223a 3230302c 226d7367 ... 61223a6e 756c6c7d }
        NSLog(@"responseObject: %@", responseObject);
    } failure:^(NSURLSessionDataTask *_Nullable task,NSError *_Nonnull error) {
        NSLog(@"网络连接失败");
        NSLog(@"error: %@", error);
    }];
}

@end

#pragma mark - C Methods
/// 奔溃异常处理
void HandleException(NSException *exception) {
    // 异常数量
    int32_t exceptionCount = OSAtomicIncrement32(&UncaughtExceptionCount);
    
    // 如果太多不用处理
    if (exceptionCount > UncaughtExceptionMaximum) {
        return;
    }
    
    // 获取调用堆栈
    NSArray *callStack = [exception callStackSymbols];
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithDictionary:[exception userInfo]];
    [userInfo setObject:callStack forKey:UncaughtExceptionHandlerAddressesKey];
    
    // 在主线程中，执行制定的方法, withObject是执行方法传入的参数
    [[[UncaughtExceptionHandler alloc] init]
     performSelectorOnMainThread:@selector(handleException:)
     withObject:
     [NSException exceptionWithName:[exception name]
                             reason:[exception reason]
                           userInfo:userInfo]
     waitUntilDone:YES];
}

/// signal报错处理
void SignalHandler(int signal) {
    // 异常数量
    int32_t exceptionCount = OSAtomicIncrement32(&UncaughtExceptionCount);
    
    // 如果太多不用处理
    if (exceptionCount > UncaughtExceptionMaximum) {
        return;
    }
    
    NSString* description = nil;
    switch (signal) {
        case SIGABRT:
            description = [NSString stringWithFormat:@"Signal SIGABRT was raised!\n"];
            break;
        case SIGILL:
            description = [NSString stringWithFormat:@"Signal SIGILL was raised!\n"];
            break;
        case SIGSEGV:
            description = [NSString stringWithFormat:@"Signal SIGSEGV was raised!\n"];
            break;
        case SIGFPE:
            description = [NSString stringWithFormat:@"Signal SIGFPE was raised!\n"];
            break;
        case SIGBUS:
            description = [NSString stringWithFormat:@"Signal SIGBUS was raised!\n"];
            break;
        case SIGPIPE:
            description = [NSString stringWithFormat:@"Signal SIGPIPE was raised!\n"];
            break;
        case SIGSYS:
            description = [NSString stringWithFormat:@"Signal SIGSYS was raised!\n"];
            break;
        case SIGTRAP:
            description = [NSString stringWithFormat:@"Signal SIGTRAP was raised!\n"];
            break;
        case SIGHUP:
            description = [NSString stringWithFormat:@"Signal SIGHUP was raised!\n"];
            break;
        case SIGINT:
            description = [NSString stringWithFormat:@"Signal SIGINT was raised!\n"];
            break;
        case SIGQUIT:
            description = [NSString stringWithFormat:@"Signal SIGQUIT was raised!\n"];
            break;
        default:
            description = [NSString stringWithFormat:@"Signal %d was raised!",signal];
    }
    
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    NSArray *callStack = [UncaughtExceptionHandler backtrace];
    [userInfo setObject:callStack forKey:UncaughtExceptionHandlerAddressesKey];
    [userInfo setObject:[NSNumber numberWithInt:signal] forKey:UncaughtExceptionHandlerSignalKey];
    
    // 在主线程中，执行指定的方法, withObject是执行方法传入的参数
    [[[UncaughtExceptionHandler alloc] init]
     performSelectorOnMainThread:@selector(handleException:)
     withObject:
     [NSException exceptionWithName:UncaughtExceptionHandlerSignalExceptionName
                             reason:description
                           userInfo:userInfo]
     waitUntilDone:YES];
}

/// 获取app信息
NSString* getAppInfo() {
    NSString *appInfo = [NSString stringWithFormat:@"App : %@ %@(%@)\nDevice : %@\nOS Version : %@ %@\n",
                         [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"],
                         [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"],
                         [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"],
                         _modelName,
                         [UIDevice currentDevice].systemName,
                         [UIDevice currentDevice].systemVersion];
    return appInfo;
}

#pragma mark - signalHandler
/// 通过注册 signalHandler 来捕获到信号
void registerSignalHandler(void) {
    signal(SIGSEGV, handleSignalException);
    signal(SIGFPE, handleSignalException);
    signal(SIGBUS, handleSignalException);
    signal(SIGPIPE, handleSignalException);
    signal(SIGHUP, handleSignalException);
    signal(SIGINT, handleSignalException);
    signal(SIGQUIT, handleSignalException);
    signal(SIGABRT, handleSignalException);
    signal(SIGILL, handleSignalException);
}

/// 处理信号异常
void handleSignalException(int signal) {
    NSMutableString *crashString = [[NSMutableString alloc]init];
    void* callstack[128];
    int i, frames = backtrace(callstack, 128);
    char** traceChar = backtrace_symbols(callstack, frames);
    for (i = 0; i <frames; ++i) {
        [crashString appendFormat:@"%s\n", traceChar[i]];
    }
    NSLog(@"crashString: %@", crashString);
}

```
### PLCrashReporter 第三方库

代码如下所示：

```objc
// MARK: - 启用崩溃报告器，捕获崩溃日志
extension AppDelegate {
    /// 启用崩溃报告器，捕获崩溃日志
    private func startCrashReporter() {
        // 取消注释并实现 isDebuggerAttached 以使用调试器安全地运行此代码
        // 请参阅：https://github.com/microsoft/plcrashreporter/blob/2dd862ce049e6f43feb355308dfc710f3af54c4d/Source/Crash%20Demo/main.m#L96

#if DEBUG
        print("崩溃应用应在不存在调试器的情况下运行，退出")
#else
        // if (!isDebuggerAttached()) {

        // 强烈建议仅为非发布版本启用本地符号化
        // 使用 [] 作为发布版本
//        let config = PLCrashReporterConfig(signalHandlerType: .mach, symbolicationStrategy: .all)
        let config = PLCrashReporterConfig(signalHandlerType: .mach, symbolicationStrategy: [])
        guard let crashReporter = PLCrashReporter(configuration: config) else {
            print("无法创建 PLCrashReporter 的实例")
            return
        }

        // 启用崩溃报告器
        do {
            try crashReporter.enableAndReturnError()
        } catch let error {
            print("警告：无法启用崩溃报告器：\(error)")
        }
        // }


        // 尝试加载崩溃报告
        if crashReporter.hasPendingCrashReport() {
            do {
                let data = try crashReporter.loadPendingCrashReportDataAndReturnError()

                // 检索崩溃报告器数据
                let report = try PLCrashReport(data: data)

                // 我们可以从这里发送报告，但我们只会打印出一些调试信息
                if let text = PLCrashReportTextFormatter.stringValue(for: report, with: PLCrashReportTextFormatiOS) {
                    print("[AppDelegate:startCrashReporter] hasPendingCrashReport: \(text)")
                    // 上传到自己服务器上进行整体监控
                    // ...
                } else {
                    print("崩溃报告器：无法将报告转换为文本")
                }
            } catch let error {
                print("崩溃报告器无法加载和分析，出现错误：\(error)")
            }
        }

        // 清除报告
        crashReporter.purgePendingCrashReport()
#endif
    }
}

```

综上，通过[PLCrashReporter](https://www.plcrashreporter.org/) 这样的第三方开源库捕获崩溃日志，然后上传到自己服务器上进行整体监控，这种方式比较好。

## 服务器崩溃记录（在线学学习app）

在线学学习app，从课程列表点击进入详情页面发生异常崩溃，日志记录如下：

```objc
// 日志1
--------Log Exception---------
 appInfo             :
 App : 在线学教师 3.6.6(20221225)
 Device : iPhone 13 Pro Max
 OS Version : iOS 16.2
 
 
 exception name      :UncaughtExceptionHandlerSignalExceptionName
 exception reason    :Signal SIGTRAP was raised!
 
 exception userInfo  :{
     UncaughtExceptionHandlerAddressesKey =     (
         "0   \U5728\U7ebf\U5b66\U6559\U5e08\U8bc1                  0x0000000100b18d98 \U5728\U7ebf\U5b66\U6559\U5e08\U8bc1 + 495000",
         "1   \U5728\U7ebf\U5b66\U6559\U5e08\U8bc1                  0x0000000100b18bc4 \U5728\U7ebf\U5b66\U6559\U5e08\U8bc1 + 494532",
         "2   libsystem_platform.dylib            0x00000001f60d0a90 4BFE8F47-51E7-37B2-A2A9-A42194239137 + 6800",
         "3   \U5728\U7ebf\U5b66\U6559\U5e08\U8bc1                  0x0000000100c83790 \U5728\U7ebf\U5b66\U6559\U5e08\U8bc1 + 1980304",
         "4   \U5728\U7ebf\U5b66\U6559\U5e08\U8bc1                  0x0000000100c822f8 \U5728\U7ebf\U5b66\U6559\U5e08\U8bc1 + 1975032",
         "5   \U5728\U7ebf\U5b66\U6559\U5e08\U8bc1                  0x0000000100c2b500 \U5728\U7ebf\U5b66\U6559\U5e08\U8bc1 + 1619200",
         "6   \U5728\U7ebf\U5b66\U6559\U5e08\U8bc1                  0x0000000100c28500 \U5728\U7ebf\U5b66\U6559\U5e08\U8bc1 + 1606912",
         "7   UIKitCore                           0x00000001aa3f4b34 59CBC9B5-30AE-396E-A269-A986640001BC + 1358644",
         "8   UIKitCore                           0x00000001aa3c84cc 59CBC9B5-30AE-396E-A269-A986640001BC + 1176780",
         "9   UIKitCore                           0x00000001aa301b28 59CBC9B5-30AE-396E-A269-A986640001BC + 363304",
         "10  UIKitCore                           0x00000001aa30161c 59CBC9B5-30AE-396E-A269-A986640001BC + 362012",
         "11  UIKitCore                           0x00000001aa2ad860 59CBC9B5-30AE-396E-A269-A986640001BC + 18528",
         "12  QuartzCore                          0x00000001a9780b0c E0E47B5D-2805-361D-88C4-875002B0244D + 39692",
         "13  QuartzCore                          0x00000001a97941c0 E0E47B5D-2805-361

// 日志2
--------Log Exception---------
 appInfo             :
 App : 在线学教师 3.6.6(20221225)
 Device : iPhone 13 Pro Max
 OS Version : iOS 16.2
 
 
 exception name      :UncaughtExceptionHandlerSignalExceptionName
 exception reason    :Signal SIGTRAP was raised!
 
 exception userInfo  :{
     UncaughtExceptionHandlerAddressesKey =     (
         "0   \U5728\U7ebf\U5b66\U6559\U5e08\U8bc1                  0x0000000100b04d98 \U5728\U7ebf\U5b66\U6559\U5e08\U8bc1 + 495000",
         "1   \U5728\U7ebf\U5b66\U6559\U5e08\U8bc1                  0x0000000100b04bc4 \U5728\U7ebf\U5b66\U6559\U5e08\U8bc1 + 494532",
         "2   libsystem_platform.dylib            0x00000001f60d0a90 4BFE8F47-51E7-37B2-A2A9-A42194239137 + 6800",
         "3   \U5728\U7ebf\U5b66\U6559\U5e08\U8bc1                  0x0000000100c6f790 \U5728\U7ebf\U5b66\U6559\U5e08\U8bc1 + 1980304",
         "4   \U5728\U7ebf\U5b66\U6559\U5e08\U8bc1                  0x0000000100c6e2f8 \U5728\U7ebf\U5b66\U6559\U5e08\U8bc1 + 1975032",
         "5   \U5728\U7ebf\U5b66\U6559\U5e08\U8bc1                  0x0000000100c17500 \U5728\U7ebf\U5b66\U6559\U5e08\U8bc1 + 1619200",
         "6   \U5728\U7ebf\U5b66\U6559\U5e08\U8bc1                  0x0000000100c14500 \U5728\U7ebf\U5b66\U6559\U5e08\U8bc1 + 1606912",
         "7   UIKitCore                           0x00000001aa3f4b34 59CBC9B5-30AE-396E-A269-A986640001BC + 1358644",
         "8   UIKitCore                           0x00000001aa3c84cc 59CBC9B5-30AE-396E-A269-A986640001BC + 1176780",
         "9   UIKitCore                           0x00000001aa301b28 59CBC9B5-30AE-396E-A269-A986640001BC + 363304",
         "10  UIKitCore                           0x00000001aa30161c 59CBC9B5-30AE-396E-A269-A986640001BC + 362012",
         "11  UIKitCore                           0x00000001aa2ad860 59CBC9B5-30AE-396E-A269-A986640001BC + 18528",
         "12  QuartzCore                          0x00000001a9780b0c E0E47B5D-2805-361D-88C4-875002B0244D + 39692",
         "13  QuartzCore                          0x00000001a97941c0 E0E47B5D-2805-361

// 日志3
--------Log Exception---------
 appInfo             :
 App : 在线学教师 3.6.6(20221225)
 Device : iPhone 13 Pro Max
 OS Version : iOS 16.2
 
 
 exception name      :UncaughtExceptionHandlerSignalExceptionName
 exception reason    :Signal SIGTRAP was raised!
 
 exception userInfo  :{
     UncaughtExceptionHandlerAddressesKey =     (
         "0   \U5728\U7ebf\U5b66\U6559\U5e08\U8bc1                  0x0000000100d44d98 \U5728\U7ebf\U5b66\U6559\U5e08\U8bc1 + 495000",
         "1   \U5728\U7ebf\U5b66\U6559\U5e08\U8bc1                  0x0000000100d44bc4 \U5728\U7ebf\U5b66\U6559\U5e08\U8bc1 + 494532",
         "2   libsystem_platform.dylib            0x00000001f60d0a90 4BFE8F47-51E7-37B2-A2A9-A42194239137 + 6800",
         "3   \U5728\U7ebf\U5b66\U6559\U5e08\U8bc1                  0x0000000100eaf790 \U5728\U7ebf\U5b66\U6559\U5e08\U8bc1 + 1980304",
         "4   \U5728\U7ebf\U5b66\U6559\U5e08\U8bc1                  0x0000000100eae2f8 \U5728\U7ebf\U5b66\U6559\U5e08\U8bc1 + 1975032",
         "5   \U5728\U7ebf\U5b66\U6559\U5e08\U8bc1                  0x0000000100e57500 \U5728\U7ebf\U5b66\U6559\U5e08\U8bc1 + 1619200",
         "6   \U5728\U7ebf\U5b66\U6559\U5e08\U8bc1                  0x0000000100e54500 \U5728\U7ebf\U5b66\U6559\U5e08\U8bc1 + 1606912",
         "7   UIKitCore                           0x00000001aa3f4b34 59CBC9B5-30AE-396E-A269-A986640001BC + 1358644",
         "8   UIKitCore                           0x00000001aa3c84cc 59CBC9B5-30AE-396E-A269-A986640001BC + 1176780",
         "9   UIKitCore                           0x00000001aa301b28 59CBC9B5-30AE-396E-A269-A986640001BC + 363304",
         "10  UIKitCore                           0x00000001aa30161c 59CBC9B5-30AE-396E-A269-A986640001BC + 362012",
         "11  UIKitCore                           0x00000001aa2ad860 59CBC9B5-30AE-396E-A269-A986640001BC + 18528",
         "12  QuartzCore                          0x00000001a9780b0c E0E47B5D-2805-361D-88C4-875002B0244D + 39692",
         "13  QuartzCore                          0x00000001a97941c0 E0E47B5D-2805-361

// 日志4
--------Log Exception---------
 appInfo             :
 App : 在线学教师 3.6.6(20221225)
 Device : iPhone 13 Pro Max
 OS Version : iOS 16.2
 
 
 exception name      :UncaughtExceptionHandlerSignalExceptionName
 exception reason    :Signal SIGTRAP was raised!
 
 exception userInfo  :{
     UncaughtExceptionHandlerAddressesKey =     (
         "0   \U5728\U7ebf\U5b66\U6559\U5e08\U8bc1                  0x00000001007c0d98 \U5728\U7ebf\U5b66\U6559\U5e08\U8bc1 + 495000",
         "1   \U5728\U7ebf\U5b66\U6559\U5e08\U8bc1                  0x00000001007c0bc4 \U5728\U7ebf\U5b66\U6559\U5e08\U8bc1 + 494532",
         "2   libsystem_platform.dylib            0x00000001f60d0a90 4BFE8F47-51E7-37B2-A2A9-A42194239137 + 6800",
         "3   \U5728\U7ebf\U5b66\U6559\U5e08\U8bc1                  0x000000010092b790 \U5728\U7ebf\U5b66\U6559\U5e08\U8bc1 + 1980304",
         "4   \U5728\U7ebf\U5b66\U6559\U5e08\U8bc1                  0x000000010092a2f8 \U5728\U7ebf\U5b66\U6559\U5e08\U8bc1 + 1975032",
         "5   \U5728\U7ebf\U5b66\U6559\U5e08\U8bc1                  0x00000001008d3500 \U5728\U7ebf\U5b66\U6559\U5e08\U8bc1 + 1619200",
         "6   \U5728\U7ebf\U5b66\U6559\U5e08\U8bc1                  0x00000001008d0500 \U5728\U7ebf\U5b66\U6559\U5e08\U8bc1 + 1606912",
         "7   UIKitCore                           0x00000001aa3f4b34 59CBC9B5-30AE-396E-A269-A986640001BC + 1358644",
         "8   UIKitCore                           0x00000001aa3c84cc 59CBC9B5-30AE-396E-A269-A986640001BC + 1176780",
         "9   UIKitCore                           0x00000001aa301b28 59CBC9B5-30AE-396E-A269-A986640001BC + 363304",
         "10  UIKitCore                           0x00000001aa30161c 59CBC9B5-30AE-396E-A269-A986640001BC + 362012",
         "11  UIKitCore                           0x00000001aa2ad860 59CBC9B5-30AE-396E-A269-A986640001BC + 18528",
         "12  QuartzCore                          0x00000001a9780b0c E0E47B5D-2805-361D-88C4-875002B0244D + 39692",
         "13  QuartzCore                          0x00000001a97941c0 E0E47B5D-2805-361
```

### 解决方案

1.  定位到第三方库其中一个类，类中初始化方法存在异常，数组越界
2. 直播详情类，存在大量对对象进行强制解包，有时候对象是nil值，将会导致崩溃

### 引起的问题

崩溃情况消失，但是有一个用户详情页面空白，没有日志记录

### 结合dsym文件分析内存地址

结合dsym文件分析了内存地址，发现这里的 sigtrap  应该不是一个崩溃信号，可能是处理 trap 指令时候发的这个信号，这边把这个截获了。所以这里每次内存地址都不一样 ，这里的log 推断出不是那个直播详情页面的。

用户直播详情空白的情况，现在明确肯定不是崩溃了。sigtrap 代表陷阱信号，它并不是一个真正的崩溃信号，会在处理器执行 trap 指令发送。

优化方案：后面会把集成日志这个信号量优化下，捕获这个信号没有意义。