## APP 的启动

App 的启动分为冷启动和热启动：

1. 冷启动是指， App 点击启动前，它的进程不在系统里，需要系统新创建一个进程分配给它启动的情况。这是一次完整的启动过程
2. 热启动是指 ，App 在冷启动后用户将 App 退后台，在 App 的进程还在系统里的情况下，用户重新启动进入 App 的过程，这个过程做的事情非常少

所以，我们只展开 App 冷启动的优化

## App 在启动时干的事

App 的启动时间，指的是从用户点击 App 开始，到用户看到第一个界面之间的时间，主要包括三个阶段：

1. main() 函数执行前
2. main() 函数执行后
3. 首屏渲染完成后

## main() 函数执行前

在 main() 函数执行前，系统主要会做下面几件事情：

- 加载可执行文件（App 的.o 文件的集合）
- 加载动态链接库，进行 rebase 指针调整和 bind 符号绑定
- Objc 运行时的初始处理，包括 Objc 相关类的注册、category 注册、selector 唯一性检查等
- 初始化，包括了执行 +load() 方法、attribute((constructor)) 修饰的函数的调用、创建 C++ 静态全局变量

这个阶段对于启动速度优化来说，可以做的事情包括：

- 减少动态库加载。每个库本身都有依赖关系，苹果公司建议使用更少的动态库，并且建议在使用动态库的数量较多时，尽量将多个动态库进行合并。数量上，苹果公司最多可以支持 6 个非系统动态库合并为一个
- 减少加载启动后不会去使用的类或者方法
- +load() 方法里的内容可以放到首屏渲染完成后再执行，或使用 +initialize() 方法替换掉。因为，在一个 +load() 方法里，进行运行时方法替换操作会带来 4 毫秒的消耗。不要小看这 4 毫秒，积少成多，执行 +load() 方法对启动速度的影响会越来越大
- 控制 C++ 全局变量的数量

## main() 函数执行后

main() 函数执行后的阶段，指的是从 main() 函数执行开始，到 appDelegate 的 didFinishLaunchingWithOptions 方法里首屏渲染相关方法执行完成

首页的业务代码都是要在这个阶段，也就是首屏渲染前执行的，主要包括了：

- 首屏初始化所需配置文件的读写操作
- 首屏列表大数据的读取
- 首屏渲染的大量计算

## 首屏渲染完成后

首屏渲染后的这个阶段，主要完成的是，非首屏其他业务服务模块的初始化、监听的注册、配置文件的读取等

从函数上来看，这个阶段就是从渲染完成时开始，到 didFinishLaunchingWithOptions 方法作用域结束时结束

这个阶段用户已经能够看到 App 的首页信息了，所以优化的优先级排在最后。但是，那些会卡住主线程的方法还是需要最优先处理的，不然还是会影响到用户后面的交互操作

## 功能级别的启动优化

功能级别的启动优化，就是要从 main() 函数执行后这个阶段下手

优化的思路是： main() 函数开始执行后到首屏渲染完成前只处理首屏相关的业务，其他非首屏业务的初始化、监听注册、配置文件读取等都放到首屏渲染完成后去做

## 方法级别的启动优化

检查首屏渲染完成前主线程上有哪些耗时方法，将没必要的耗时方法滞后或者异步执行。通常情况下，耗时较长的方法主要发生在计算大量数据的情况下，具体的表现就是加载、编辑、存储图片和文件等资源

## 对 App 启动速度的监控

1. 第一种方法是，定时抓取主线程上的方法调用堆栈，计算一段时间里各个方法的耗时。Xcode 工具套件里自带的 Time Profiler ，采用的就是这种方式

![[Time Profiler 抓取方法调用堆栈计算main耗时.png]]

上图所示，main函数方法执行耗时占比 19.2%，耗时 94.00 ms

![[Time Profiler 抓取方法调用堆栈计算appProxy耗时.png]]

上图所示，appProxy 函数方法执行耗时占比 55.0%，耗时 22.00 ms

由上图可见，Time Profiler 工具定时间隔设置得长了，会漏掉一些方法，从而导致检查出来的耗时不精确

2. 第二种方法是，对 objc_msgSend 方法进行 hook 来掌握所有方法的执行耗时

## 使用 hook objc_msgSend 方式来检查启动方法的执行耗时

1. 阅读 objc_msgSend 源码
2. Facebook 开源库 fishhook，可以在 iOS 上运行的 Mach-O 二进制文件中动态地重新绑定符号：https://github.com/facebook/fishhook
3. 检查方法耗时的工具 SMCallTrace：在需要检测耗时时间的地方调用 [SMCallTrace start]，结束时调用 stop 和 save 就可以打印出方法的调用层级和耗时了。还可以设置最大深度和最小耗时检测，来过滤不需要看到的信息

