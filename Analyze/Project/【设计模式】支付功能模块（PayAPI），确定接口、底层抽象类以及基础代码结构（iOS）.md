## 配置说明

- 支付：支付功能，支持微信和支付宝，3.1.0sp4版本开始，支持。需要依赖yespaylibrary。在3.1.0sp8版本之前，如果需要微信支付功能，打包时，需要在打包工程AndroidMainfest的application节点中添加如下配置：

```xml
<activity-alias
    android:name="${applicationId}.wxapi.WXPayEntryActivity"
    android:exported="true"
    android:targetActivity="com.bokesoft.yesapp.wxapi.WXPayEntryActivity" />
<activity-alias
    android:name="${applicationId}.wxapi.WXEntryActivity"
    android:exported="true"
    android:targetActivity="com.bokesoft.yesapp.wxapi.WXEntryActivity" />
```
<activity-alias
    android:name="${applicationId}.wxapi.WXPayEntryActivity"
    android:exported="true"
    android:targetActivity="com.bokesoft.yesapp.wxapi.WXPayEntryActivity" />
<activity-alias
    android:name="${applicationId}.wxapi.WXEntryActivity"
    android:exported="true"
    android:targetActivity="com.bokesoft.yesapp.wxapi.WXEntryActivity" />

- 3.1.0sp8及之后版本不需要在打包工程AndroidMainfest的application节点中添加如上配置（3.1.0sp8版本开始，已在yespaylibrary集成如上配置，不用额外添加）。

## 版本说明

version：1.0

## 项目结构

    |-- YESPayAPI
       |-- README.md
       |-- YESPayAPI
           |-- Interface 界面
              |-- PayResult 支付结果
              |-- NativePay Native支付
              |-- AppPay APP支付
           |-- Pay 支付（核心）
              |-- Model 模型类
              |-- Service 服务类
           |-- Request 请求
              |-- Model 模型类
              |-- Service 服务类
           |-- Tools 工具类
           |-- Macros 宏定义
           |-- Function 函数
           |-- Proxy 代理
           |-- Vendor 第三方框架
              |-- STPopup
           |-- Resources 图片资源
           |-- Libs 库文件
              |-- WXPaySDK 微信支付
              |-- AlipaySDK 支付宝支付
           |-- Utils 帮助类

## API 接口

```objc
// 支付模块
// 获取支付信息
1、getPaymentInfo的请求参数：
service------"InvokeService"
cmd----------"InvokeExtService2"
extSvrName---"PaymentService"
paras--------paraJSONObject.toString
  

paraJSONObject里的参数为：
cmdName-----GetPaymentInfo
appKey------程序的包名，IOS的bundleID，Android的applicationId

// 支付订单生成
2、createPayOrder的请求参数：
service------"InvokeService"
cmd----------"InvokeExtService2"
extSvrName---"PaymentService"
paras--------paraJSONObject.toString


paraJSONObject里的参数为：
cmdName------CreatePayOrder
type---------支付类型，目前传字符串：WeChat、Alipay
appKey-------程序的包名，IOS的bundleID，Android的applicationId
outTradeNo-----付款订单号，公式传进来的第一个参数
totalFee-----付款金额，公式传进来的第二个参数
body---------付款信息，公式传进来的第三个参数
notifyUrl----支付后的回调请求地址，app请求的主地址+”/PayNotify“

// 退款
3、refund的请求参数：
service------"InvokeService"
cmd----------"InvokeExtService2"
extSvrName---"PaymentService"
paras--------paraJSONObject.toString


paraJSONObject里的参数为：
cmdName------Refund
type---------支付类型，目前传字符串：WeChat、Alipay
appKey-------程序的包名，IOS的bundleID，Android的applicationId
outTradeNo-----付款订单号，公式传进来的第一个参数
totalFee-----付款金额，公式传进来的第二个参数
refundFee---------退款金额，公式传进来的第三个参数 

// 支付结果验证
4、confirmPayResult的请求参数：
service------"InvokeService"
cmd----------"InvokeExtService2"
extSvrName---"PaymentService"
paras--------paraJSONObject.toString

paraJSONObject里的参数为：
cmdName------PayResult
transactionSn-----支付编号


// 发票模块
// 获取发票渠道信息
5、getInvoiceInfo的请求参数：
service------"InvokeService"
cmd----------"InvokeExtService2"
extSvrName---"InvoicementService"
paras--------paraJSONObject.toString
  

paraJSONObject里的参数为：
cmdName-----GetInvoiceInfo
type---------发票渠道类型，目前传字符串：WeChat、Alipay
appKey------程序的包名，IOS的bundleID，Android的applicationId

返回的参数为：
appId------微信开发者ID
universalLink------微信开发者Universal Link

scheme------业务回跳当前app的scheme
einvMerchantId------企业标志，字段唯一，需传入配置申请表中提供的税号
isvUrl------报销应用发票输出接收地址（与申请表中发票输出接收地址一致）

// 获取发票要素列表
6、getInvoiceElementList的请求参数：
service------"InvokeService"
cmd----------"InvokeExtService2"
extSvrName---"InvoicementService"
paras--------paraJSONObject.toString


paraJSONObject里的参数为：
cmdName------GetInvoiceElementList
type---------支付类型，目前传字符串：WeChat、Alipay
appKey-------程序的包名，IOS的bundleID，Android的applicationId
token-------查询请求令牌。通过唤起支付宝钱包后用户进入发票管家选择发票列表后创建，并通过isv接收url回传给isv。详见 "选"模式发票报销。

返回的参数为：
invoiceElementList------发票要素列表
```

