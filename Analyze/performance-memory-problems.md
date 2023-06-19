# 性能优化-内存问题

## 常见的内存问题

1. 内存泄漏：Memory Leak，是指程序在申请内存后，无法释放已申请的内存空间，一次内存泄漏似乎不会有大的影响，但内存泄漏堆积后的后果就是内存溢出。
2. 内存溢出：OOM，是 Out of Memory 的缩写，指的是 App 占用的内存达到了 iOS 系统对单个 App 占用内存上限后，而被系统强杀掉的现象。OOM 其实也属于应用“崩溃”中的一种，是由 iOS 的 Jetsam 机制导致的一种“另类”崩溃，并且日志无法通过信号捕捉到。
3. 访问未分配的内存：XNU 会报 EXC_BAD_ACCESS 错误，信号为 SIGSEGV Signal #11 。
4. 访问已分配但未提交的内存：XNU 会拦截分配物理内存，出现问题的线程分配内存页时会被冻结。
5. 没有遵守权限访问内存：内存页面的权限标准类似 UNIX 文件权限。如果去写只读权限的内存页面就会出现错误，XNU 会发出 SIGBUS Signal #7 信号。

注意：“访问未分配的内存”和“没有遵守权限访问内存”问题都可以通过崩溃信息获取到，在收集崩溃信息时如果发现是这两类，我们就可以把内存分配的记录同时传过来进行分析，对于不合理的内存分配进行优化和修改。

## 内存问题监控手段

### 线下监控手段

1. Xcode-Runtime issues：Runtime issues 有三类：线程问题，UI 布局和渲染问题，以及内存问题。内存问题最常见的就是内存泄漏，比如循环引用就是一个经典的错误。
2. Xcode-Memory Debug Graph：点击调试工具栏中的按钮，Xcode 会自动检测内存相关的 memory runtime issue。点击相关问题处 Xcode 就会给出详细的循环引用示意图。
3. Instruments-Leak：一个专门检测内存泄漏的工具。进入页面后发现 Leak Checks 中出现内存泄漏时，我们可以将导航栏切换到 call tree 模式下，强烈建议在 Display Settings 中勾选 Separate by Thread 和 Hide System Libraries 两个选项，这样可以隐藏掉系统和应用本身的调用路径，帮助我们更方便的找出 retain cycle 位置。
4. Zombie 和 Address Sanitizer：僵尸对象和地址内存错误检测，可以在绝大多数情况下定位 EXC_BAD_ACCESS 问题代码，EXC_BAD_ACCESS 主要原因是访问了某些已经释放的对象，或者访问了它们已经释放的成员变量或方法。
5. Instruments-Allocations：跟踪进程的匿名虚拟内存和堆，为对象提供类名和可选的 retain、release历史记录。可以查看虚拟内存占用、堆信息、对象信息、调用栈信息，VM Regions 信息等。可以利用这个工具分析内存，并针对地进行优化。

注意：1-3是内存泄露，主要是循环引用；4是坏内存访问，EXC_BAD_ACCESS 错误，主要是访问了某些已经释放的对象，或者访问了它们已经释放的成员变量或方法；5是检查内存溢出。

### 线上监控手段

1. 通过 JetsamEvent 日志计算内存限制值：查看手机中以 JetsamEvent 开头的系统日志（我们可以从设置 -> 隐私 -> 分析中看到这些日志）。
2. 通过 XNU 获取内存限制值：通过 XNU 的宏获取内存限制，需要有 root 权限，而 App 内的权限是不够的，所以正常情况下，作为 App 开发者你是看不到这个信息的。那么，需要越狱去获取这个权限。
3. 通过内存警告获取内存限制值： 可以利用 didReceiveMemoryWarning 这个内存压力代理事件来动态地获取内存限制值。iOS 系统在强杀掉 App 之前还有 6 秒钟的时间，足够你去获取记录内存信息了。

注意：1-2是获取内存上限值，3是监控到 App 因为占用内存过大而被强杀的时机，然后获取当前内存使用情况，一般使用1、3。

## 内存问题信息收集

1. 内存分配函数 malloc 和 calloc 等默认使用的是 nano_zone。nano_zone 是 256B 以下小内存的分配，大于 256B 的时候会使用 scalable_zone 来分配。
2. 这里主要是针对大内存的分配监控，所以只针对 scalable_zone 进行分析，同时也可以过滤掉很多小内存分配监控。比如，malloc 函数用的是 malloc_zone_malloc，calloc 用的是 malloc_zone_calloc。
3. 使用 scalable_zone 分配内存的函数都会调用 malloc_logger 函数，因为系统总是需要有一个地方来统计并管理内存的分配情况。（malloc_zone_malloc 函数中，在 zone 分配完内存后就开始使用 malloc_logger 进行进行记录。）
4. 可以使用 fishhook 去 Hook 这个函数，加上自己的统计记录就能够通盘掌握内存的分配情况。出现问题时，将内存分配记录的日志捞上来，你就能够跟踪到导致内存不合理增大的原因了。