## 源码分析

BaseAppDelegate 类中 application:didFinishLaunchingWithOptions 方法源码如下：

```objc
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
//    [SMCallTrace start];
   [SMCallTrace startWithMaxDepth:0];
//    [SMCallTrace startWithMinCost:100];
//    [SMCallTrace startWithMaxDepth:0 minCost:100];
   
   [self registAPPStartInit];
   
   [self appProxy:application didFinishLaunchingWithOptions:launchOptions];
   
   [self installUncaughtExceptionHandler];
   
   [self resetApp];
   
   [self setProgress];
   
   [SMCallTrace save];
   return YES;
}
   
- (void)setProgress {
   //progress
   UIView<IProgressView>* progress = [self getProgressInstance];
   if (progress) {
       [[ProgressIndicator sharedSingleton] setProgress:progress];
   }else{
       [[ProgressIndicator sharedSingleton] setProgress:[[DefaultProgress alloc] init]];
   }
}
   
- (void)resetApp {
   //默认打开初始化页面
   self.window = [[UIWindow alloc]initWithFrame:[[UIScreen mainScreen]bounds]];
   __weak typeof(self) weakSelf =self;
   [AppInfo setAppResetBlock:^{
       UIViewController* controller = [weakSelf getInitController];
       NSArray* array = [weakSelf getGuideimagePaths];
       
       weakSelf.window = [AppRootWindow getInstance];
       if (controller) {
           if([ViewUtil isFirstLauch] && array){//处理引导页面的添加
               UserGuideViewController* guideController = [[UserGuideViewController alloc]initWithImages:array];
               [weakSelf.window setRootViewController:guideController];
               [guideController setEnterCallback:^{
                   [weakSelf.window setRootViewController:controller];
               }];
           }else{
               [weakSelf.window setRootViewController:controller];
           }
           [weakSelf.window makeKeyAndVisible];
       }
   }];
   [AppInfo resetApp];
}
   
- (void)installUncaughtExceptionHandler {
//    NSSetUncaughtExceptionHandler (&UncaughtExceptionHandler);
   // 异常的处理方法
   [UncaughtExceptionHandler installUncaughtExceptionHandler:YES showAlert:YES];
}
   
- (void)registAPPStartInit {
   [NotificationUtil registAPPStartInit:self selector:@selector(launchingInit) object:nil];
}
   
- (void)appProxy:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
   int numClasses;
   Class *classes = NULL;
   numClasses = objc_getClassList(NULL,0);
   if (numClasses >0 )
   {
       classes = (__unsafe_unretained Class *)malloc(sizeof(Class) * numClasses);
       numClasses = objc_getClassList(classes, numClasses);
       for (int i = 0; i < numClasses; i++) {
           Class subClazz = classes[i];
           if (class_getSuperclass(subClazz) == [BaseAppProxy class]){
               BaseAppProxy* appProxy = [subClazz alloc];
               [_subProxys addObject:appProxy];
               if ([appProxy respondsToSelector:@selector(application:didFinishLaunchingWithOptions:)]) {
                   [appProxy application:application didFinishLaunchingWithOptions:launchOptions];
               }
           }
       }
       free(classes);
   }
}
```
   
1. 首先，分析功能级别的启动优化：BaseAppDelegate 和 BaseInitView 类的初始化方法内部耗时忽略不计，这里更多是内存问题。其次，BaseAppDelegate 类 application:didFinishLaunchingWithOptions 方法内部 registAPPStartInit 注册通知和installUncaughtExceptionHandler 捕获崩溃耗时忽略不计。最后，该方法内部 appProxy:didFinishLaunchingWithOptions 遍历循环创建继承自 BaseAppProxy 类的所有子类，并调用 application:didFinishLaunchingWithOptions 方法。首个办法放子线程异步处理，但由于 AppDelegate 类中 getInitController 方法是公开的，获取初始化页面实例化对象可以完全自定义，如果 APP 启动后首页渲染完成前需要完成插件的初始化注册操作，就无法放子线程进行异步处理。
2. 然后，分析方法级别的启动优化：选择使用检查方法耗时的工具 SMCallTrace，对于方法内部检测耗时调用 [SMCallTrace start] 方法，结束时调用 [SMCallTrace save] 方法，控制台则会打印出方法的调用层级和耗时，打印 log 如下：