## 基础代码结构

如下图所示：

![[支付 PayAPI.png]]

## 聚合支付

简单梳理一下聚合支付的业务：

- 需要对接多个支付渠道
- 所有的支付能够兼容任意渠道
- 所有的退款能够兼容任何渠道
- 任何渠道都能需要独立进行配置
- 任何渠道都有统计功能
- 渠道之间能够无缝进行切换（比如某个渠道奔溃了，能够切换到其他渠道）

如果想满足上面的功能，又不影响原有的业务的情况下，就需要将原有的支付模块独立抽离开来，单独作为一个服务，也就是聚合支付，凡是项目里面的任何支付、退款、查询、统计等都要通过聚合支付来处理。

## 设计模式

要怎么设计呢？考虑到由于涉及到多个支付渠道，首先工厂模式跑不了，一个支付渠道可以看成一个工厂；此外单例模式也要用到，支付的配置是固定的，没必要重复 new 创建；还要适配器模式，由于不同的支付渠道使用的参数或者返回结果都可能不一样，适配器就派上用场了；此外还有策略模式，比如你要根据什么依据创建支付渠道进行支付。

- 工厂模式
- 单例模式
- 适配器模式
- 策略模式

![[支付 PayAPI 设计模式.png]]

### 工厂模式

工厂模式：这种类型的设计模式属于创建型模式，它提供了一种创建对象的最佳方式。在工厂模式中，我们在创建对象时不会对客户端暴露创建逻辑，并且是通过使用一个共同的接口来指向新创建的对象。

好处：

- 一个调用者想创建一个对象，只要知道其名称就可以了
- 扩展性高，如果想增加一个产品，只要扩展一个工厂类就可以
- 屏蔽产品的具体实现，调用者只关心产品的接口

为什么用工厂模式呢？由于支付渠道很多，而且不同的支付渠道其实是有共性的，比如：支付、回调、查询、退款、退款查询等。把这些共同的东西抽出来当成一个 IPayChannel 接口，任何支付渠道都需要实现这个接口。

接着上面的聚合支付，使用工厂模式可以将所有的支付渠道抽出一个模型出来，把它们的共同点全部封装成一个接口，不同的支付渠道都需要实现这个接口。

之前代码如下：

```objc
/*! @brief 支付类型
 *
 */
typedef NS_ENUM(NSUInteger, PayType) {
    PayType_Alipay = 0,      //**< 支付宝支付  */
    PayType_WXPay = 1,       //**< 微信支付  */
    PayType_NativePay = 2    //**< Native支付  */
};
```

重构代码如下：


