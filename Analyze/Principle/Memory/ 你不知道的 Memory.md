## iOS程序的内存布局

1. 代码段：编译之后的代码
2. 数据段
    - 字符串常量：比如NSString *str = @"123"
    - 已初始化数据：已初始化的全局变量、静态变量等
    - 未初始化数据：未初始化的全局变量、静态变量等
3. 栈：函数调用开销，比如局部变量。分配的内存空间地址越来越小
4. 堆：通过alloc、malloc、calloc等动态分配的空间，分配的内存空间地址越来越大

## Tagged Pointer

1. 从64bit开始，iOS引入了Tagged Pointer技术，用于优化NSNumber、NSDate、NSString等小对象的存储
2. 在没有使用Tagged Pointer之前， NSNumber等对象需要动态分配内存、维护引用计数等，NSNumber指针存储的是堆中NSNumber对象的地址值
3. 使用Tagged Pointer之后，NSNumber指针里面存储的数据变成了：Tag + Data，也就是将数据直接存储在了指针中
4. 当指针不够存储数据时，才会使用动态分配内存的方式来存储数据
5. objc_msgSend能识别Tagged Pointer，比如NSNumber的intValue方法，直接从指针提取数据，节省了以前的调用开销

## 如何判断一个指针是否为Tagged Pointer？

1. iOS平台，最高有效位是1（第64bit）
2. Mac平台，最低有效位是1

## OC对象的内存管理

1. 在iOS中，使用引用计数来管理OC对象的内存
2. 一个新创建的OC对象引用计数默认是1，当引用计数减为0，OC对象就会销毁，释放其占用的内存空间
3. 调用retain会让OC对象的引用计数+1，调用release会让OC对象的引用计数-1
4. 内存管理的经验总结
    - 当调用alloc、new、copy、mutableCopy方法返回了一个对象，在不需要这个对象时，要调用release或者autorelease来释放它
    - 想拥有某个对象，就让它的引用计数+1；不想再拥有某个对象，就让它的引用计数-1
5. 可以通过以下私有函数来查看自动释放池的情况

```objective-c
extern void _objc_autoreleasePoolPrint(void);
```

## copy和mutableCopy

1. NSString copy -> NSString => 浅拷贝
2. NSMutableString copy -> NSString => 深拷贝
3. NSArray copy -> NSArray => 浅拷贝
4. NSMutableArray copy -> NSArray => 深拷贝
5. NSDictionary copy -> NSDictionary => 浅拷贝
6. NSMutableDictionary copy -> NSDictionary => 深拷贝

1. NSString mutableCopy -> NSMutableString => 深拷贝
2. NSMutableString mutableCopy -> NSMutableString => 深拷贝
3. NSArray mutableCopy -> NSMutableArray => 深拷贝
4. NSMutableArray mutableCopy -> NSMutableArray => 深拷贝
5. NSDictionary mutableCopy -> NSMutableDictionary => 深拷贝
6. NSMutableDictionary mutableCopy -> NSMutableDictionary => 深拷贝

## 深拷贝、浅拷贝区别

1. 浅拷贝只是对指针的拷贝，拷贝后两个指针指向同一个内存空间，深拷贝不但对指针进行拷贝，而且对指针指向的内容进行拷贝，经深拷贝后的指针是指向两个不同地址的指针。
2. 当对象中存在指针成员时，除了在复制对象时需要考虑自定义拷贝构造函数，还应该考虑以下两种情形：
3. 函数的参数为对象时，实参传递给形参的实际上是实参的一个拷贝对象，系统自动通过拷贝构造函数实现；
4. 当函数的返回值为一个对象时，该对象实际上是函数内对象的一个拷贝，用于返回函数调用处。
5. copy方法:如果是非可扩展类对象，则是浅拷贝。如果是可扩展类对象，则是深拷贝。
6. mutableCopy方法:无论是可扩展类对象还是不可扩展类对象，都是深拷贝。

## 引用计数的存储

1. 在64bit中，引用计数可以直接存储在优化过的isa指针中，也可能存储在SideTable类中
2. refcnts是一个存放着对象引用计数的散列表

## dealloc

1. 当一个对象要释放时，会自动调用dealloc，接下的调用轨迹是

```objective-c
dealloc
_objc_rootDealloc
rootDealloc
object_dispose
objc_destructInstance、free
```
2. objc_destructInstance 内部清除成员变量、移除关联对象、将指向当前对象的弱指针置为nil

## 自动释放池

1. 自动释放池的主要底层数据结构是：__AtAutoreleasePool、AutoreleasePoolPage
2. 调用了autorelease的对象最终都是通过AutoreleasePoolPage对象来管理的
3. 源码分析
    clang重写@autoreleasepool
    objc4源码：NSObject.mm
4. 每个AutoreleasePoolPage对象占用4096字节内存，除了用来存放它内部的成员变量，剩下的空间用来存放autorelease对象的地址
5. 所有的AutoreleasePoolPage对象通过双向链表的形式连接在一起
6. 调用push方法会将一个POOL_BOUNDARY入栈，并且返回其存放的内存地址
7. 调用pop方法时传入一个POOL_BOUNDARY的内存地址，会从最后一个入栈的对象开始发送release消息，直到遇到这个POOL_BOUNDARY
8. id *next指向了下一个能存放autorelease对象地址的区域 

## Runloop和Autorelease

