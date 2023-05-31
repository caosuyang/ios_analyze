## Category

1. Category 表示分类或者类别，用于为已经存在的类添加方法，可以在不修改原来类的基础上，为一个类扩展方法。
3. Category 是拥有 .h 文件和 .m 文件的类。
4. Category 只能添加对象方法、类方法、协议、属性，Category 添加的属性不会生成成员变量，只会生成 get 方法、set 方法的声明，需要自己去实现。
5. Category 是在运行时，才会将数据合并到类信息中。

## Class Extension

1. Class Extension 表示类扩展，用于给某个类附加额外的属性、成员变量、方法声明。
3. Extension 只存在于一个 .h 文件中，或者只存在于一个类的 .m 文件中，Extension 一般写到 .m 文件中，作为私有属性、成员变量、方法声明。
4. Extension 除了方法、协议、属性，还能添加成员变量。
5. Extension 在编译的时候，它的数据就已经包含在类信息中。

## Category 使用场景

1. 一般用于为已经存在的类添加方法，可以在不修改原来类的基础上，为一个类扩展方法。
2. 最主要的应用：给系统自带的类扩展方法，比如 UIView、NSString 等。

## Category 和 Class Extension 区别

1. 表现形式不同：Category 是拥有 .h 文件和 .m 文件的类；而 Extension 只存在于一个 .h 文件中，或者只存在于一个类的 .m 文件中，Extension 一般写到 .m 文件中，作为私有属性、成员变量、方法声明。
2. 用法限制不同：Category 只能添加对象方法、类方法、协议、属性，Category 添加的属性不会生成成员变量，只会生成 get 方法、set 方法的声明，需要自己去实现。Extension 除了方法、协议、属性，还能添加成员变量。
3. 原理机制不同：Category 是在运行时，才会将数据合并到类信息中。lass Extension在编译的时候，它的数据就已经包含在类信息中。

## Category 底层结构