```objc
// IPayChannelFactory
typedef void(^PayResult)(BOOL success, NSInteger statusCode, NSDictionary *resultDic);

/// 支付渠道抽象工厂
@protocol IPayChannelFactory <NSObject>

/// 支付订单，传入订单信息，支付结果回调
/// @param orderInfo 订单信息
/// @param payResult 支付结果
- (void)payOrder:(id)orderInfo callback:(PayResult)payResult;

/// 处理三方客户端通过URL启动App时传递的数据
/// @param url URL
- (BOOL)handleOpenURL:(NSURL *)url;
@end

// BasePayChannelFactory
@implementation BasePayChannelFactory

- (BOOL)handleOpenURL:(nonnull NSURL *)url {
    return NO;
}

- (void)payOrder:(nonnull id)orderInfo callback:(nonnull PayResult)payResult {
    self.payResult = payResult;
}

@end

// AlipayChannelFactory
#import "AlipayChannelFactory.h"
#import <AlipaySDK/AlipaySDK.h>
#import "YESOrderInfo.h"
@implementation AlipayChannelFactory

- (BOOL)handleOpenURL:(nonnull NSURL *)url {
    // 跳转到支付宝APP支付的回传结果
    if ([url.host isEqualToString:@"safepay"]) {
        // 处理支付宝app支付后跳回商户app携带的支付结果Url
        [[AlipaySDK defaultService] processOrderWithPaymentResult:url standbyCallback:^(NSDictionary *resultDic) {
            // 结果码
            // https://opendocs.alipay.com/open/204/105302
            NSInteger statusCode = [resultDic[@"resultStatus"] integerValue];
            // 订单支付成功
            // 正在处理中，支付结果未知（有可能已经支付成功），请查询商户订单列表中订单的支付状态
            // 支付结果未知（有可能已经支付成功），请查询商户订单列表中订单的支付状态
            if (statusCode == ResultStatus_Success
                || statusCode == ResultStatus_Process
                || statusCode == ResultStatus_Unknown) {
                self.payResult(YES, statusCode, resultDic);
            } else {
                self.payResult(NO, statusCode, resultDic);
            }
        }];
    }
    
    // 跳转到支付宝网页版支付的回传结果
    if ([url.host isEqualToString:@"platformapi"]) {
        // 处理支付宝app授权后跳回商户app携带的授权结果Url
        [[AlipaySDK defaultService] processAuthResult:url standbyCallback:^(NSDictionary *resultDic) {
            // 结果码
            // https://opendocs.alipay.com/open/204/105302
            NSInteger statusCode = [resultDic[@"resultStatus"] integerValue];
            // 订单支付成功
            // 正在处理中，支付结果未知（有可能已经支付成功），请查询商户订单列表中订单的支付状态
            // 支付结果未知（有可能已经支付成功），请查询商户订单列表中订单的支付状态
            if (statusCode == ResultStatus_Success
                || statusCode == ResultStatus_Process
                || statusCode == ResultStatus_Unknown) {
                self.payResult(YES, statusCode, resultDic);
            } else {
                self.payResult(NO, statusCode, resultDic);
            }
        }];
    }
    return NO;
}

- (void)payOrder:(nonnull YESOrderInfo *)orderInfo callback:(nonnull PayResult)payResult {
    [super payOrder:orderInfo callback:payResult];
    [[AlipaySDK defaultService] payOrder:orderInfo.orderString fromScheme:orderInfo.scheme callback:^(NSDictionary *resultDic) {
        // 跳转到支付宝网页版支付的回传结果
        // 结果码
        // https://opendocs.alipay.com/open/204/105302
        NSInteger statusCode = [resultDic[@"resultStatus"] integerValue];
        // 订单支付成功
        // 正在处理中，支付结果未知（有可能已经支付成功），请查询商户订单列表中订单的支付状态
        // 支付结果未知（有可能已经支付成功），请查询商户订单列表中订单的支付状态
        if (statusCode == ResultStatus_Success
            || statusCode == ResultStatus_Process
            || statusCode == ResultStatus_Unknown) {
            self.payResult(YES, statusCode, resultDic);
        } else {
            self.payResult(NO, statusCode, resultDic);
        }
    }];
}
@end

// WXChannelFactory
#import "WXChannelFactory.h"
#import <WXSDK/WXSDK.h>
#import "YESOrderInfo.h"
@interface WXChannelFactory ()<WXApiDelegate>

@end
@implementation WXChannelFactory

- (BOOL)handleOpenURL:(nonnull NSURL *)url {
    // 处理旧版微信通过URL启动App时传递的数据
    [WXApi handleOpenURL:url delegate:self];
    return NO;
}

- (void)payOrder:(nonnull YESOrderInfo *)orderInfo callback:(nonnull PayResult)payResult {
    [super payOrder:orderInfo callback:payResult];
    // 第三方向微信终端发起支付的消息结构体
    PayReq *req = [[PayReq alloc] init];
    // 由用户微信号和AppID组成的唯一标识，需要校验微信用户是否换号登录时填写
    req.openID = orderInfo.openID;
    // 商家向财付通申请的商家id
    req.partnerId = orderInfo.partnerId;
    // 预支付订单
    req.prepayId = orderInfo.prepayId;
    // 随机串，防重发
    req.nonceStr = orderInfo.nonceStr;
    // 时间戳，防重发
    req.timeStamp = orderInfo.timeStamp;
    // 商家根据财付通文档填写的数据和签名
    req.package = orderInfo.package;
    // 商家根据微信开放平台文档对数据做的签名
    req.sign = orderInfo.sign;
    // 发送请求到微信，等待微信返回onResp
    [WXApi sendReq:req completion:nil];
}

#pragma mark - WXApiDelegate
- (void)onResp:(BaseResp *)resp {
    // 处理微信支付回调
    if ([resp isKindOfClass:[PayResp class]]) {
        // 微信终端返回给第三方的关于支付结果的结构体
        PayResp *response = (PayResp *)resp;
        // 结果字典
        // returnKey：财付通返回给商家的信息
        // errCode：错误码
        // errStr：错误提示字符串
        // type：响应类型
        NSDictionary *resultDic = @{@"returnKey": response.returnKey,
                                    @"errCode": @(response.errCode),
                                    @"errStr": (response.errStr != nil ? response.errStr : @"errStr is nil"),
                                    @"type": @(response.type)};
        // 错误码
        if (resp.errCode == WXSuccess) {
            self.payResult(YES, response.errCode, resultDic);
        } else {
            self.payResult(NO, response.errCode, resultDic);
        }
    }
}
@end
```

