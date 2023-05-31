## Thread概念

## Thread常见方案

1. pthread
2. NSThread
3. GCD
4. NSOperation

## 方案

1. pthread：一套通用的多线程API，适用于Unix\Linux\Windows等系统，跨平台\可移植，使用难度大。
2. NSThread：使用更加面向对象，简单易用，可直接操作线程对象。
3. GCD：旨在替代NSThread等线程技术，充分利用设备的多核。
4. NSOperation：基于GCD（底层是GCD），比GCD多了一些更简单实用的功能，使用更加面向对象。

## GCD 中的同步、异步、并发、串行

1. 同步和异步主要影响：能不能开启新的线程
    - 同步：在当前线程中执行任务，不具备开启新线程的能力
    - 异步：在新的线程中执行任务，具备开启新线程的能力
2. 并发和串行主要影响：任务的执行方式
    - 并发：多个任务并发（同时）执行
    - 串行：一个任务执行完毕后，再执行下一个任务
3. 同步和异步，是指GCD中有2个用来执行任务的函数：dispatch_sync 和 dispatch_async，分别用同步的方式执行任务，用异步的方式执行任务
4. 并发和串行，是指GCD的队列可以分为这2大类型：
    - 并发队列（Concurrent Dispatch Queue）
        - 可以让多个任务并发（同时）执行（自动开启多个线程同时执行任务）
        - 并发功能只有在异步（dispatch_async）函数下才有效
    - 串行队列（Serial Dispatch Queue）
        - 让任务一个接着一个地执行（一个任务执行完毕后，再执行下一个任务）

## GCD 中各种队列的执行效果

1. 同步（sync）+ 并发队列：没有开启新线程，串行执行任务
2. 同步（sync）+ 手动创建的串行队列：没有开启新线程，串行执行任务
3. 同步（sync）+ 主队列：没有开启新线程，串行执行任务
4. 异步（async）+ 并发队列：开启新线程，并发执行任务
5. 异步（async）+ 手动创建的串行队列：开启新线程，串行执行任务
6. 异步（async）+ 主队列：没有开启新线程，串行执行任务
7. 使用sync函数往当前串行队列中添加任务，会卡住当前的串行队列（产生死锁）

## gcd 队列组

1. 如何用gcd实现以下功能：
2. 异步并发执行任务1、任务2，等任务1、任务2都执行完毕后，再回到主线程执行任务3

## 多线程的安全隐患

1. 资源共享，1块资源可能会被多个线程共享，也就是多个线程可能会访问同一块资源，比如多个线程访问同一个对象、同一个变量、同一个文件
2. 当多个线程访问同一块资源时，很容易引发数据错乱和数据安全问题
3. 解决方案：使用线程同步技术（同步，就是协同步调，按预定的先后次序进行），常见的线程同步技术是：加锁

## iOS中的线程同步方案

1. OSSpinLock：自旋锁
2. os_unfair_lock：休眠锁
3. pthread_mutex：休眠锁，分普通、互斥、递归、条件四种类型
4. dispatch_semaphore：信号量
5. dispatch_queue(DISPATCH_QUEUE_SERIAL)：直接使用GCD的串行队列，也是可以实现线程同步的
6. NSLock：对mutex普通锁的封装
7. NSRecursiveLock：对mutex递归锁的封装
8. NSCondition：对mutex和cond的封装
9. NSConditionLock：对NSCondition的进一步封装，可以设置具体的条件值
10. @synchronized：对mutex递归锁的封装

## dispatch_semaphore

1. semaphore叫做”信号量”
2. 信号量的初始值，可以用来控制线程并发访问的最大数量
3. 信号量的初始值为1，代表同时只允许1条线程访问资源，保证线程同步
4. 使用场景：
    - 使用场景一：初值设置为 0，多线程同步（网络请求）
    - 用场景二：初值设置为 1, 实现锁的功能（网络请求、连接socket）
    - 使用场景三：初值设置为其他正整数，设置资源池的数量（下载配置文件）