```objc
// 设置最大深度为0，打印 log
2022-12-16 17:31:44.910679+0800 YIGO移动[17156:4333629] [SMCallTrace:save]  0| 201.09|-[AppDelegate appProxy:didFinishLaunchingWithOptions:]
path[AppDelegate appProxy:didFinishLaunchingWithOptions:]
0| 311.48|-[AppDelegate resetApp]
path[AppDelegate resetApp]
0|   1.85|-[AppDelegate setProgress]
path[AppDelegate setProgress]
 
// 设置最大深度为1，打印 log
2022-12-16 17:34:37.144825+0800 YIGO移动[17165:4335324] [SMCallTrace:save]  0| 184.75|-[AppDelegate appProxy:didFinishLaunchingWithOptions:]
path[AppDelegate appProxy:didFinishLaunchingWithOptions:]
1|   4.42|  -[JPushAppDelegateProxy application:didFinishLaunchingWithOptions:]
path[AppDelegate appProxy:didFinishLaunchingWithOptions:] - [JPushAppDelegateProxy application:didFinishLaunchingWithOptions:]
1|  28.03|  -[AliyunEMASPushAppDelegateProxy application:didFinishLaunchingWithOptions:]
path[AppDelegate appProxy:didFinishLaunchingWithOptions:] - [AliyunEMASPushAppDelegateProxy application:didFinishLaunchingWithOptions:]
1|   2.44|  -[BaiduTechPushAppDelegateProxy application:didFinishLaunchingWithOptions:]
path[AppDelegate appProxy:didFinishLaunchingWithOptions:] - [BaiduTechPushAppDelegateProxy application:didFinishLaunchingWithOptions:]
1|  12.13|  -[BaiduPushAppDelegateProxy application:didFinishLaunchingWithOptions:]
path[AppDelegate appProxy:didFinishLaunchingWithOptions:] - [BaiduPushAppDelegateProxy application:didFinishLaunchingWithOptions:]
0| 310.62|-[AppDelegate resetApp]
path[AppDelegate resetApp]
1| 306.89|  +[AppInfo resetApp]
path[AppDelegate resetApp] - [AppInfo resetApp]
1|   3.39|  -[UIWindow initWithFrame:]
path[AppDelegate resetApp] - [UIWindow initWithFrame:]
1|   4.42|  -[JPushAppDelegateProxy application:didFinishLaunchingWithOptions:]
path[AppDelegate resetApp] - [JPushAppDelegateProxy application:didFinishLaunchingWithOptions:]
1|  28.03|  -[AliyunEMASPushAppDelegateProxy application:didFinishLaunchingWithOptions:]
path[AppDelegate resetApp] - [AliyunEMASPushAppDelegateProxy application:didFinishLaunchingWithOptions:]
1|   2.44|  -[BaiduTechPushAppDelegateProxy application:didFinishLaunchingWithOptions:]
path[AppDelegate resetApp] - [BaiduTechPushAppDelegateProxy application:didFinishLaunchingWithOptions:]
1|  12.13|  -[BaiduPushAppDelegateProxy application:didFinishLaunchingWithOptions:]
path[AppDelegate resetApp] - [BaiduPushAppDelegateProxy application:didFinishLaunchingWithOptions:]
0|   2.01|-[AppDelegate setProgress]
path[AppDelegate setProgress]
1|   1.41|  +[ProgressIndicator sharedSingleton]
path[AppDelegate setProgress] - [ProgressIndicator sharedSingleton]
1| 306.89|  +[AppInfo resetApp]
path[AppDelegate setProgress] - [AppInfo resetApp]
1|   3.39|  -[UIWindow initWithFrame:]
path[AppDelegate setProgress] - [UIWindow initWithFrame:]
1|   4.42|  -[JPushAppDelegateProxy application:didFinishLaunchingWithOptions:]
path[AppDelegate setProgress] - [JPushAppDelegateProxy application:didFinishLaunchingWithOptions:]
1|  28.03|  -[AliyunEMASPushAppDelegateProxy application:didFinishLaunchingWithOptions:]
path[AppDelegate setProgress] - [AliyunEMASPushAppDelegateProxy application:didFinishLaunchingWithOptions:]
1|   2.44|  -[BaiduTechPushAppDelegateProxy application:didFinishLaunchingWithOptions:]
path[AppDelegate setProgress] - [BaiduTechPushAppDelegateProxy application:didFinishLaunchingWithOptions:]
1|  12.13|  -[BaiduPushAppDelegateProxy application:didFinishLaunchingWithOptions:]
path[AppDelegate setProgress] - [BaiduPushAppDelegateProxy application:didFinishLaunchingWithOptions:]
 
// 设置最小耗时检测为100ms，打印 log
2022-12-16 17:36:47.756365+0800 YIGO移动[17170:4336912] [SMCallTrace:save]  0| 198.07|-[AppDelegate appProxy:didFinishLaunchingWithOptions:]
path[AppDelegate appProxy:didFinishLaunchingWithOptions:]
0| 307.88|-[AppDelegate resetApp]
path[AppDelegate resetApp]
1| 304.08|  +[AppInfo resetApp]
path[AppDelegate resetApp] - [AppInfo resetApp]
2| 204.40|    -[AppDelegate getInitController]
path[AppDelegate resetApp] - [AppInfo resetApp] - [AppDelegate getInitController]
3| 204.39|      -[BaseInitView init]
path[AppDelegate resetApp] - [AppInfo resetApp] - [AppDelegate getInitController] - [BaseInitView init]
 
// 设置最大深度为0，最小耗时检测为100ms，打印 log
2022-12-16 17:38:41.100242+0800 YIGO移动[17174:4338186] [SMCallTrace:save]  0| 153.50|-[AppDelegate appProxy:didFinishLaunchingWithOptions:]
path[AppDelegate appProxy:didFinishLaunchingWithOptions:]
0| 315.75|-[AppDelegate resetApp]
path[AppDelegate resetApp]
```