### 单例模式

单例模式：这种类型的设计模式属于创建型模式，它提供了一种创建对象的最佳方式。这种模式涉及到一个单一的类，该类负责创建自己的对象，同时确保只有单个对象被创建。这个类提供了一种访问其唯一的对象的方式，可以直接访问，不需要实例化该类的对象。

好处：

- 在内存里只有一个实例，减少了内存的开销，尤其是频繁的创建和销毁实例
- 避免对资源的多重占用

对接过支付的人都知道，调用任何一个接口都需要用特定的支付配置，比如公钥、私钥、计算签名的key、请求接口、回调验签的key等，这种配置类型的参数，我们可以抽出来当成一个单例类，避免每一次支付都频繁创建和销毁，减少内存开支。

比如可以把某个支付渠道 A 的配置参数抽出来，当成一个 AChannelConfig。

之前代码如下：

```objc
/// 创建支付单例服务
+ (nonnull instancetype)defaultService {
    static YESPayService *service = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        service = [[YESPayService alloc] init];
    });
    return service;
}
```

重构代码如下：

```objc
// IChannelConfig
/// 支付渠道抽象配置
@protocol IChannelConfig <NSObject>

@required
/// 创建支付配置单例服务
+ (instancetype)defaultService;

@optional
/// 向微信终端注册第三方应用
/// @param appid 微信开发者ID
/// @param universalLink 微信开发者Universal Link
+ (BOOL)registerApp:(NSString *)appid universalLink:(NSString *)universalLink;

/// 检查微信会否已被用户安装
+ (BOOL)isWXAppInstalled;


/// 商户程序注册的 URL protocol，供支付完成后回调商户程序使用
@property (nonatomic, copy) NSString *scheme;
/// 应用ID，微信开放平台审核通过的应用APPID
@property (nonatomic, copy) NSString *appId;
/// 微信开发者Universal Link
@property (nonatomic, copy) NSString *universalLink;


/// 二开服务
/// 请求参数
/// service------"InvokeService"
@property (nonatomic, copy) NSString *invokeService;
/// cmd----------"InvokeExtService2"
@property (nonatomic, copy) NSString *invokeExtService2;
/// extSvrName---"PaymentService"
@property (nonatomic, copy) NSString *paymentService;

/// paraJSONObject里的参数
/// cmdName-----GetPaymentInfo
@property (nonatomic, copy) NSString *getPaymentInfo;
/// cmdName------CreatePayOrder
@property (nonatomic, copy) NSString *createPayOrder;
/// cmdName------Refund
@property (nonatomic, copy) NSString *refund;
/// cmdName------PayResult
@property (nonatomic, copy) NSString *payResult;

/// notifyUrl----支付后的回调请求地址，app请求的主地址+”/PayNotify“
@property (nonatomic, copy) NSString *payNotify;
@end

// BaseIChannelConfig
@implementation BaseIChannelConfig

+ (nonnull instancetype)defaultService {
    return nil;
}
@end

// AlipayChannelConfig
@implementation AlipayChannelConfig
+ (nonnull instancetype)defaultService {
    static AlipayChannelConfig *service = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        service = [[AlipayChannelConfig alloc] init];
    });
    return service;
}
@end

// WXChannelConfig
#import "WXChannelConfig.h"
#import <WXSDK/WXSDK.h>
@implementation WXChannelConfig
+ (nonnull instancetype)defaultService {
    static WXChannelConfig *service = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        service = [[WXChannelConfig alloc] init];
    });
    return service;
}

+ (BOOL)isWXAppInstalled {
    // 检查微信是否已被用户安装
    return [WXApi isWXAppInstalled];
}

+ (BOOL)registerApp:(nonnull NSString *)appid universalLink:(nonnull NSString *)universalLink {
    // WXApi的成员函数，向微信终端程序注册第三方应用
    BOOL success = [WXApi registerApp:appid universalLink:universalLink];
    return success;
}
@end

// ServerConfig
#import "ServerConfig.h"

@implementation ServerConfig
+ (nonnull instancetype)defaultService {
    static ServerConfig *service = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        service = [[ServerConfig alloc] init];
        service.invokeService = @"InvokeService";
        service.invokeExtService2 = @"InvokeExtService2";
        service.paymentService = @"PaymentService";
        service.getPaymentInfo = @"GetPaymentInfo";
        service.createPayOrder = @"CreatePayOrder";
        service.refund = @"Refund";
        service.payResult = @"PayResult";
        service.payNotify = @"/PayNotify";
    });
    return service;
}
@end
```