## @synchronized

1. @synchronized是对mutex递归锁的封装
2. 源码查看：objc4中的objc-sync.mm文件
3. @synchronized(obj)内部会生成obj对应的递归锁，然后进行加锁、解锁操作
4. 使用场景：写入文件数据


## 线上线程死锁如何监控

- 字节跳动 iOS Heimdallr 卡死卡顿监控方案与优化之路：https://www.cnblogs.com/ClientInfra/p/15845988.html

## 遇到的问题

1. 公式执行和事件队列优化，解决多个线程访问同一块资源引发的安全隐患
2. 公式、事件之前在主线程串行执行，会卡住主线程
3. 使用 NSOperation 和 NSOperationPool 异步执行，最大并发数设置为 10
4. 公式和事件任务中存在多个线程访问同一块资源，使用 dispatch_semaphore：信号量 和 @synchronized：对mutex递归锁的封装 进行加锁

## 自旋锁、互斥锁比较

1. 什么情况使用自旋锁比较划算？
    预计线程等待锁的时间很短
    加锁的代码（临界区）经常被调用，但竞争情况很少发生
    CPU资源不紧张
    多核处理器
2. 什么情况使用互斥锁比较划算？
    预计线程等待锁的时间较长
    单核处理器
    临界区有IO操作
    临界区代码复杂或者循环量大
    临界区竞争非常激烈
3. 自旋锁、互斥锁没什么好比较的，目前苹果一般使用休眠锁代替自旋锁，自旋锁存在安全问题

## 自旋锁、互斥锁使用场景

1. 自旋锁：
    1. RunLoop 中，两个自动获取的函数 CFRunLoopGetMain() 和 CFRunLoopGetCurrent()。 这两个函数内部使用 loopsLock 作为访问 loopsDic 时的锁
    2. 引用计数的存储，在64bit中，引用计数可以直接存储在优化过的isa指针中，也可能存储在SideTable类中，refcnts是一个存放着对象引用计数的散列表，而SideTable中有一个spinlock_t slock 自旋锁
2. 互斥锁：todo！

## atomic

1. atomic用于保证属性setter、getter的原子性操作，相当于在getter和setter内部加了线程同步的锁
2. 可以参考源码objc4的objc-accessors.mm
3. 它并不能保证使用属性的过程是线程安全的，如果存在多个线程访问这个属性，将会引发数据错乱和数据安全问题

## iOS中的读写安全方案

1. 如何实现以下场景
2. 同一时间，只能有1个线程进行写的操作
3. 同一时间，允许有多个线程进行读的操作
4. 同一时间，不允许既有写的操作，又有读的操作
5. 上面的场景就是典型的“多读单写”，经常用于文件等数据的读写操作，iOS中的实现方案有
6. pthread_rwlock：读写锁，等待锁的线程会进入休眠
7. dispatch_barrier_async：异步栅栏调用
8. 项目没有使用场景

## dispatch_barrier_async

1. 这个函数传入的并发队列必须是自己通过dispatch_queue_cretate创建的
2. 如果传入的是一个串行或是一个全局的并发队列，那这个函数便等同于dispatch_async函数的效果

## OSSpinLock 自旋锁

1. 具体来说，如果一个低优先级的线程获得锁并访问共享资源，这时一个高优先级的线程也尝试获得这个锁，它会处于 spin lock 的忙等状态从而占用大量 CPU。此时低优先级线程无法与高优先级线程争夺 CPU 时间，从而导致任务迟迟完不成、无法释放 lock。
2. 最终的结论就是，除非开发者能保证访问锁的线程全部都处于同一优先级，否则 iOS 系统中所有类型的自旋锁都不能再使用了。
3. 看到除了 OSSpinLock 外，dispatch_semaphore 和 pthread_mutex 性能是最高的。
4. 不再安全的 OSSpinLock：https://blog.ibireme.com/2016/01/16/spinlock_is_unsafe_in_ios/