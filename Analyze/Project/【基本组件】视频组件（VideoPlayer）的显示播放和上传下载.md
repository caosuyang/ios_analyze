## 配置说明

VideoPlayer(视频组件)3.1.0sp7新增控件

```xml
<VideoPlayer Key="VideoPlayer" Caption="VideoPlayer" SourceType="Data" Path="test/test.mp4" UploadProgress="Strip" />
</VideoPlayer>
```

- 仅mp4格式视频同时支持Android，IOS，h5端，所以一般推荐使用mp4格式。各端支持视频格式参阅各系统官方文档，其中Android端参考https://developer.android.google.cn/guide/topics/media/media-formats.html。
- 该控件的宽高不可以为自适应。
- 当控件可用性为true时，点击后当SourceType为Data，非上传过程中，且控件值为空时，弹出对话框，选择拍照或从相册选择图片，再上传。 如果上传时服务端有同名文件，会替换服务端同名文件。
- 当控件可用性为true，SourceType为Data，非上传过程中，且控件值不为空时，右上角显示删除按钮，点击清空控件值。
  - SourceType：视频来源类型，取值为Data或Resource，即配置文件Data文件夹或Resource文件夹视频。默认值为Data。SourceType为Data时，显示控件值对应视频，SourceType为Resource时，显示Path属性对应视频。
  - Path：在SourceType为Resource时，定义视频相对Resource文件夹路径
  - UploadProgress：显示上传进度指示器的样式，有None、Strip、Circle、Percent，分别是不显示、条状、圆环状、百分比。默认不显示
  - OnlyShow：控件不支持该属性
  - BackColor：不支持Format的BackColor属性

## 业务需求

1. 支持调用系统相册和相机，选择视频，从相册列表获取；拍摄视频，打开相机进入视频拍摄模式
2. 播放来源 data 和 resource 本地的视频
3. 支持本地缓存视频文件
4. 支持上传进度指示器样式，条状，圆环状，百分比
5. 支持自定义视频播放器组件，包括选择、删除、播放、暂停按钮
6. 支持明细控件中装配该组件
7. 支持分段加载视频文件

## 核心

1. 自定义视频视频播放器
2. 分段加载视频文件
3. 低代码逻辑

## 自定义视频视频播放器

- VideoPlayerImpl：视频组件视图
- import <AVFoundation/AVFoundation.h>：AVPlayer
- import <AVKit/AVKit.h>：AVPlayerViewController
- 核心逻辑：playerVC.player = player
- 点击事件和上传视频数据流使用 VideoPlayerImplDelegate 视频组件视图委托给 VideoPlayer 视频组件处理
- 重要逻辑：上传视频数据流，封装成 UploadVideoHandler 处理类（初始化、上传视频、成功回调、失败回调），异步处理

## 分段加载视频文件