### 适配器模式

适配器模式：作为两个不兼容的接口之间的桥梁。这种类型的设计模式属于结构型模式，它结合了两个独立接口的功能。这种模式涉及到一个单一的类，该类负责加入独立的或不兼容的接口功能。

好处：

-  可以让任何两个没有关联的类一起运行
-  提高了类的复用
- 增加了类的透明度
- 灵活性好

当你对接的支付渠道多了之后，你会发现，不同的公司的请求参数和返回参数都是不一样的，这种情况下，你就得需要一个适配器，把它们的数据格式进行适配，转化成你自己的格式，后面不管你对接多少个渠道，对你项目来说，只需要处理适配器返回的数据格式就行了，不需要管第三方返回的格式；支付也是类型，你只管把参数传给适配器，由适配器逆向适配即可。

创建一个 PayChannelAdapter，来对支付参数以及返回结果进行适配，这个跟单例类一样需要结合工厂类进行处理。

之前代码如下：

```objc
/// 支付接口，传入订单信息，支付结果回调
/// @param orderInfo 订单信息
/// @param payResult 支付结果
- (void)payOrder:(nonnull YESOrderInfo *)orderInfo callback:(nonnull YESPayResult)payResult {
    // 支付方式
    payType = orderInfo.payType;
    // 支付结果
    self.payResult = payResult;
    
    // 判断支付方式
    if (payType == PayType_Alipay) {
        // 支付宝支付
        // 支付接口
        [[AlipaySDK defaultService] payOrder:orderInfo.orderString fromScheme:orderInfo.scheme callback:^(NSDictionary *resultDic) {
            // 跳转到支付宝网页版支付的回传结果
            // 结果码
            // https://opendocs.alipay.com/open/204/105302
            NSInteger statusCode = [resultDic[@"resultStatus"] integerValue];
            // 订单支付成功
            // 正在处理中，支付结果未知（有可能已经支付成功），请查询商户订单列表中订单的支付状态
            // 支付结果未知（有可能已经支付成功），请查询商户订单列表中订单的支付状态
            if (statusCode == ResultStatus_Success
                || statusCode == ResultStatus_Process
                || statusCode == ResultStatus_Unknown) {
                self.payResult(YES, statusCode, resultDic);
            } else {
                self.payResult(NO, statusCode, resultDic);
            }
        }];
    } else if (payType == PayType_WXPay) {
        // 微信支付
        // 第三方向微信终端发起支付的消息结构体
        PayReq *req = [[PayReq alloc] init];
        // 由用户微信号和AppID组成的唯一标识，需要校验微信用户是否换号登录时填写
        req.openID = orderInfo.openID;
        // 商家向财付通申请的商家id
        req.partnerId = orderInfo.partnerId;
        // 预支付订单
        req.prepayId = orderInfo.prepayId;
        // 随机串，防重发
        req.nonceStr = orderInfo.nonceStr;
        // 时间戳，防重发
        req.timeStamp = orderInfo.timeStamp;
        // 商家根据财付通文档填写的数据和签名
        req.package = orderInfo.package;
        // 商家根据微信开放平台文档对数据做的签名
        req.sign = orderInfo.sign;
        // 发送请求到微信，等待微信返回onResp
        [WXApi sendReq:req completion:nil];
    } else if (payType == PayType_NativePay) {
        // Native支付
    }
}
```

重构代码如下：