3. 由上可知，appProxy:didFinishLaunchingWithOptions 和 resetApp 方法比较耗时，resetApp 方法内部是 UI 操作，放在主线程。所以考虑优化 appProxy:didFinishLaunchingWithOptions 这部分代码。想到的办法是，考虑空间换时间，APP 第一次启动后把 _subProxys 存在内存中，后面直接从缓存取，从而避免每次需要循环创建添加这部分耗时操作。不过，把 _subProxys 存在内存，存取这部分 io 操作也是耗时的，如果继承自 BaseAppProxy 类的插件足够多，优化空间比较明显，否则不建议进行优化。

## 解决办法

想到的办法是，考虑空间换时间，APP 第一次启动后把 _subProxys 存在内存中，后面直接从缓存取，从而避免每次需要循环创建添加这部分耗时操作。代码如下：

- 第一种情况，没有存，且除去 respondsToSelector 方法的情况，可以看出耗时 115.18 ms

```objc
// 源代码
- (void)appProxy:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
int numClasses;
Class *classes = NULL;
numClasses = objc_getClassList(NULL,0);
if (numClasses >0 )
{
    classes = (__unsafe_unretained Class *)malloc(sizeof(Class) * numClasses);
    numClasses = objc_getClassList(classes, numClasses);
    for (int i = 0; i < numClasses; i++) {
        Class subClazz = classes[i];
        if (class_getSuperclass(subClazz) == [BaseAppProxy class]){
            BaseAppProxy* appProxy = [subClazz alloc];
            [_subProxys addObject:appProxy];
//                if ([appProxy respondsToSelector:@selector(application:didFinishLaunchingWithOptions:)]) {
//                    [appProxy application:application didFinishLaunchingWithOptions:launchOptions];
//                }
        }
    }
    free(classes);
}
}

// 设置最大深度为1，打印 log
2023-01-03 18:06:54.954397+0800 YIGO移动[24861:6752534] [SMCallTrace:save]  0| 115.18|-[AppDelegate appProxy:didFinishLaunchingWithOptions:]
path[AppDelegate appProxy:didFinishLaunchingWithOptions:]
```

- 第二种情况，没有存，且存在 respondsToSelector 方法的情况，可以看出耗时 189.03 ms

```objc
// 源代码
- (void)appProxy:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
int numClasses;
Class *classes = NULL;
numClasses = objc_getClassList(NULL,0);
if (numClasses >0 )
{
    classes = (__unsafe_unretained Class *)malloc(sizeof(Class) * numClasses);
    numClasses = objc_getClassList(classes, numClasses);
    for (int i = 0; i < numClasses; i++) {
        Class subClazz = classes[i];
        if (class_getSuperclass(subClazz) == [BaseAppProxy class]){
            BaseAppProxy* appProxy = [subClazz alloc];
            [_subProxys addObject:appProxy];
            if ([appProxy respondsToSelector:@selector(application:didFinishLaunchingWithOptions:)]) {
                [appProxy application:application didFinishLaunchingWithOptions:launchOptions];
            }
        }
    }
    free(classes);
}
}

// 设置最大深度为1，打印 log
2023-01-03 17:59:53.749436+0800 YIGO移动[24834:6746470] [SMCallTrace:save]  0| 189.03|-[AppDelegate appProxy:didFinishLaunchingWithOptions:]
path[AppDelegate appProxy:didFinishLaunchingWithOptions:]
1|   3.63|  -[JPushAppDelegateProxy application:didFinishLaunchingWithOptions:]
path[AppDelegate appProxy:didFinishLaunchingWithOptions:] - [JPushAppDelegateProxy application:didFinishLaunchingWithOptions:]
1|  25.65|  -[AliyunEMASPushAppDelegateProxy application:didFinishLaunchingWithOptions:]
path[AppDelegate appProxy:didFinishLaunchingWithOptions:] - [AliyunEMASPushAppDelegateProxy application:didFinishLaunchingWithOptions:]
1|   2.46|  -[BaiduTechPushAppDelegateProxy application:didFinishLaunchingWithOptions:]
path[AppDelegate appProxy:didFinishLaunchingWithOptions:] - [BaiduTechPushAppDelegateProxy application:didFinishLaunchingWithOptions:]
1|  12.54|  -[BaiduPushAppDelegateProxy application:didFinishLaunchingWithOptions:]
path[AppDelegate appProxy:didFinishLaunchingWithOptions:] - [BaiduPushAppDelegateProxy application:didFinishLaunchingWithOptions:]
```