- [KTVHTTPCache]((https://github.com/ChangbaDevs/KTVHTTPCache)：一个强大的媒体缓存框架。它可以缓存HTTP请求，非常适合媒体资源

![[KTVHTTPCache流程图.jpeg]]

- [唱吧KTVHTTPCache 主体框架](https://blog.csdn.net/u014600626/article/details/120368196)
- 主要模块就是 `Data Storage`，它主要负责资源加载及缓存处理。从这里可以看出，[KTVHTTPCache](https://link.jianshu.com/?t=https://github.com/ChangbaDevs/KTVHTTPCache "KTVHTTPCache") 主要的工作量是设计 Data Storage 这个模块，也就是它的核心所在
- 其本质是对 HTTP 请求进行缓存，对传输内容并没有限制，因此应用场景不限于音视频在线播放，也可以用于文件下载、图片加载、普通网络请求等场景
- KTVHTTPCache 由 HTTP Server 和 Data Storage 两大模块组成。前者负责与 Client 交互，后者负责资源加载及缓存处理。
- 通俗地讲，HTTP Server 和 Data Storage 是 KTVHTTPCache 两大重要组成部分， HTTP Server 主要负责与用户交互，也就是最顶层，最直接与用户交互（比如下载数据），而 Data Storage 则在后面为 HTTP Server 提供数据，数据主要从 DataSourcer 中获取，如果本地有数据，它会从 KTVHCDataFileSource 中获取，反之会从 KTVHCDataNetworkSource 中读取数据，这里会走下载逻辑（KTVHCDownload）。
- 其实 HttpServer 的关键点是在 KTVHCHTTPConnection 中下面这个方法，它是连接缓存模块的一个桥梁。使用 `KTVHCDataRequest` 和 `KTVHCHTTPConnection` 来生成 `KTVHCHTTPResponse`，**关键点在于生成这个 Response**。
- DataStroage，主要用来缓存数据，加载数据，也就是提供数据给 HttpServer。上面代码中关键的一句代码 `[KTVHCHTTPResponse responseWithConnection:self dataRequest:dataRequest]`，它会在这个方法的内部使用 `KTVHCDataStorage` 生成一个 `KTVHCDataReader`，负责读取数据。生成 `KTVHCDataReader` 后通过 `[self.reader prepare]` 来准备数据源 `KTVHCDataSourcer`，这里主要有两个数据源，`KTVHCDataFileSource` 和 `KTVHCDataNetworkSource`，它实现了协议 `KTVHCDataSourceProtocol`。`KTVHCDataNetworkSource` 会通过 `KTVHCDownload` 下载数据
- 要说明一点，缓存是分片处理的
- 缓存目录的构成：结构，Data Storeage 同时支持并行和串行。在并行场景中极端情况可能遇到恰好同时存在两个相同 Offset 的 Network Source，用来保证并行加载的安全性（实际场景中也没遇到过，但在结构设计时把这部分考虑进去了）
- 缓存策略：例如一次请求的 Range 为 0-999，本地缓存中已有 200-499 和 700-799 两段数据。那么会对应生成 5 个 Source
- 日志系统：做音视频项目时，一个好的 Log 管理可以提高调试效率，而 [KTVHTTPCache](https://link.jianshu.com/?t=https://github.com/ChangbaDevs/KTVHTTPCache "KTVHTTPCache") 可以追踪到每一次异常的请求。而且回记录到一个 `KTVHTTPCache.log` 文件中

```txt
学习这个库总体来说比较耗时，但是能学到作者的思想，这里总结一下：

职责明确，每个类的作用定义明确；
KTVHCDataFileSource 和 KTVHCDataNetworkSource，使用协议 KTVHCDataSourceProtocol 的方式实现不同的 Source，而不用继承，耦合性更低；
使用简单，内部定义复杂，缓缓相扣；
使用 NSLock 保证线程安全；
日志定义周全，调试更容易；
```

- 初始化 log

```objc
2023-01-17 10:33:09.429311+0800 KTVHTTPCache[9962:2763949] <KTVHCHTTPServer: 0x280a14160>  :   alloc
2023-01-17 10:33:09.432635+0800 KTVHTTPCache[9962:2763949] KTVHCHTTPServer         :   0x280a14160, Start server success
2023-01-17 10:33:09.432669+0800 KTVHTTPCache[9962:2763949] Proxy Start Success
2023-01-17 10:33:09.432729+0800 KTVHTTPCache[9962:2763949] <KTVHCDownload: 0x282144150>  :   alloc
```

- 播放+缓存+销毁 log

```objc
2023-01-17 10:35:16.969848+0800 KTVHTTPCache[9962:2763949] KTVHCHTTPServer         :   0x280a14160, Return URL
URL : http://localhost:80/request.mp4?url=http%3A%2F%2Faliuwmp3.changba.com%2Fuserdata%2Fvideo%2F45F6BD5E445E4C029C33DC5901307461.mp4
2023-01-17 10:35:17.148512+0800 KTVHTTPCache[9962:2764847] <KTVHCHTTPConnection: 0x283b5c960>  :   alloc
2023-01-17 10:35:17.150826+0800 KTVHTTPCache[9962:2764847] KTVHCHTTPConnection     :   0x283b5c960, Receive request
method : GET
path : /request.mp4?url=http%3A%2F%2Faliuwmp3.changba.com%2Fuserdata%2Fvideo%2F45F6BD5E445E4C029C33DC5901307461.mp4
URL : /request.mp4?url=http%3A%2F%2Faliuwmp3.changba.com%2Fuserdata%2Fvideo%2F45F6BD5E445E4C029C33DC5901307461.mp4 -- http://localhost:80/
2023-01-17 10:35:17.150959+0800 KTVHTTPCache[9962:2764847] <KTVHCDataRequest: 0x280423b10>  :   alloc
2023-01-17 10:35:17.151101+0800 KTVHTTPCache[9962:2764847] KTVHCDataRequest        :   0x280423b10 Create data request
URL : http://aliuwmp3.changba.com/userdata/video/45F6BD5E445E4C029C33DC5901307461.mp4
Headers : {
    Accept = "*/*";
    "Accept-Encoding" = identity;
    "Accept-Language" = "zh-CN,zh-Hans;q=0.9";
    Connection = "keep-alive";
    Host = "localhost:80";
    Range = "bytes=0-1";
    "User-Agent" = "AppleCoreMedia/1.0.0.20B101 (iPhone; U; CPU OS 16_1_1 like Mac OS X; zh_cn)";
    "X-Playback-Session-Id" = "86EB8EDA-6718-4A87-A90D-19522219E252";
}
Range : Range : {0, 1}
2023-01-17 10:35:17.151180+0800 KTVHTTPCache[9962:2764847] <KTVHCHTTPResponse: 0x280a09200>  :   alloc
2023-01-17 10:35:17.151300+0800 KTVHTTPCache[9962:2764847] <KTVHCDataReader: 0x282147cd0>  :   alloc
2023-01-17 10:35:17.154974+0800 KTVHTTPCache[9962:2764847] <KTVHCDataUnitItem: 0x281f21c80>  :   alloc
2023-01-17 10:35:17.155040+0800 KTVHTTPCache[9962:2764847] KTVHCDataUnitItem       :   0x281f21c80, Create Unit Item
absolutePath : /var/mobile/Containers/Data/Application/38A12524-BD9B-4CCB-B042-5C402B8A514B/Documents/KTVHTTPCache/05f68836443a1535b73bfcf3c2e86d99/05f68836443a1535b73bfcf3c2e86d99.mp4
relativePath : /KTVHTTPCache/05f68836443a1535b73bfcf3c2e86d99/05f68836443a1535b73bfcf3c2e86d99.mp4
Offset : 0
Length : 21181097
2023-01-17 10:35:17.155085+0800 KTVHTTPCache[9962:2764847] <KTVHCDataUnit: 0x282e445a0>  :   alloc
2023-01-17 10:35:17.155132+0800 KTVHTTPCache[9962:2764847] KTVHCDataUnit           :   0x282e445a0, Sort unitItems - Begin
(
    "<KTVHCDataUnitItem: 0x281f21c80>"
)
2023-01-17 10:35:17.155174+0800 KTVHTTPCache[9962:2764847] KTVHCDataUnit           :   0x282e445a0, Sort unitItems - End  
(
    "<KTVHCDataUnitItem: 0x281f21c80>"
)
2023-01-17 10:35:17.156805+0800 KTVHTTPCache[9962:2764847] KTVHCDataUnit           :   0x282e445a0, Create Unit
URL : http://aliuwmp3.changba.com/userdata/video/45F6BD5E445E4C029C33DC5901307461.mp4
key : 05f68836443a1535b73bfcf3c2e86d99
timeInterval : 2023-01-17 02:28:55 +0000
totalLength : 21181097
cacheLength : 21181097
vaildLength : 21181097
responseHeaders : {
    "Accept-Ranges" = bytes;
    Connection = "keep-alive";
    "Content-Type" = "video/mp4";
    Server = Tengine;
}
unitItems : (
    "<KTVHCDataUnitItem: 0x281f21c80>"
)
2023-01-17 10:35:17.192988+0800 KTVHTTPCache[9962:2764847] <KTVHCDataUnitItem: 0x281f23c40>  :   alloc
2023-01-17 10:35:17.193053+0800 KTVHTTPCache[9962:2764847] KTVHCDataUnitItem       :   0x281f23c40, Create Unit Item
absolutePath : /var/mobile/Containers/Data/Application/38A12524-BD9B-4CCB-B042-5C402B8A514B/Documents/KTVHTTPCache/66cc3b6a71dc1a480b895940da0666a2/66cc3b6a71dc1a480b895940da0666a2.mp4
relativePath : /KTVHTTPCache/66cc3b6a71dc1a480b895940da0666a2/66cc3b6a71dc1a480b895940da0666a2.mp4
Offset : 0
Length : 19085441
2023-01-17 10:35:17.193107+0800 KTVHTTPCache[9962:2764847] <KTVHCDataUnit: 0x282e4c1e0>  :   alloc
2023-01-17 10:35:17.193167+0800 KTVHTTPCache[9962:2764847] KTVHCDataUnit           :   0x282e4c1e0, Sort unitItems - Begin
(
    "<KTVHCDataUnitItem: 0x281f23c40>"
)
2023-01-17 10:35:17.193203+0800 KTVHTTPCache[9962:2764847] KTVHCDataUnit           :   0x282e4c1e0, Sort unitItems - End  
(
    "<KTVHCDataUnitItem: 0x281f23c40>"
)
2023-01-17 10:35:17.193358+0800 KTVHTTPCache[9962:2764847] KTVHCDataUnit           :   0x282e4c1e0, Create Unit
URL : http://aliuwmp3.changba.com/userdata/video/3B1DDE764577E0529C33DC5901307461.mp4
key : 66cc3b6a71dc1a480b895940da0666a2
timeInterval : 2023-01-17 02:29:04 +0000
totalLength : 19085441
cacheLength : 19085441
vaildLength : 19085441
responseHeaders : {
    "Accept-Ranges" = bytes;
    Connection = "keep-alive";
    "Content-Type" = "video/mp4";
    Server = Tengine;
}
unitItems : (
    "<KTVHCDataUnitItem: 0x281f23c40>"
)
2023-01-17 10:35:17.193927+0800 KTVHTTPCache[9962:2764847] <KTVHCDataUnitItem: 0x281fdd540>  :   alloc
2023-01-17 10:35:17.193971+0800 KTVHTTPCache[9962:2764847] KTVHCDataUnitItem       :   0x281fdd540, Create Unit Item
absolutePath : /var/mobile/Containers/Data/Application/38A12524-BD9B-4CCB-B042-5C402B8A514B/Documents/KTVHTTPCache/c3c09314a104eb42fe9ac4c0769d4722/c3c09314a104eb42fe9ac4c0769d4722.mp4
relativePath : /KTVHTTPCache/c3c09314a104eb42fe9ac4c0769d4722/c3c09314a104eb42fe9ac4c0769d4722.mp4
Offset : 0
Length : 24483470
2023-01-17 10:35:17.194051+0800 KTVHTTPCache[9962:2764847] <KTVHCDataUnit: 0x282e74ba0>  :   alloc
2023-01-17 10:35:17.194088+0800 KTVHTTPCache[9962:2764847] KTVHCDataUnit           :   0x282e74ba0, Sort unitItems - Begin
(
    "<KTVHCDataUnitItem: 0x281fdd540>"
)
2023-01-17 10:35:17.194119+0800 KTVHTTPCache[9962:2764847] KTVHCDataUnit           :   0x282e74ba0, Sort unitItems - End  
(
    "<KTVHCDataUnitItem: 0x281fdd540>"
)
2023-01-17 10:35:17.194206+0800 KTVHTTPCache[9962:2764847] KTVHCDataUnit           :   0x282e74ba0, Create Unit
URL : http://qiniuuwmp3.changba.com/941946870.mp4
key : c3c09314a104eb42fe9ac4c0769d4722
timeInterval : 2023-01-17 02:29:28 +0000
totalLength : 24483470
cacheLength : 24483470
vaildLength : 24483470
responseHeaders : {
    "Accept-Ranges" = bytes;
    Connection = "keep-alive";
    "Content-Type" = "video/mp4";
    Server = "Byte-nginx";
}
unitItems : (
    "<KTVHCDataUnitItem: 0x281fdd540>"
)
2023-01-17 10:35:17.195237+0800 KTVHTTPCache[9962:2764847] <KTVHCDataUnit: 0x282e78840>  :   alloc
2023-01-17 10:35:17.195288+0800 KTVHTTPCache[9962:2764847] KTVHCDataUnit           :   0x282e78840, Sort unitItems - Begin
(
)
2023-01-17 10:35:17.195316+0800 KTVHTTPCache[9962:2764847] KTVHCDataUnit           :   0x282e78840, Sort unitItems - End  
(
)
2023-01-17 10:35:17.195459+0800 KTVHTTPCache[9962:2764847] KTVHCDataUnit           :   0x282e78840, Create Unit
URL : http://lzaiuw.changba.com/userdata/video/940071102.mp4
key : e383b6e5086182b2e00c799d3a4ad498
timeInterval : 2023-01-17 02:29:38 +0000
totalLength : 0
cacheLength : 0
vaildLength : 0
responseHeaders : (null)
unitItems : (
)
2023-01-17 10:35:17.195790+0800 KTVHTTPCache[9962:2764847] KTVHCDataUnitPool       :   0x2804d9e60, Create Pool
Units : (
    "<KTVHCDataUnit: 0x282e445a0>",
    "<KTVHCDataUnit: 0x282e4c1e0>",
    "<KTVHCDataUnit: 0x282e74ba0>",
    "<KTVHCDataUnit: 0x282e78840>"
)
2023-01-17 10:35:17.195879+0800 KTVHTTPCache[9962:2764847] URL Filter reviced URL : http://aliuwmp3.changba.com/userdata/video/45F6BD5E445E4C029C33DC5901307461.mp4
2023-01-17 10:35:17.196307+0800 KTVHTTPCache[9962:2764847] KTVHCDataUnit           :   0x282e445a0, Working retain  : 1
2023-01-17 10:35:17.196410+0800 KTVHTTPCache[9962:2764847] <KTVHCDataRequest: 0x2804ddc20>  :   alloc
2023-01-17 10:35:17.196567+0800 KTVHTTPCache[9962:2764847] KTVHCDataRequest        :   0x2804ddc20 Create data request
URL : http://aliuwmp3.changba.com/userdata/video/45F6BD5E445E4C029C33DC5901307461.mp4
Headers : {
    Accept = "*/*";
    "Accept-Encoding" = identity;
    "Accept-Language" = "zh-CN,zh-Hans;q=0.9";
    Connection = "keep-alive";
    Host = "localhost:80";
    Range = "bytes=0-1";
    "User-Agent" = "AppleCoreMedia/1.0.0.20B101 (iPhone; U; CPU OS 16_1_1 like Mac OS X; zh_cn)";
    "X-Playback-Session-Id" = "86EB8EDA-6718-4A87-A90D-19522219E252";
}
Range : Range : {0, 1}
2023-01-17 10:35:17.196612+0800 KTVHTTPCache[9962:2764847] KTVHCDataReader         :   0x282147cd0, Create reader
orignalRequest : <KTVHCDataRequest: 0x280423b10>
finalRequest : <KTVHCDataRequest: 0x2804ddc20>
Unit : <KTVHCDataUnit: 0x282e445a0>
2023-01-17 10:35:17.197394+0800 KTVHTTPCache[9962:2764847] KTVHCDataReader         :   0x282147cd0, Call prepare
2023-01-17 10:35:17.197449+0800 KTVHTTPCache[9962:2764847] KTVHCDataUnit           :   0x282e445a0, Get unitItems
(
    "<KTVHCDataUnitItem: 0x281f21c80>"
)
2023-01-17 10:35:17.197510+0800 KTVHTTPCache[9962:2764847] <KTVHCDataFileSource: 0x282178310>  :   alloc
2023-01-17 10:35:17.197594+0800 KTVHTTPCache[9962:2764847] KTVHCDataFileSource     :   0x282178310, Create file source
path : /var/mobile/Containers/Data/Application/38A12524-BD9B-4CCB-B042-5C402B8A514B/Documents/KTVHTTPCache/05f68836443a1535b73bfcf3c2e86d99/05f68836443a1535b73bfcf3c2e86d99.mp4
range : Range : {0, 21181096}
readRange : Range : {0, 1}
2023-01-17 10:35:17.197653+0800 KTVHTTPCache[9962:2764847] <KTVHCDataSourceManager: 0x282e74cc0>  :   alloc
2023-01-17 10:35:17.198193+0800 KTVHTTPCache[9962:2764847] KTVHCDataSourceManager  :   0x282e74cc0, Call prepare
2023-01-17 10:35:17.198225+0800 KTVHTTPCache[9962:2764847] KTVHCDataSourceManager  :   0x282e74cc0, Sort sources - Begin
Sources : (
    "<KTVHCDataFileSource: 0x282178310>"
)
2023-01-17 10:35:17.198251+0800 KTVHTTPCache[9962:2764847] KTVHCDataSourceManager  :   0x282e74cc0, Sort sources - End  
Sources : (
    "<KTVHCDataFileSource: 0x282178310>"
)
2023-01-17 10:35:17.198440+0800 KTVHTTPCache[9962:2764847] KTVHCDataSourceManager  :   0x282e74cc0, Sort source
currentSource : <KTVHCDataFileSource: 0x282178310>
currentNetworkSource : (null)
2023-01-17 10:35:17.198470+0800 KTVHTTPCache[9962:2764847] KTVHCDataFileSource     :   0x282178310, Call prepare
2023-01-17 10:35:17.198981+0800 KTVHTTPCache[9962:2764847] KTVHCDataFileSource     :   0x282178310, Callback for prepared - Begin
2023-01-17 10:35:17.199067+0800 KTVHTTPCache[9962:2764847] <KTVHCDataUnitItem: 0x281fdc800>  :   dealloc
2023-01-17 10:35:17.199138+0800 KTVHTTPCache[9962:2764847] KTVHCHTTPResponse       :   0x280a09200, Create response
request : <KTVHCDataRequest: 0x280423b10>
2023-01-17 10:35:17.199253+0800 KTVHTTPCache[9962:2764847] <KTVHCDataRequest: 0x280423b10>  :   dealloc
2023-01-17 10:35:17.199590+0800 KTVHTTPCache[9962:2764843] KTVHCDataFileSource     :   0x282178310, Callback for prepared - End
2023-01-17 10:35:17.199641+0800 KTVHTTPCache[9962:2764843] KTVHCDataSourceManager  :   0x282e74cc0, Callback for prepared - Begin
2023-01-17 10:35:17.199672+0800 KTVHTTPCache[9962:2764843] KTVHCDataSourceManager  :   0x282e74cc0, Callback for prepared - End
2023-01-17 10:35:17.199673+0800 KTVHTTPCache[9962:2764847] KTVHCHTTPResponse       :   0x280a09200, Delay response : 1
2023-01-17 10:35:17.199723+0800 KTVHTTPCache[9962:2764843] <KTVHCDataResponse: 0x28291d2c0>  :   alloc
2023-01-17 10:35:17.199823+0800 KTVHTTPCache[9962:2764843] KTVHCDataResponse       :   0x28291d2c0 Create data response
URL : http://aliuwmp3.changba.com/userdata/video/45F6BD5E445E4C029C33DC5901307461.mp4
Headers : {
    "Accept-Ranges" = bytes;
    Connection = "keep-alive";
    "Content-Length" = 2;
    "Content-Range" = "bytes 0-1/21181097";
    "Content-Type" = "video/mp4";
    Server = Tengine;
}
contentType : video/mp4
totalLength : 21181097
currentLength : 2
2023-01-17 10:35:17.200132+0800 KTVHTTPCache[9962:2764843] KTVHCDataReader         :   0x282147cd0, Reader did prepared
Response : <KTVHCDataResponse: 0x28291d2c0>
2023-01-17 10:35:17.200176+0800 KTVHTTPCache[9962:2764843] KTVHCDataReader         :   0x282147cd0, Callback for prepared - Begin
2023-01-17 10:35:17.200224+0800 KTVHTTPCache[9962:2764843] KTVHCDataReader         :   0x282147cd0, Callback for prepared - End
2023-01-17 10:35:17.200251+0800 KTVHTTPCache[9962:2764843] KTVHCHTTPResponse       :   0x280a09200, Prepared
2023-01-17 10:35:17.200273+0800 KTVHTTPCache[9962:2764843] KTVHCHTTPResponse       :   0x280a09200, Call connection did prepared
2023-01-17 10:35:17.200424+0800 KTVHTTPCache[9962:2764843] KTVHCHTTPResponse       :   0x280a09200, Delay response : 0
2023-01-17 10:35:17.200454+0800 KTVHTTPCache[9962:2764843] KTVHCHTTPResponse       :   0x280a09200, Conetnt length : 21181097
2023-01-17 10:35:17.202408+0800 KTVHTTPCache[9962:2764843] KTVHCHTTPResponse       :   0x280a09200, Header
{
    "Accept-Ranges" = bytes;
    Connection = "keep-alive";
    "Content-Type" = "video/mp4";
    Server = Tengine;
}
2023-01-17 10:35:17.202533+0800 KTVHTTPCache[9962:2764843] KTVHCHTTPResponse       :   0x280a09200, Set offset : 0, 0
2023-01-17 10:35:17.202828+0800 KTVHTTPCache[9962:2764843] KTVHCDataFileSource     :   0x282178310, Read data : 2, 2, 2
2023-01-17 10:35:17.202858+0800 KTVHTTPCache[9962:2764843] KTVHCDataFileSource     :   0x282178310, Read data did finished
2023-01-17 10:35:17.202906+0800 KTVHTTPCache[9962:2764843] KTVHCDataSourceManager  :   0x282e74cc0, Read data : 2
2023-01-17 10:35:17.203873+0800 KTVHTTPCache[9962:2764843] KTVHCDataSourceManager  :   0x282e74cc0, Fetch netxt source failed
2023-01-17 10:35:17.203899+0800 KTVHTTPCache[9962:2764843] KTVHCDataSourceManager  :   0x282e74cc0, Read data did finished
2023-01-17 10:35:17.203924+0800 KTVHTTPCache[9962:2764843] KTVHCDataReader         :   0x282147cd0, Read data : 2
2023-01-17 10:35:17.204103+0800 KTVHTTPCache[9962:2764843] KTVHCDataReader         :   0x282147cd0, Read data did finished
2023-01-17 10:35:17.204581+0800 KTVHTTPCache[9962:2764843] KTVHCDataReader         :   0x282147cd0, Call close
2023-01-17 10:35:17.204611+0800 KTVHTTPCache[9962:2764843] KTVHCDataSourceManager  :   0x282e74cc0, Call close
2023-01-17 10:35:17.204817+0800 KTVHTTPCache[9962:2764843] KTVHCDataFileSource     :   0x282178310, Call close
2023-01-17 10:35:17.204915+0800 KTVHTTPCache[9962:2764843] KTVHCDataUnit           :   0x282e445a0, Working release : 0
2023-01-17 10:35:17.205238+0800 KTVHTTPCache[9962:2764843] URL Filter reviced URL : http://aliuwmp3.changba.com/userdata/video/45F6BD5E445E4C029C33DC5901307461.mp4
2023-01-17 10:35:17.205423+0800 KTVHTTPCache[9962:2764843] URL Filter reviced URL : http://aliuwmp3.changba.com/userdata/video/45F6BD5E445E4C029C33DC5901307461.mp4
2023-01-17 10:35:17.206454+0800 KTVHTTPCache[9962:2764843] KTVHCHTTPResponse       :   0x280a09200, Read data : 2
2023-01-17 10:35:17.206499+0800 KTVHTTPCache[9962:2764843] KTVHCHTTPResponse       :   0x280a09200, Read data did finished
2023-01-17 10:35:17.206619+0800 KTVHTTPCache[9962:2764843] KTVHCHTTPResponse       :   0x280a09200, Connection did closed : 2, 2
2023-01-17 10:35:17.206659+0800 KTVHTTPCache[9962:2764843] <KTVHCHTTPResponse: 0x280a09200>  :   dealloc
2023-01-17 10:35:17.206685+0800 KTVHTTPCache[9962:2764843] <KTVHCDataReader: 0x282147cd0>  :   dealloc
2023-01-17 10:35:17.206709+0800 KTVHTTPCache[9962:2764843] KTVHCDataReader         :   0x282147cd0, Destory reader
Error : (null)
readOffset : 2
2023-01-17 10:35:17.206733+0800 KTVHTTPCache[9962:2764843] <KTVHCDataSourceManager: 0x282e74cc0>  :   dealloc
2023-01-17 10:35:17.208783+0800 KTVHTTPCache[9962:2764843] KTVHCDataReader         :   0x282e74cc0, Destory reader
Error : (null)
currentSource : (null)
currentNetworkSource : (null)
2023-01-17 10:35:17.209212+0800 KTVHTTPCache[9962:2764843] <KTVHCDataFileSource: 0x282178310>  :   dealloc
2023-01-17 10:35:17.209304+0800 KTVHTTPCache[9962:2764843] <KTVHCDataResponse: 0x28291d2c0>  :   dealloc
2023-01-17 10:35:17.209330+0800 KTVHTTPCache[9962:2764843] <KTVHCDataRequest: 0x2804ddc20>  :   dealloc
```

- [iOS 视频缓存KTVHTTPCache原理和实现](https://www.jianshu.com/p/7daec9ce6390)

```txt
目前iOS端比较常见的视频缓存的实现方式主要有两种：
1、使用iOS自带的AVURLAsset的AVAssetResourceLoader来实现。
2、在客户端搭建local服务器，local服务器作为中间者，代替客户端请求服务器数据，并将获取到的数据缓存，再提供给客户端。
我们项目里使用的是KTVHTTPCache来实现视频缓存，KTVHTTPCache的实现方式就是第二种，项目地址：(https://github.com/ChangbaDevs/KTVHTTPCache)。
```

## 低代码逻辑

1. 配置xml项目，Tomcat启动服务，iOS APP 加载服务接口，解析配置内容，获取对象及界面相关数据
2. 配置内容->对象及界面相关数据，数据流转代码逻辑

### 外层涉及业务

1. 组件JSON处理Map（UIJSONHandlerMap）、组件JSON处理器（MetaVideoPlayerJSONHandler）
2. 组件属性JSON处理器Map（PropertiesJSONHandlerMap）、组件属性JSON处理器（MetaVideoPlayerPropertiesJSONHandler）
3. 元组件工厂（MetaComponentFactory）、元组件（MetaVideoPlayer）、元组件属性（MetaVideoPlayerProperties）
4. 组件构建器Map（UIBuilderMap）、组件构建器（VideoPlayerBuilder）、组件（VideoPlayer）
5. 视图组件（VideoPlayerImpl）、组件行为器（VideoPlayerBehavior）

### 中层涉及职责
 
1. 组件JSON处理Map（UIJSONHandlerMap）
2. 组件属性JSON处理器Map（PropertiesJSONHandlerMap）
3. 元组件工厂（MetaComponentFactory）
4. 组件构建器Map（UIBuilderMap）
5. EditColumnToMetaCompFactory（编辑列元组件工厂）、GridCellToMetaCompFactory（网格元组件工厂）、ListColumnToMetaCompFactory（列表列元组件工厂）：支持明细控件中装配该组件

## 底层涉及解析？？

大胆猜测，类似 Java 框架 Spring 中将 xml 配置解析工作，主要涉及 配置的加载、词法分析、词法匹配、赋值给构建对象和属性，此类工作等等...

这部分核心底层逻辑，需要结合 Java 服务端源码、Andriod 客户端源码、Web 前端源码相互对照进一步验证。