```objc
// PayChannelAdapter
//
//  PayChannelAdapter.m
//  YESPayAPI
//
//  Created by csy on 2023/1/13.
//

#import "PayChannelAdapter.h"

@implementation PayChannelAdapter

/// 支付请求
- (void)_requestPayResultWithPayListArray:(NSMutableArray<YESPayList *> *)payListArray {
    // 支付列表数组
    [payListArray enumerateObjectsUsingBlock:^(YESPayList * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        // 选择按钮是否被选择
        if (obj.isSelected) {
            // 支付订单生成
            YESOrderInfo *orderInfo = [self loadApiPayCreatePayOrderWithOutTradeNo:self.outTradeNo totalFee:self.totalFee body:self.body payType:obj.payType];
            // 支付接口，传入订单信息，支付结果回调
            [self _payOrderWithOrderInfo:orderInfo payType:obj.payType];
        }
    }];
}

/// 支付订单生成
/// paraJSONObject里的参数为：
/// cmdName------CreatePayOrder
/// type---------支付类型，目前传字符串：WeChat、Alipay
/// appKey-------程序的包名，IOS的bundleID，Android的applicationId
/// outTradeNo-----付款订单号，公式传进来的第一个参数
/// totalFee-----付款金额，公式传进来的第二个参数
/// body---------付款信息，公式传进来的第三个参数
/// notifyUrl----支付后的回调请求地址，app请求的主地址+”/PayNotify“
/// @param outTradeNo 订单号
/// @param totalFee 在支付界面显示的订单金额
/// @param body 在支付界面显示的订单详情
/// @param payType 支付类型
- (nonnull id)loadApiPayCreatePayOrderWithOutTradeNo:(nullable NSString *)outTradeNo
                                            totalFee:(nullable NSString *)totalFee
                                                body:(nullable NSString *)body
                                             payType:(PayType)payType {
    // paraJSONObject里的参数
    NSMutableDictionary<NSString*, id> *paras = [[NSMutableDictionary<NSString*, id> alloc] init];
    // 程序的包名，IOS的bundleID
    NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    // 支付后的回调请求地址，app请求的主地址+”/PayNotify“
    NSString *notifyUrl = [[ServiceSetting getURL] stringByAppendingFormat:@"%@", kNotifyUrl_PayNotify];
    // cmdName------CreatePayOrder
    [paras put:@"cmdName" Value:kCmdName_CreatePayOrder];
    // appKey------程序的包名，IOS的bundleID，Android的applicationId
    [paras put:@"appKey" Value:bundleIdentifier];
    // outTrade-----付款订单号，公式传进来的第一个参数
    [paras put:@"outTradeNo" Value:outTradeNo];
    // totalFee-----付款金额，公式传进来的第二个参数
    [paras put:@"totalFee" Value:totalFee];
    // subject-----付款金额，公式传进来的第二个参数
    [paras put:@"subject" Value:body];
    // body---------付款信息，公式传进来的第三个参数
    [paras put:@"body" Value:body];
    // notifyUrl----支付后的回调请求地址，app请求的主地址+”/PayNotify“
    [paras put:@"notifyUrl" Value:notifyUrl];
    // type---------支付类型，目前传字符串：WeChat、Alipay
    if (payType == PayType_Alipay) {
        // 支付宝支付
        [paras put:@"type" Value:@"Alipay"];
    } else if (payType == PayType_WXPay) {
        // 微信支付
        [paras put:@"type" Value:@"WeChat"];
    } else if (payType == PayType_NativePay) {
        // Native支付
        [paras put:@"type" Value:@"Native"];
    }
    // 初始化方法
    YESPayRequestService *service = [[YESPayRequestService alloc] initWithEnv:self.env form:self.form paras:paras];
    // 获取支付信息
    id result = [service loadApiPayCreatePayOrderWithOutTradeNo:outTradeNo totalFee:totalFee body:body payType:payType];
    // 强转订单信息
    YESOrderInfo *orderInfo = (YESOrderInfo *)result;
    return orderInfo;
}

/// 支付接口，传入订单信息，支付结果回调
/// @param orderInfo 订单信息
/// @param payType 支付类型
- (void)_payOrderWithOrderInfo:(YESOrderInfo *)orderInfo payType:(PayType)payType {
    if (payType == PayType_NativePay) {
        // Native支付
        // 加载包
        NSBundle *bundle = [YESBundleTool loadBundle];
        YESNativePayViewController *nativePayVC = [[YESNativePayViewController alloc] initWithNibName:@"YESNativePayViewController" bundle:bundle];
        [self.popupController pushViewController:nativePayVC animated:YES];
    } else {
        // 判断支付方式
        if (payType == PayType_Alipay) {
            // 支付宝支付
            AlipayChannelFactory *factory = [PayChannelStrategy createPayChannelFactoryWithOrderInfo:orderInfo payType:payType];
            [factory payOrder:orderInfo callback:^(BOOL success, NSInteger statusCode, NSDictionary * _Nonnull resultDic) {
                    // ...
            }];
            
        } else if (payType == PayType_WXPay) {
            // 微信支付
            WXChannelFactory *factory = [[WXChannelFactory createPayChannelFactoryWithOrderInfo:orderInfo payType:payType];
            [factory payOrder:orderInfo callback:^(BOOL success, NSInteger statusCode, NSDictionary * _Nonnull resultDic) {
                     // ...
            }];
        } else if (payType == PayType_NativePay) {
            // Native支付
            
            
        }
    }
}
@end
```