1. iOS在主线程的Runloop中注册了2个Observer
2. 第1个Observer监听了kCFRunLoopEntry事件，会调用objc_autoreleasePoolPush()
3. 第2个Observer
4. 监听了kCFRunLoopBeforeWaiting事件，会调用objc_autoreleasePoolPop()、objc_autoreleasePoolPush()
5. 监听了kCFRunLoopBeforeExit事件，会调用objc_autoreleasePoolPop()

## 使用CADisplayLink、NSTimer有什么注意点？

1. CADisplayLink、NSTimer会对target产生强引用，如果target又对它们产生强引用，那么就会引发循环引用
2. 解决方案
    1. 使用block
    2. 使用代理对象（NSProxy）

## 代理对象（NSProxy）机制原理

1. weak 关键字修饰 target 属性
2. runtime进行消息转发，转发给self的selctor方法

## ARC 都帮我们做了什么？

- LLVM + Runtime

## weak指针的实现原理

1. weak 表示指向但不拥有该对象。其修饰的对象引用计数不会增加。无需手动设置，该对象会自行在内存中销毁。
2. weak 一般用来修饰对象，assign 一般用来修饰基本数据类型。原因是 assign 修饰的对象被释放后，指针的地址依然存在，造成野指针，在堆上容易造成崩溃。而栈上的内存系统会自动处理，不会造成野指针。
3. 什么情况使用 weak 关键字？
    - 在 ARC 中,在有可能出现循环引用的时候,往往要通过让其中一端使用 weak 来解决,比如: delegate 代理属性
    - 自身已经对它进行一次强引用,没有必要再强引用一次,此时也会使用 weak,自定义 IBOutlet 控件属性一般也使用 weak；当然，也可以使用strong。
4. 不同点：
    - weak 此特质表明该属性定义了一种“非拥有关系” (nonowning relationship)。为这种属性设置新值时，设置方法既不保留新值，也不释放旧值。此特质同assign类似， 然而在属性所指的对象遭到摧毁时，属性值也会清空(nil out)。 而 assign 的- “设置方法”只会执行针对“纯量类型” (scalar type，例如 CGFloat 或 NSlnteger 等)的简单赋值操作。
    - assign 可以用非 OC 对象,而 weak 必须用于 OC 对象
5. 实现原理：弱引用表，hashtable管理，todo？
6. 弱引用表也是一张哈希表的结构，其内部包含了每个对象对应的弱引用表 weak_entry_t，而 weak_entry_t 是一个结构体数组，其中包含的则是每一个对象弱引用的对象所对应的弱引用指针。

## autorelease对象在什么时机会被调用release

1. 用了autorelease的对象最终都是通过AutoreleasePoolPage对象来管理的
2. AutoreleasePoolPage对象，调用pop方法时传入一个POOL_BOUNDARY的内存地址，会从最后一个入栈的对象开始发送release消息，直到遇到这个POOL_BOUNDARY

## 方法里有局部对象， 出了方法后会立即释放吗

1. 分情况
2. 如果方法被 AutoreleasePool 管理着，那么出了方法后会调用 autorelease 方法，加入 AutoreleasePool，延迟释放
3. 如果方法没被 AutoreleasePool 管理着，那么出了方法后，局部对象不在被指针引用，会调用 release 方法，这时引用计数减至0，立即释放内存

## autorelease 和 release 方法区别

1. autorelease 和 release 是 Objective-C 中用于管理对象的内存的两个重要方法。它们的主要区别在于它们的行为以及何时被调用。
2. autorelease 方法
    - autorelease 方法将对象添加到对象队列中，以便在应用程序释放对象时自动释放它们。
    - autorelease 方法不会在对象队列中等待释放，而是立即返回。
    - autorelease 方法通常在创建对象后将其添加到对象队列中，以便在将来释放。
    - autorelease 方法可用于延迟对象释放，例如在循环中创建一个对象并在循环结束后释放它们。
3. release 方法
    - release 方法将对象从对象队列中移除，并释放对象的内存。
    - release 方法在对象队列中没有对象时立即被调用。
    - release 方法不能用于延迟对象释放，因为它们在对象队列中没有对象时立即被调用。
    - release 方法是释放对象的唯一方法，因此如果您需要释放对象，请使用 release 方法。
4. 在 Objective-C 中，autorelease 和 release 方法都是用于管理对象的内存的常用方法。autorelease 方法将对象添加到对象队列中，以便在应用程序释放对象时自动释放它们，而 release 方法将对象从对象队列中移除并释放它们的内存。

## arc机制什么场景分别调用 autorelease 和 release

1. 字面量创建的直接存储在常量区
2. alloc出来的存储在堆区并且作用域结束前直接插入release（符合NSTagged Pointer的会直接分配在常量区，类型是NSTaggedPointer_接类型名，标识指针和对象存储在一起）
3. 通过stringWithFormat工厂方法创建的对象则在其后插入autorelease，这是因为工厂方法里面通过alloc分配堆内存，到返回出来以后其作用域已经结束，所以只能延迟释放了，否则没有办法返回非空对象（符合NSTagged Pointer的会直接分配在常量区，类型是NSTaggedPointer_接类型名，标识指针和对象存储在一起）

## 小结

1. arc机制
2. autorelease 和 release
3. copy、strong 等关键字
4. copy和mutableCopy方法
5. autoreleasePool
6. 引用计数

## 内存方向的性能优化

### 内存如何优化？

### 如何检查内存问题，分别两种，一种是内存泄漏，一种是内存溢出

### 如何使用 instrument 检查内存

### 如何线下和线上两个方向监控内存