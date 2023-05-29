## 框架的组成

- 网络通信模块（AFURLSessionManager、AFHTTPSessionManager）
- 网络状态监听模块（AFNetworkReachabilityManager）
- 网络通信安全策略模块（AFSecurityPolicy）
- 网络通信信息序列化/反序列化模块（AFURLRequestSerialization、AFURLResponseSerialization）
- 对于iOS UIKit库的扩展（UIKit+AFNetworking）

## 结构关系

![结构关系1](media/16421314259247/%E7%BB%93%E6%9E%84%E5%85%B3%E7%B3%BB.png)

在开发中，我们一般使用 AFHTTPSessionManager 类做网络请求（提供常用 API），AFURLSessionManager 作为其父类，真正负责请求逻辑的实现（核心模块）。我们阅读源代码可知，AFURLSessionManager 对 NSURLSession 进行了一层封装，最终调用的 iOS 系统底层 Foundation 库中的 NSURLSession 类。

```
@interface AFURLSessionManager : NSObject <NSURLSessionDelegate, NSURLSessionTaskDelegate, NSURLSessionDataDelegate, NSURLSessionDownloadDelegate, NSSecureCoding, NSCopying>

/**
 The managed session.
 */
@property (readonly, nonatomic, strong) NSURLSession *session;
```

其余 Reachability、Security、Serialization 三个模块在 AFURLSessionManager 中配合 NSURLSession 实现网络通信。UIKit+AFNetworking 独立于 AFURLSessionManager，对iOS UIKit库进行扩展。

![结构关系2](media/16421314259247/%E7%BB%93%E6%9E%84%E5%85%B3%E7%B3%BB2.png)

## 示例分析

### 初始化方法

```
@implementation AFAppDotNetAPIClient

+ (instancetype)sharedClient {
    static AFAppDotNetAPIClient *_sharedClient = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedClient = [[AFAppDotNetAPIClient alloc] initWithBaseURL:[NSURL URLWithString:AFAppDotNetAPIBaseURLString]];
        _sharedClient.securityPolicy = [AFSecurityPolicy policyWithPinningMode:AFSSLPinningModeNone];
    });
    
    return _sharedClient;
}

@end
```

由上面示例代码，AFAppDotNetAPIClient调用父类AFHTTPSessionManager中-initWithBaseURL:初始化方法生成一个实例对象，继续跟进去可以看到：

```
- (instancetype)initWithBaseURL:(NSURL *)url {
    return [self initWithBaseURL:url sessionConfiguration:nil];
}

- (instancetype)initWithSessionConfiguration:(NSURLSessionConfiguration *)configuration {
    return [self initWithBaseURL:nil sessionConfiguration:configuration];
}

- (instancetype)initWithBaseURL:(NSURL *)url
           sessionConfiguration:(NSURLSessionConfiguration *)configuration
{
    // 初始化方法调用父类AFURLSessionManager的初始化方法-initWithSessionConfiguration:
    self = [super initWithSessionConfiguration:configuration];
    if (!self) {
        return nil;
    }

    // Ensure terminal slash for baseURL path, so that NSURL +URLWithString:relativeToURL: works as expected
    // 确保传入参数baseURL路径是以斜杠`/`结尾，以便NSURL类中+URLWithString:relativeToURL:方法能够按预期工作
    // 如果baseURL有值且后缀不包含`/`，那么url拼接上`/`
    if ([[url path] length] > 0 && ![[url absoluteString] hasSuffix:@"/"]) {
        url = [url URLByAppendingPathComponent:@""];
    }

    // 把baseURL存了起来
    self.baseURL = url;

    // 初始化一个请求序列对象
    self.requestSerializer = [AFHTTPRequestSerializer serializer];
    // 初始化一个响应序列对象
    self.responseSerializer = [AFJSONResponseSerializer serializer];

    return self;
}
```

我们可以看到， 初始化方法调用父类AFURLSessionManager的初始化方法-initWithSessionConfiguration:，继续跟进去，来到父类AFURLSessionManager的初始化方法：

```
- (instancetype)init {
    return [self initWithSessionConfiguration:nil];
}

// 父类AFURLSessionManager的初始化方法
- (instancetype)initWithSessionConfiguration:(NSURLSessionConfiguration *)configuration {
    self = [super init];
    if (!self) {
        return nil;
    }

    if (!configuration) {
        configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    }

    self.sessionConfiguration = configuration;

    self.operationQueue = [[NSOperationQueue alloc] init];
    // maxConcurrentOperationCount不是控制线程最大数，而是控制队列中同一时间片能执行多少个类型的任务操作
    // 设置的是queue里面最多能并发运行的operation个数，而不是线程个数，因为一个operation并非只能运行一个线程
    // operationQueue是代理回调的Queue
    self.operationQueue.maxConcurrentOperationCount = 1;

    // 初始化一个响应序列化（转码）
    self.responseSerializer = [AFJSONResponseSerializer serializer];

    // 初始化默认的安全策略
    self.securityPolicy = [AFSecurityPolicy defaultPolicy];

#if !TARGET_OS_WATCH
    self.reachabilityManager = [AFNetworkReachabilityManager sharedManager];
#endif

    // 初始化可变字典，用于存放NSURLSessionTask和AFURLSessionManagerTaskDelegate
    // MARK: - 每个NSURLSessionTask匹配一个AFURLSessionManagerTaskDelegate，用于Task的Delegate事件处理
    // mutableTaskDelegatesKeyedByTaskIdentifier用来让每个请求task和自定义的AFURLSessionManagerTaskDelegate委托建立映射
    // MARK: - 对task的委托进行一个封装，并且转发委托到自定义的AFURLSessionManagerTaskDelegate委托
    self.mutableTaskDelegatesKeyedByTaskIdentifier = [[NSMutableDictionary alloc] init];

    // 初始化锁，用于确保mutableTaskDelegatesKeyedByTaskIdentifier字典在多线程中读写操作的安全
    self.lock = [[NSLock alloc] init];
    self.lock.name = AFURLSessionManagerLockName;

    // 置空task关联的delegate
    // NSURLSession类中-getTasksWithCompletionHandler:方法，用来异步获取当前session所有未完成的tasks
    // 作用：这是为了防止后台回来，重新初始化这个session，一些之前的后台请求任务，导致程序的crash
    [self.session getTasksWithCompletionHandler:^(NSArray *dataTasks, NSArray *uploadTasks, NSArray *downloadTasks) {
        for (NSURLSessionDataTask *task in dataTasks) {
            [self addDelegateForDataTask:task uploadProgress:nil downloadProgress:nil completionHandler:nil];
        }

        for (NSURLSessionUploadTask *uploadTask in uploadTasks) {
            [self addDelegateForUploadTask:uploadTask progress:nil completionHandler:nil];
        }

        for (NSURLSessionDownloadTask *downloadTask in downloadTasks) {
            [self addDelegateForDownloadTask:downloadTask progress:nil destination:nil completionHandler:nil];
        }
    }];

    return self;
}
```

对于初始化方法，我们需要注意一下几点：

1. `self.operationQueue.maxConcurrentOperationCount`，对于operationQueue 和 maxConcurrentOperationCount 的理解？
2. `self.mutableTaskDelegatesKeyedByTaskIdentifier`，如何建立映射关系，如何对task委托进行封装，并且转发到自定义的委托对象中去？
3. `[self.session getTasksWithCompletionHandler:^(NSArray *dataTasks, NSArray *uploadTasks, NSArray *downloadTasks) {`，这段代码的作用是什么？
### 网络请求