### 策略模式

 策略模式：一个类的行为或其算法可以在运行时更改。这种类型的设计模式属于行为型模式。在策略模式中，我们创建表示各种策略的对象和一个行为随着策略对象改变而改变的 context 对象。策略对象改变 context 对象的执行算法。

好处： 

- 算法可以自由切换
- 避免使用多重条件判断
- 扩展性良好  

为什么使用策略模式呢？先看下我们的需求，其中有一点说，**渠道之间能够无缝切换**，就是为了避免某个渠道突然出问题不能用了，为了不影响商家正常营业，只能临时帮商家切换到备用的渠道，尽可能减少商家的损失。这种情况主要是对接的支付公司不是特别靠谱导致的，想想也是，规模达到一定程度的公司，费率也都差不多。一般只有新的渠道为了抢占市场份额才会推出低费率，吸引更多的使用者来使用。

前面说了工厂模式 ，不同的支付渠道对应一个工厂，现在问题来了，要怎么创建工厂，谁来创建工厂，这就得用到策略模式了。

创建一个 PayChannelStrategy 类，用来创建对应的支付通道，结合工厂模式效果更佳。

之前代码如下：

```objc
/// 获取支付信息
/// paraJSONObject里的参数为：
/// cmdName-----GetPaymentInfo
/// appKey------程序的包名，IOS的bundleID，Android的applicationId
- (void)loadApiPayGetPaymentInfo {
    // paraJSONObject里的参数
    NSMutableDictionary<NSString*, id> *paras = [[NSMutableDictionary<NSString*, id> alloc] init];
    // 程序的包名，IOS的bundleID
    NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    // cmdName-----GetPaymentInfo
    [paras put:@"cmdName" Value:kCmdName_GetPaymentInfo];
    // appKey------程序的包名，IOS的bundleID，Android的applicationId
    [paras put:@"appKey" Value:bundleIdentifier];
    // 初始化方法
    YESPayRequestService *service = [[YESPayRequestService alloc] initWithEnv:self.env form:self.form paras:paras];
    // 获取支付信息
    id result = [service loadApiPayGetPaymentInfo];
    // 强转支付列表数组
    NSMutableArray<YESPayList *> *payListArray = (NSMutableArray<YESPayList *> *)result;
    // 移除支付列表数组
    [self.payListArray removeAllObjects];
    // 添加元素对象
    [self.payListArray addObjectsFromArray:payListArray];
    // 刷新列表
    [self.tableView reloadData];
    // 遍历支付列表数组
    [self _enumerateObjectsUsingBlockWithPayListArray:self.payListArray];
}

/// 遍历支付列表数组
- (void)_enumerateObjectsUsingBlockWithPayListArray:(NSMutableArray<YESPayList *> *)payListArray {
    // 遍历支付列表数组
    [payListArray enumerateObjectsUsingBlock:^(YESPayList * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        // 判断支付类型
        if (obj.payType == PayType_WXPay) {
            // 微信支付
            // 向微信终端注册第三方应用
            [self _registerApp:obj.appId universalLink:kUniversalLink];
        }
    }];
}
```

重构代码如下：