- 第三种情况，有存，且存在 respondsToSelector 方法的情况，可以看出耗时 44.56 ms

```objc
// 源代码
- (void)appProxy:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
NSData *arrayData = [userDefaults  objectForKey:@"arrayKey"];
_subProxys = [NSKeyedUnarchiver unarchiveObjectWithData:arrayData];

if (_subProxys.count > 0) {
    for (BaseAppProxy* appProxy in _subProxys) {
        if ([appProxy respondsToSelector:@selector(application:didFinishLaunchingWithOptions:)]) {
            [appProxy application:application didFinishLaunchingWithOptions:launchOptions];
        }
    }
} else {
    int numClasses;
    Class *classes = NULL;
    numClasses = objc_getClassList(NULL,0);
    if (numClasses >0 )
    {
        classes = (__unsafe_unretained Class *)malloc(sizeof(Class) * numClasses);
        numClasses = objc_getClassList(classes, numClasses);
        for (int i = 0; i < numClasses; i++) {
            Class subClazz = classes[i];
            if (class_getSuperclass(subClazz) == [BaseAppProxy class]){
                BaseAppProxy* appProxy = [subClazz alloc];
                [_subProxys addObject:appProxy];
                if ([appProxy respondsToSelector:@selector(application:didFinishLaunchingWithOptions:)]) {
                    [appProxy application:application didFinishLaunchingWithOptions:launchOptions];
                }
            }
        }
        arrayData = [NSKeyedArchiver archivedDataWithRootObject:_subProxys];
        [userDefaults setObject:arrayData forKey:@"arrayKey"];
        [userDefaults synchronize];
        free(classes);
    }
}
}

// 设置最大深度为1，打印 log
2023-01-03 18:04:01.181361+0800 YIGO移动[24853:6750638] [SMCallTrace:save]  0|  44.56|-[AppDelegate appProxy:didFinishLaunchingWithOptions:]
path[AppDelegate appProxy:didFinishLaunchingWithOptions:]
1|   3.83|  -[JPushAppDelegateProxy application:didFinishLaunchingWithOptions:]
path[AppDelegate appProxy:didFinishLaunchingWithOptions:] - [JPushAppDelegateProxy application:didFinishLaunchingWithOptions:]
1|  24.13|  -[AliyunEMASPushAppDelegateProxy application:didFinishLaunchingWithOptions:]
path[AppDelegate appProxy:didFinishLaunchingWithOptions:] - [AliyunEMASPushAppDelegateProxy application:didFinishLaunchingWithOptions:]
1|   2.17|  -[BaiduTechPushAppDelegateProxy application:didFinishLaunchingWithOptions:]
path[AppDelegate appProxy:didFinishLaunchingWithOptions:] - [BaiduTechPushAppDelegateProxy application:didFinishLaunchingWithOptions:]
1|  11.69|  -[BaiduPushAppDelegateProxy application:didFinishLaunchingWithOptions:]
path[AppDelegate appProxy:didFinishLaunchingWithOptions:] - [BaiduPushAppDelegateProxy application:didFinishLaunchingWithOptions:]
1|   2.41|  +[NSKeyedUnarchiver unarchiveObjectWithData:]
path[AppDelegate appProxy:didFinishLaunchingWithOptions:] - [NSKeyedUnarchiver unarchiveObjectWithData:]
```

对比可以看出，把 _subProxys 存在内存中，后面直接从缓存取，耗时从 189.03 ms 减少到 44.56 ms，优化还是十分明显的。