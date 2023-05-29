## 支付模块同后台服务交互的功能代码处理（Java）

以下是目录说明：

1、CustomServer
是二次开发的eclipse工程，包含支付的二次开发代码，可以直接在eclipse中加载查看修改。
2、lib
存放支付相关的架包及文件
3、外网穿透
外网穿透工具，提供给内网测试人员

## 支付功能说明

### 一、准备事项

1、支付宝支付：

- 支付宝开发平台注册，接入前准备，具体参考支付宝相关文档，地址为：[https://opendocs.alipay.com/open/204/105297](https://opendocs.alipay.com/open/204/105297)。
- 创建对应应用，获取APPID（应用唯一标识）、PrivateKey（私钥）、PublicKey（公钥）、Scheme（格式为ali+APPID，比如ali2016091901922189）。

2、微信支付

- 微信开放平台注册，接入前准备，具体参考微信支付相关文档，地址为：[https://developers.weixin.qq.com/doc/oplatform/Mobile_App/WeChat_Pay/Vendor_Service_Center.html](https://developers.weixin.qq.com/doc/oplatform/Mobile_App/WeChat_Pay/Vendor_Service_Center.html)
- 微信商户平台注册，具体参考微信商户平台相关指引，地址为：
[https://pay.weixin.qq.com/index.php/apply/applyment_home/guide_normal](https://pay.weixin.qq.com/index.php/apply/applyment_home/guide_normal)
- 应用创建完成，关联商户完成后，获取APPID（应用唯一标识）、ApiKey（支付秘钥）、ParterID（商户ID）、Scheme（等同于APPID）、apiclient_cert.p12证书文件。

## 二、服务器端说明

本章节主要说明后台服务器部署时，针对支付功能需要进行的特殊设置。如若未进行设置，则支付功能将不能正确正常地使用。以下为具体说明：

1、服务器部署时，需要添加必要的文件到webapps\yigo\WEB-INF\lib目录下。主要为：

- Pay_Default.jar（二开打包生成）：该名字只是暂定测试用，具体为项目上二次开发之后导出生成的jar包。该架包主要包含了后台支付功能需要进行处理的代码，具体参考第三章节“必要的服务端二次开发”。
- alipay-sdk-java20161226110022.jar：支付宝支付需要的SDK架包。
- httpclient-4.3.jar：微信支付请求需要的架包。
- httpcore-4.3.jar：微信支付请求需要的架包。

另外需要在Tomcat的目录Tomcat_7.0_x64\lib下添加：

- apiclient_cert.p12：微信支付需要的证书文件。
- YesPayParas.txt：定义支付相关参数的文件，用于定义各个支持支付的app的参数
- TestPayNotifyURL.txt：内部测试用，主要写内网穿透后外网能连接的PayNotify的地址，比如：http://4s8msg.natappfree.cc/yigo/PayNotify。

2、服务器部署时，需要修改webapps\yigo\WEB-INF目录下的web.xml文件，添加：

```xml
<servlet>

<servlet-name>PayNotify</servlet-name>

<servlet-class>com.bokesoft.yespay.servlet.PayNotifyServlet</servlet-class>

</servlet>

<servlet-mapping>

<servlet-name>PayNotify</servlet-name>

<url-pattern>/PayNotify</url-pattern>

<url-pattern>/PayNotify/*</url-pattern>

</servlet-mapping>
```

主要是用于定义PayNotify的servlet服务接收器，用于接收支付后各个支付服务器返回的支付结果信息，然后针对支付结果进行处理。

3、配置根目录下添加Enhance.xml，其中定义支付的二次开发服务：

```xml
<ExtService>

<Service Name="PaymentService" Description="支付服务"

Impl="com.bokesoft.yespay.service.PaymentService"/>

</ExtService>
```

4、数据库中添加Sys_PaymentInfo表，该表包含两个字段：

- TicketCode：varchar（250） 不为NULL      （支付信息标识字段，通常为订单号）
- Data： varchar（8000）  可为NULL       （支付服务器返回的支付结果内容）

## 三、必要的服务端二次开发

1、IParaService的二次开发

目前的二开开发环境中存在了一个测试用YesParaService，该Service需要项目上自行开发，构建一个新的类实现IParaService的接口。该类主要功能是，处理支付静态参数对象IPayParas的来源，可以来源于数据库，可以来源于其他文件等等。

特别说明下，IPayParas静态参数对象，必定存在AppKey及AppID两个属性。

另外，IParaService二次开发后，需要在PaymentService及PayNotifyServlet中通过ParaServiceFactory.setGlobalInstance方法重新注册下，替换掉原来的测试用YesParaService。

2、IPayNotifyProcess的二次开发

该接口主要是提供对支付结果的信息的相关处理，包括校验，转换为参数对象，成功信息传输等。该接口有默认实现，无特殊需要的话，项目上可以不用进行二次开发。

3、IPaymentResultPersistService的二次开发

该接口主要是处理支付结果信息的保存修改和查询。二开环境中的默认实现DefaultPaymentResultPersistService处理了保存到数据库表Sys_PaymentInfo的动作，以及相关的查询删除动作。如若项目上有需要，可自行开发，处理对应的修改保存、查询和删除。

## 四、客户端说明

1、Android端

项目上打包Apk时，注意packageName（包名）是程序的唯一标识，必须同支付平台上创建应用申请AppID时填写的packageName一致，否则会导致无法正确调用对应支付功能。

特别说明：目前二开环境中，所有的支付信息都是同博科公式挂钩。项目上使用时，必定要使用客户申请的账号及创建的对应应用，所以该packageName必定要修改为项目上的具体包名。

2、IOS端

项目上打包IPA时，建立对应的项目壳工程后，需要修改项目属性--Info中的URL Types，填写支付方式对应的urlschema。微信可以是AppID，支付宝是“Ali”+AppID。

## 五、注意事项

1、Android端

1）微信支付，如果无法正确调起微信客户端，请检查以下：

- 应用的包名是否和注册的app的包名一致
- 应用的签名是否和注册的app的签名一致

注意：该签名的获取方式是：通过手机端安装Gen_Signature_Android.apk，输入应 用包名来获取的。

2、IOS端暂无

## 代码结构

yes-webapp-pay 项目

- com.bokesoft.yespay.paraService 参数服务
- com.bokesoft.yespay.service 支付接口服务
- com.bokesoft.yespay.service.payment 支付方式工厂
- com.bokesoft.yespay.service.payment.alipay 支付宝支付
- com.bokesoft.yespay.service.payment.wechat 微信支付
- com.bokesoft.yespay.servlet 支付回调接口
- com.bokesoft.yespay.servlet.process 支付回调处理
- com.bokesoft.yespay.servlet.resultpersist 支付结果回调处理接口、默认的支付结果存储实现

## 设计模式

- 抽象接口
- 工厂模式
- 单例模式
- 适配器模式
- 观察者模式

## 数据库操作

- DefaultPaymentResultPersistService 默认的支付结果存储实现

## 调用流程

1. 首先 PaymentService 继承 IExtService2 类，用于定义被客户端调用的服务
2. 在 PaymentService 类 doCmd 方法中，获取接口请求传过来的 arguments map，从 map 中获取 cmdName
3. 通过判断 cmdName，分别对 GetPaymentInfo、CreatePayOrder、Refund、PayResult 做不同逻辑操作
4. GetPaymentInfo 获取支付信息操作，通过传入的 appkey参数，遍历注册的paymentmap，拿到每个支付类，获取支付配置
5. CreatePayOrder 创建支付订单操作，首先判断支付类型，然后从 arguments map 中取到一系列 string 类型的参数，执行 payment 预支付操作（具体还有细节）
6. Refund 退款操作，通过传入的订单编号，先查询支付结果，查询到支付结果参数对象（数据库查询），执行 payment 退款操作，调用支付三方的接口，拿到回调结果
7. PayResult 支付结果操作，先拿到订单编号，然后从默认支付结果存储实现类中，查询支付结果（其实是数据库查询操作）

## 重要的逻辑

1. AlipayPayment 中 Base64 ，用于签名以及验证签名
2. AlipayPayment 中 OrderInfoUtil，构造授权参数、支付订单参数列表，对支付参数信息进行签名
3. AlipayPayment 中 SignUtils，签名以及验证签名
4. WeChatPayment 中 MD5Util，用于生成签名
5. WeChatPayment 中 WXParam，预支付，支付，退款参数构造方法
6. WeChatPayment 中 WXPayUtil，用于生成随机字符串和签名，组装请求xml和xml的解析工作
7. IPayNotifyProcess，处理支付回调的接口，不同服务不同实现
8. AlipayPayNotifyProcess，支付宝交易完成回调接口的实现
9. WeChatPayNotifyProcess，微信交易完成回调接口的实现
10. IPaymentCallback，支付的回调接口,支付的结果都在这里进行处理
11. PaymentWebListener，继承自ServletContextListener，用于监听处理
12. PayNotifyData，回调回的data数据类
13. PayNotifyServlet，继承自 HttpServlet，用于处理支付后监听三方结果的回调处理，成功后回调 data，失败后回调 errormessage，并将最新的 data 通过 persistService 的 save 操作存到数据库内，以备客户端 app 调用 PayResult 支付结果接口时的 fetch 查询支付结果操作
14. DefaultPaymentResultPersistService，默认的支付结果存储实现，用于支付结果的存，查询，移除一系列数据库操作
15. IPaymentResultPersistService，支付结果回调处理接口（支付结果保存动作、支付结果查询、删除支付结果）

## 支付签名

## 支付结果监听三方

## 支付结果数据库操作