```objc
// PayChannelStrategy
//
//  PayChannelStrategy.m
//  YESPayAPI
//
//  Created by csy on 2023/1/13.
//

#import "PayChannelStrategy.h"

@implementation PayChannelStrategy

- (BasePayChannelFactory *)createPayChannelFactoryWithOrderInfo:(YESOrderInfo *)orderInfo payType:(PayType)payType {
    // 判断支付方式
    if (payType == PayType_Alipay) {
        // 支付宝支付
        AlipayChannelFactory *factory = [[AlipayChannelFactory alloc] init];
        AlipayChannelConfig * config = [AlipayChannelConfig defaultService];
        config.scheme = orderInfo.scheme;
        return factory;
    } else if (payType == PayType_WXPay) {
        // 微信支付
        WXChannelFactory *factory = [[WXChannelFactory alloc] init];
        WXChannelConfig * config = [WXChannelConfig defaultService];
        config.appId = orderInfo.openID
        config.universalLink = orderInfo.universalLink;
        return factory;
    } else if (payType == PayType_NativePay) {
        // Native支付
        
        
    }
    return nil;
}

/// 获取支付信息
/// paraJSONObject里的参数为：
/// cmdName-----GetPaymentInfo
/// appKey------程序的包名，IOS的bundleID，Android的applicationId
- (void)loadApiPayGetPaymentInfo {
    // paraJSONObject里的参数
    NSMutableDictionary<NSString*, id> *paras = [[NSMutableDictionary<NSString*, id> alloc] init];
    // 程序的包名，IOS的bundleID
    NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    // cmdName-----GetPaymentInfo
    [paras put:@"cmdName" Value:kCmdName_GetPaymentInfo];
    // appKey------程序的包名，IOS的bundleID，Android的applicationId
    [paras put:@"appKey" Value:bundleIdentifier];
    // 初始化方法
    YESPayRequestService *service = [[YESPayRequestService alloc] initWithEnv:self.env form:self.form paras:paras];
    // 获取支付信息
    id result = [service loadApiPayGetPaymentInfo];
    // 强转支付列表数组
    NSMutableArray<YESPayList *> *payListArray = (NSMutableArray<YESPayList *> *)result;
    // 移除支付列表数组
    [self.payListArray removeAllObjects];
    // 添加元素对象
    [self.payListArray addObjectsFromArray:payListArray];
    // 刷新列表
    [self.tableView reloadData];
    // 遍历支付列表数组
    [self _enumerateObjectsUsingBlockWithPayListArray:self.payListArray];
}

/// 遍历支付列表数组
- (void)_enumerateObjectsUsingBlockWithPayListArray:(NSMutableArray<YESPayList *> *)payListArray {
    // 遍历支付列表数组
    [payListArray enumerateObjectsUsingBlock:^(YESPayList * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        // 判断支付类型
        if (obj.payType == PayType_WXPay) {
            // 微信支付
            // 向微信终端注册第三方应用
            [self _registerApp:obj.appId universalLink:kUniversalLink];
        }
    }];
}
@end
```

### 优缺点

先说下优点：

- 代码结构清晰，不同的类处理不同的业务
- 易于扩展，新增一个渠道so easy
- 屏蔽了具体的实现，只需要关心接口即可
- 灵活性高，算法可以自由切换，避免多重判断
- 兼容性高

当然也是有缺点的：

- 由于使用了工厂模式，每多一个渠道就要新增一个文件，当工厂多了就不是什么好事了
- 适配器过多的使用也会造成一定的复杂性，一个类尽量少用或者使用一个适配器
- 策略类多了，也会有膨胀的问题

## 调用流程

1. PayAppDelegateProxy 继承 BaseAppProxy，注册函数实现公式，处理 url 启动 app 时回调函数（ Proxy/YESPayAppDelegateProxy）
2. 在 app 中点击支付按钮，异步执行 Pay 或者 Refund 公式（ Function/YESPayFunction）
3. 异步执行函数实现，通过公式传递的参数 args 获取订单信息后，发起支付操作（ Function/YESPayFunction/PayImpl）
4. 使用支付工具类发起支付操作，内部执行初始化支付vc，传递参数，弹起支付弹窗一系列流程（Utils/YESPayUtil）
5. 第一步初始化支付vc后，首先调用“获取支付信息”接口，刷新ui组件显示支付金额，订单详情，支付方式（Interface/YESAppPayViewController）
6. 选择支付宝支付，点击支付按钮发起支付，首先根据选择的支付方式调用“支付订单生成”接口，生成对应的支付订单（Interface/YESAppPayViewController）
7.  随后，将对应的支付订单信息传入支付服务实现类 PayService，这个过程有三步，传入订单信息，调用第三方提供的支付 api发送给支付平台，最后进行支付结果回调（Pay/YESPayService）
8. 通过 block 方式结果回调回 AppPayViewController，在 callback 中执行下一步逻辑，首先传递支付编号，调用支付结果验证接口，跟自己服务器验证支付结果（Interface/YESAppPayViewController）
9. 根据验证得到的支付结果，判断成功或失败，如果成功则执行支付成功页面逻辑，否则执行失败页面逻辑（Interface/YESAppPayViewController）
10. 如果点击左上角取消支付按钮，则 block 结果回调传递一个支付取消的标志，表示取消支付，执行取消页面逻辑（Interface/YESAppPayViewController）
11. 如果是退款，直接拿公式中取到的退款参数（订单号、付款金额、退款金额），调用申请订单退款接口，回调结果是表示成功或失败的字符串，在 RefundImpl 回调出去，最后执行弹出结果提示框的逻辑（Function/YESPayFunction）
12. 至此，支付和退款调用流程结束

## 参考

- [从聚合支付的设计来谈谈几个设计模式](https://www.cnblogs.com/lyc94620/p/13055116.html)]