# 性能优化-内存泄露

## 内存泄露

内存泄漏：Memory Leak，是指程序在申请内存后，无法释放已申请的内存空间，一次内存泄漏似乎不会有大的影响，但内存泄漏堆积后的后果就是内存溢出。

## 常见内存泄露的场景

1. 循环引用
	- 对象间强引用（2个或以上对象互相强引用，对象属性strong关键字修饰）
	- block（block 强引用捕获外部变量）
	- timer、displaylink与 target（NSTimer 在释放前未调用 [timer invalidate]，对target强引用；timer 使用后没有停止和销毁）
	- delegate（delegate 变量没声明为 weak 类型）
2. 线程死锁
3. 非oc对象内存处理（提供了release函数的C语言接口）
	- calloc 后没有free（malloc后需要手动 free）
	- cgimage后需要 cgimagerelease（cgimage 绘制出来，在绘制完成后需要手动进行释放 cgimagerelease）
4. notification使用后没有remove（NSNotification 没有移除通知）
5. 地图应用内存泄漏，比如百度地图
	- 在使⽤完毕时地图、代理等没有滞空为nil；
	- 地图中标注（⼤头针）没有复⽤，并且在使⽤完毕时没有清空标注数组
6. 短时间创建大量对象造成内存暴涨，没有使用自动释放池
7. WKWebView 的 addScriptMessageHandler 操作
8. kvo，add之后没有进行remove

注意：6、7、8场景有待验证。

## 内存泄露监控手段

### 线下监控手段

1. Xcode-Runtime issues：Runtime issues 有三类：线程问题，UI 布局和渲染问题，以及内存问题。内存问题最常见的就是内存泄漏，比如循环引用就是一个经典的错误。
2. Xcode-Memory Debug Graph：点击调试工具栏中的按钮，Xcode 会自动检测内存相关的 memory runtime issue。点击相关问题处 Xcode 就会给出详细的循环引用示意图。
3. Instruments-Leak：一个专门检测内存泄漏的工具。进入页面后发现 Leak Checks 中出现内存泄漏时，我们可以将导航栏切换到 call tree 模式下，强烈建议在 Display Settings 中勾选 Separate by Thread 和 Hide System Libraries 两个选项，这样可以隐藏掉系统和应用本身的调用路径，帮助我们更方便的找出 retain cycle 位置。
4. Xcode-Analyzer（静态分析）：静态分析工具
5. MLeaksFinder (第三方工具)：提供了内存泄露检测更好的解决方案

注意：1-3是内存泄露，主要是循环引用。

### 线上监控手段

注意：内存泄露如何定位判断时机，有待验证。一般来说，内存泄露主要使用线下监控手段，而内存泄露堆积后导致内存溢出，发生内存溢出崩溃，这种场景需要结合线上监控手段+内存问题信息收集。

## 内存泄露线下监控工具

### Instruments-Leak（动态检测）

1. 通过Xcode打开项目，然后点击Product->Profile
2. 按上面操作，build成功后跳出Instruments工具，如上图右侧图所示。选择Leaks选项，点击右下角的【choose】按钮
3. 这时候项目程序也在模拟器或手机上运行起来了，在手机或模拟器上对程序进行操作
4. 点击左上角的红色圆点，这时项目开始启动了，由于Leaks是动态监测，所以手动进行一系列操作，可检查项目中是否存在内存泄漏问题。如图所示，橙色矩形框中所示绿色为正常，如果出现如右侧红色矩形框中显示红色，则表示出现内存泄漏
5. 选中Leaks Checks,在Details所在栏中选择CallTree,并且在右下角勾选 `Invert Call Tree`  和 `Hide System Libraries`，会发现显示若干行代码，双击即可跳转到出现内存泄漏的地方，修改即可。
6. Instruments 可以帮我们了解到应用程序使用内存的几个方面：
  - 全局内存使用情况(Overall Memory Use)：从全局的角度监测应用程序的内存使用情况，捕捉非预期的或大幅度的内存增长
  - 内存泄露(Leaked memory)：未被你的程序引用，同时也不能被使用或释放的内存
  - 废弃内存(Abandoned memory)：被你的程序引用，但是没什么用的内存
  - 僵尸对象(Zombies)：指的是对应的内存已经被释放并且不再会使用到，但是你的程序却在某处依然有指向它的引用

注意：静态内存泄漏分析不能把所有的内存泄漏排查出来，因为有的内存泄漏发生在运行时，当用户做某些操作时才发生内存泄漏。这是就要使用动态内存泄漏检测方法了。
注意：内存泄露(Leaked memory)：未被你的程序引用，同时也不能被使用或释放的内存。这里就是使用Instruments-Leak动态检测内存泄漏。

### Xcode-Analyzer（静态分析）

1. 通过Xcode打开项目，然后点击Product->Analyze，开始进入静态内存泄漏分析。
2. 等待分析结果，根据分析的结果对可能造成内存泄漏的代码进行排查
3. Analyze 主要分析以下四种问题:
  - 逻辑错误：访问空指针或未初始化的变量等；  
  - 内存管理错误：如内存泄漏等；
  - 声明错误：从未使用过的变量；  
  - API调用错误：未包含使用的库和框架。

注意：静态内存泄漏分析能发现大部分问题，但只是静态分析，并且并不准确，只是有可能发生内存泄漏。一些动态内存分配的情形并没有分析。如果需要更精准一些，那就要用到的动态内存泄漏分析方法（Instruments工具中的Leaks方法）进行排查。

### MLeaksFinder (第三方工具)