1. Category 编译之后的底层结构是 struct category_t，里面存储着分类的对象方法、类方法、属性、协议信息。
2. struct category_t 定义在 objc-runtime-new.h 中，下载 [objc4](https://github.com/apple-oss-distributions/objc4/tags) 源码进行查看。
3. 代码如下：

```objective-c
/// Category 底层结构
struct category_t {
    const char *name;
    classref_t cls;
    // 对象方法
    WrappedPtr<method_list_t, method_list_t::Ptrauth> instanceMethods;
    // 类方法
    WrappedPtr<method_list_t, method_list_t::Ptrauth> classMethods;
    // 协议
    struct protocol_list_t *protocols;
    // 对象属性
    struct property_list_t *instanceProperties;
    // Fields below this point are not always present on disk.
    // 类属性
    struct property_list_t *_classProperties;

    method_list_t *methodsForMeta(bool isMeta) {
        if (isMeta) return classMethods;
        else return instanceMethods;
    }

    property_list_t *propertiesForMeta(bool isMeta, struct header_info *hi);

    protocol_list_t *protocolsForMeta(bool isMeta) {
        if (isMeta) return nullptr;
        else return protocols;
    }
};
```

## Category 加载处理过程

1. 在程序运行的时候，Runtime 会将 Category 的数据，合并到类信息中（类对象、元类对象中）
	1. 通过 Runtime 加载某个类的所有 Category 数据。
	2. 把所有 Category 的方法、属性、协议数据，合并到一个大数组中。后面参与编译的 Category 数据，会在数组的前面。
	3. 将合并后的分类数据（方法、属性、协议），插入到类原来数据的前面
2. Category 加载处理过程定义在 objc-os.mm 和 objc-runtime-new.mm 中，下载 [objc4](https://github.com/apple-oss-distributions/objc4/tags) 源码进行查看。
3. 源码解读如下：

```objective-c
// objc-os.mm
_objc_init // 1. 初始化objc结构
map_images // 2. 解析和处理可执行文件内容
map_images_nolock // 3. 不加锁解析和处理

// objc-runtime-new.mm
_read_images // 4. 读取可执行文件内容
remethodizeClass // 5. 重方法化Objc类
attachCategories // 6. 附加分类
attachLists // 7. 附加方法、属性、协议列表
realloc、memmove、 memcpy // 8. 内存分配、移动、拷贝
```

4. Category 加载处理过程，也是 APP的启动时 runtime 所做的事情，针对这块可以在 runtime 阶段进行 APP 的启动优化。

## Category 实现原理

1. Category 编译之后的底层结构是 struct category_t，里面存储着分类的对象方法、类方法、属性、协议信息
2. 在程序运行的时候，runtime 会将 Category 的数据，合并到类信息中（类对象、元类对象中）

## +load 方法

1. +load 方法会在 runtime 加载类、分类时调用
2. 每个类、分类的 +load，在程序运行过程中只调用一次
3. 调用顺序：先调用类的 +load
	1. 按照编译先后顺序调用（先编译，先调用）
	2. 调用子类的 +load 之前会先调用父类的 +load
4. 再调用分类的 +load，按照编译先后顺序调用（先编译，先调用）
5. objc4 源码解读过程：objc-os.mm

```objective-c
// objc4源码解读过程：objc-os.mm
_objc_init // 1. 初始化objc结构

load_images // 2. 在load_images中调用call_load_methods，调用所有Class和Category的+load方法

prepare_load_methods // 3. 预加载所有Class和Category的+load方法
	schedule_class_load
	add_class_to_loadable_list
	add_category_to_loadable_list

call_load_methods // 4. 调用所有Class和Category的+load方法
	call_class_loads
	call_category_loads
	(*load_method)(cls, SEL_load) // 5. 根据方法地址直接调用+load 方法
```

6. 由 `(*load_method)(cls, SEL_load)` 可知，+load 方法是根据方法地址直接调用，并不是经过 objc_msgSend 函数调用

## +initialize 方法

1. +initialize 方法会在类第一次接收到消息时调用
2. 调用顺序：先调用父类的 +initialize，再调用子类的 +initialize (先初始化父类，再初始化子类，每个类只会初始化1次)
3. objc4 源码解读过程：

```objective-c
// objc-msg-arm64.s
objc_msgSend // 1. objc_msgSend

// objc-runtime-new.mm
class_getInstanceMethod // 1. 获取类中的对象方法
lookUpImpOrNil // 2.查找方法实现1
lookUpImpOrForward // 3. 查找方法实现2
_class_initialize // 4. 类初始化
callInitialize // 5. 调用initialize方法
objc_msgSend(cls, SEL_initialize) // 6. objc_msgSend
```

4. 由 `objc_msgSend(cls, SEL_initialize)` 可知，+initialize 是通过 objc_msgSend 进行调用的

## +load 方法 和 +initialize 方法区别

1. +initialize 和 +load 的很大区别是，+initialize 是通过 objc_msgSend 进行调用的，所以有以下特点：
	1. 如果子类没有实现 +initialize，会调用父类的 +initialize（所以父类的 +initialize 可能会被调用多次）
	2. 如果分类实现了 +initialize，就覆盖类本身的 +initialize 调用
2. 在 APP 启动的 runtime 阶段，用 +initialize 方法和 dispatch_once 取代所有的 __attribute__((constructor))、C++ 静态构造器、ObjC 的 +load 方法，可以减少 APP 启动耗时

## Category中有load方法吗？load方法是什么时候调用的？load 方法能继承吗？

1. 有load方法
2. load方法在runtime加载类、分类的时候调用
3. load方法可以继承，但是一般情况下不会主动去调用load方法，都是让系统自动调用

## load、initialize方法的区别什么？它们在category中的调用的顺序？以及出现继承时他们之间的调用过程？

1. +initialize 和 +load 的很大区别是，+initialize 是通过 objc_msgSend 进行调用的
2. +load 调用顺序：先调用类的 +load
	1. 按照编译先后顺序调用（先编译，先调用）
	2. 调用子类的 +load 之前会先调用父类的 +load
3. 再调用分类的 +load，按照编译先后顺序调用（先编译，先调用）
4. +initialize 调用顺序：先调用父类的 +initialize，再调用子类的 +initialize (先初始化父类，再初始化子类，每个类只会初始化1次)

## Category能否添加成员变量？如果可以，如何给Category添加成员变量？

1. 不能直接给Category添加成员变量，但是可以间接实现Category有成员变量的效果
2. 默认情况下，因为分类底层结构的限制，不能添加成员变量到分类中。但可以通过关联对象来间接实现

## 如何给 Category 添加成员变量

1. 不能直接给Category添加成员变量，但是可以间接实现Category有成员变量的效果
2. 默认情况下，因为分类底层结构的限制，不能添加成员变量到分类中。但可以通过关联对象来间接实现

## 关联对象的原理

1. 实现关联对象技术的核心对象有
	- AssociationsManager
	- AssociationsHashMap
	- ObjectAssociationMap
	- ObjcAssociation
2. objc4源码解读：objc-references.mm

```objective-c
/// AssociationsManager
class AssociationsManager {
	// AssociationsHashMap
    AssociationsHashMap &get() {
        return _mapStorage.get();
    }
};

/// ObjectAssociationMap
typedef DenseMap<const void *, ObjcAssociation> ObjectAssociationMap;

/// AssociationsHashMap
typedef DenseMap<DisguisedPtr<objc_object>, ObjectAssociationMap> AssociationsHashMap;

/// ObjcAssociation
class ObjcAssociation {
    uintptr_t _policy;
    id _value;
};
```

3.  调用添加关联对象 API：

```objective-c
/// 添加关联对象
void objc_setAssociatedObject(id object, const void * key,
                                id value, objc_AssociationPolicy policy)
```

4. 调用添加关联对象 API 内部原理：
	1. 在全局的统一的一个AssociationsManager中存储关联对象 AssociationsHashMap。
	2. 关联对象 AssociationsHashMap 中存储 DisguisedPtr<objc_object>、ObjectAssociationMap 的键值对，DisguisedPtr<objc_object> 是添加接口中传入的 id object 参数。
	3. ObjectAssociationMap 中存储 const void *、ObjcAssociation 的键值对，const void * 是添加接口中传入的 const void * key 参数。
	4. ObjcAssociation 是一个 struct，内部存储 uintptr_t _policy、id _value，分别对应着添加接口中传入的 objc_AssociationPolicy policy 参数、id value 参数。
5. 总结：关联对象并不是存储在被关联对象本身内存中，关联对象存储在全局的统一的一个AssociationsManager中。
6. 设置关联对象为nil，就相当于是移除关联对象。

## 关联对象使用场景

1. 给 Category 添加成员变量
2. 具体应用：YesAPI SDK 项目，利用给分类添加成员变量，实现对上层业务组件 CSS 样式属性的处理
3. 代码如下：

```objective-c
// 使用属性名作为key
static const NSString* attrsMapKey = @"attrsMap";

- (AttrsMap *)attrsMap{
    return objc_getAssociatedObject(self, (__bridge const void * _Nonnull)(attrsMapKey)); // 获得关联对象
}

- (void)setAttrsMap:(AttrsMap *)attrsMap{
    objc_setAssociatedObject(self, (__bridge const void * _Nonnull)(attrsMapKey),attrsMap, OBJC_ASSOCIATION_RETAIN_NONATOMIC); // 添加关联对象
    [self loadThemeByControlState:UIControlStateNormal];
}

-(void)loadThemeByCSSState:(CSSStateType)state{
    [ComponentTheme applyViewFormatByAttrsMapWithDefBoder:self state:state attrsMap:self.attrsMap iMetaBorder:[self defaultBorder]];
}
```

## CategoryDemo 和 objc

1. 上面示例 demo 放置在 CategoryDemo
2. objc 源码 见 objc4-objc4-866.9