1. [MLeaksFinder](https://links.jianshu.com/go?to=https%3A%2F%2Fgithub.com%2FZepo%2FMLeaksFinder) 提供了内存泄露检测更好的解决方案。只需要引入`MLeaksFinder`，就可以自动在 App 运行过程检测到内存泄露的对象并立即提醒，无需打开额外的工具，也无需为了检测内存泄露而一个个场景去重复地操作。MLeaksFinder 目前能自动检测`UIViewController`和`UIView`对象的内存泄露，而且也可以扩展以检测其它类型的对象。
2. MLeaksFinder 的使用很简单，参照 [https://github.com/Zepo/MLeaksFinder](https://links.jianshu.com/go?to=https%3A%2F%2Fgithub.com%2FZepo%2FMLeaksFinder)，基本上就是把 MLeaksFinder 目录下的文件添加到你的项目中，就可以在运行时（debug 模式下）帮助你检测项目里的内存泄露了，无需修改任何业务逻辑代码，而且只在 debug 下开启，完全不影响你的 release 包。
3. 实现原理可以看 [MLeaksFinder：精准 iOS 内存泄露检测工具](https://links.jianshu.com/go?to=https%3A%2F%2Fwereadteam.github.io%2F2016%2F02%2F22%2FMLeaksFinder%2F)
4. 推荐使用第三方库来监测内存泄漏，开发的时候快速定位，节约时间。

注意：Instruments-Leak、Xcode-Analyzer、MLeaksFinder三种方案都是线下监控工具。

## 项目具体场景优化

代码参考 Ticket #4454 【优化】IOS内存优化

```
1. id 类型属性使用 __weak 修饰
2. id 类型属性 retain 修饰符改成 weak
3. 解绑视图方法中 [_implView removeFromSuperview]; （不是很明白）
4. block 代码块中 self 和 _ 改成 weakSelf，声明 __weak typeof(self) weakSelf = self;
5. unBindView 方法中，将 [super unBindView];  方法挪到最后调用
6. block 代码块前定义 __block 修饰符改成 __weak
7. NSObject 类型属性使用 __weak 修饰
8. dealloc 方法中 cancelAllOperationsByFormKey 取消线程池所有操作，unBindView 解绑视图
9. ImageUtil 类中 loadDataFromNetWithHandler 方法（猜测是图片资源释放操作）
10. UIView 类型属性使用 __weak 修饰
11. WebBrowser 类 unBindView 方法中 releaseHandler 和 [super unBindView];
```

## 项目内存泄露线下监控

1. 首先， 使用 Xcode 内置的 Analyzer 工具进行静态分析，如下图所示：

![[Xcode Analyzer 工具静态分析.png]]

2. 其次，使用 Xcode 内置的 Instruments Leaks 工具进行动态内存泄漏检测，由于加载服务地址判断网络状态时进行了越狱检查 isJailbroken，检测启动 app 时会提示“应用不支持越狱设备,请退出”，所以注释掉这块代码，代码截图如下所示：

![[注释越狱检查 isJailbroken.png]]

使用 Xcode 内置的 Instruments Leaks 工具进行动态内存泄漏检测，如下图所示：

![[Xcode Instruments Leaks 动态内存泄漏检测.png]]

由上图可以看出，存在内存泄漏，但是工具不好使无法定位内存泄漏所在代码的位置，所以考虑使用第三方库。

3. 最后，使用 MLeaksFinder 第三方内存查找库

```
使用方法：

**1) 引进 MLeaksFinder 后没生效？**

-   先验证引进是否正确，在 UIViewController+MemoryLeak.m 的 `+ (void)load` 方法里加断点，app 启动时进入该方法则引进成功，否则引进失败。
-   用 CocoaPods 安装时注意有没有 warnings，特别是 `OTHER_LDFLAGS` 相关的 warnings。如果有 warnings，可以在主工程的 Build Settings -> Other Linker Flags 加上 `-ObjC`。

**2) 可以手动引进 MLeaksFinder 吗？**

-   直接把 MLeaksFinder 的代码放到项目里即生效。如果把 MLeaksFinder 做为子工程，需要在主工程的 Build Settings -> Other Linker Flags 加上 `-ObjC`。
-   引进 MLeaksFinder 的代码后即可检测内存泄漏，但查找循环引用的功能还未生效。可以再手动加入 FBRetainCycleDetector 代码，然后把 MLeaksFinder.h 里的 `//#define MEMORY_LEAKS_FINDER_RETAIN_CYCLE_ENABLED 1` 打开。

**3) Fail to find a retain cycle？**

-   内存泄漏不一定是循环引用造成的。
-   有的循环引用 FBRetainCycleDetector 不一定能找出。

**4) 如何关掉 MLeaksFinder？**

-   MLeaksFinder 默认只在 debug 下生效，当然也可以通过 MLeaksFinder.h 里的 `//#define MEMORY_LEAKS_FINDER_ENABLED 0` 来手动控制开关。
```

控制台提示如下所示：

```objc
*** Terminating app due to uncaught exception 'NSInternalInconsistencyException', reason: 'Possibly Memory Leak.

In case that MyTableViewCell should not be dealloced, override -willDealloc in MyTableViewCell by returning NO.

View-ViewController stack: (

    MyTableViewController,

    UITableView,

    UITableViewWrapperView,

    MyTableViewCell

)'
```

从 MLeaksFinder 的使用方法可以看出，MLeaksFinder 具备以下优点：

-   使用简单，不侵入业务逻辑代码，不用打开 Instrument
-   不需要额外的操作，你只需开发你的业务逻辑，在你运行调试时就能帮你检测
-   内存泄露发现及时，更改完代码后一运行即能发现（这点很重要，你马上就能意识到哪里写错了）
-   精准，能准确地告诉你哪个对象没被释放

使用过后：该第三方库久未更新，存在异常，使用体检不佳。