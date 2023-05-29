## 业务逻辑 

折叠面板（CollapsePanel）
 
```xml
<CollapsePanel Key="" Caption="" Width="" Height="" ... ...> 
    ... ...
    <CollapseItem Key="" Caption="" Icon="" IconLocation="" TextOff="" TextOn="" IsExpand="" Height="" Padding="" CollapseHeight=""  ExpandIcon=""  CollapseIcon="">
        <OnExpand>
            <![CDATA[ShowToast("展开事件")]]> 
        </OnExpand>
        <OnCollapse>
            <![CDATA[ShowToast("收缩事件")]]> 
        </OnCollapse>
        <Format BackColor="" ForeColor="">
            <Font Size="" Bold="" Italic=""/>
        </Format>
        <Component Key="" Caption="" ... ...>
        </Component>
        <Component Key="" Caption="" ... ...>
        </Component>
    </CollapseItem> 
    <CollapseItem Key="" Caption="" Icon="" IconLocation="" TextOff="" TextOn="" IsExpand="" Height="" Padding="" CollapseHeight=""  ExpandIcon=""  CollapseIcon="">
        <OnExpand>
            <![CDATA[ShowToast("展开事件")]]> 
        </OnExpand>
        <OnCollapse>
            <![CDATA[ShowToast("收缩事件")]]> 
        </OnCollapse>
        <Format BackColor="" ForeColor="">
            <Font Size="" Bold="" Italic=""/>
        </Format>
        <Component Key="" Caption="" ... ...>
        </Component>
        <Component Key="" Caption="" ... ...>
        </Component>
    </CollapseItem>
    ... ... 
</CollapsePanel>
```

- 3.1.0sp5版本新增组件，无值。其派生于基础面板，面板相关属性及组件基础属性都支持。
- 其内部标签节点必须为CollapseItem，CollapseItem不是控件，代表折叠项，可以同时存在多个折叠项。
- 折叠项内部可以同时存在最多两个组件：
  - 如果存在一个组件，则这个组件为折叠部分（Body）的内部显示组件；
  - 如果存在两个组件，则第一个组件为折叠项的标题部分（Head）的内部自定义组件，第二个组件为折叠部分（Body）的内部显示组件。
- 如果折叠部分（Body）的内部显示组件不可见，该折叠项也不可见
- 折叠项的标题部分显示分布如下：
- 图标(Left)---Caption---图标(Right)---内部自定义部分---TextOn/TextOff---下拉箭头图标
- 面板自身目前支持以下属性：
  - Type：模式，可选Accordion（手风琴模式，最多张开一个）、Multiple（最多全部展开）。默认为Multiple
- 折叠项（CollapseItem）目前只支持以下属性：
  - Key：折叠项标识
  - Caption：折叠项标题文本，显示在折叠项标题部分的左侧。
  - Icon：折叠项标题部分的显示图标，显示在左侧，同Caption一起。默认在Caption左侧。方位参考IconLocation属性
  - IconLocation：折叠项标题部分的显示图标方位，默认值为Left，目前只支持：Left和Right，代表显示在Caption的左边还是右边。
  - TextOn：折叠项标题部分的右侧在折叠部分展开时的说明文本。
  - TextOff：折叠项标题部分的右侧在折叠部分收缩时的说明文本。
  - IsExpand：是否默认展开，默认值为false，即默认不展开。
  - Height：代表折叠项中标题部分的高度，如果需要设置，目前只支持固定值，即只支持px，dp单位，其他一律作为自适应处理。
  - CollapseHeight：代表折叠项中折叠部分的高度，如果需要设置，目前只支持固定值，即只支持px，dp单位，其他一律作为自适应处理。3.1.0sp8版本新增
  - ExpandIcon：折叠项标题部分的展开图标，显示在右侧，同说明文本一起。默认在说明文本右侧。3.1.0sp8版本新增
  - CollapseIcon：折叠项标题部分的收缩图标，显示在右侧，同说明文本一起。默认在说明文本右侧 。3.1.0sp8版本新增
  - Padding,LeftPadding,TopPadding,RightPadding,BottomPadding：整个折叠项（包括标题部分和折叠部分）的内边距。
  - OnCollapse：收缩事件
  - OnExpand：展开事件
  - BorderWidth,BorderStyle,BorderRadius,BorderColor：整个折叠项（包括标题部分和折叠部分）的边框属性。3.1.0sp8版本新增
  - Format：Format节点。3.1.0sp8版本新增
    - BackColor：折叠项标题部分的背景色。3.1.0sp8版本新增
    - ForeColor,Size,Bold,Italic：折叠项标题部分的标题文本和右边收缩文本的文本属性。3.1.0sp8版本新增

## 折叠面板实现

- 折叠面板，最开始的考虑是创建一个 UITableView 的扩展 使用 swizzleInstanceMethod 交换实例方法
- 核心即 UITableView (FoldableTableView) 和 NSObject (Swizzle) 扩展类
- 这里主要是 swizzleInstanceMethod 这块，需要重点聊
- 缺陷：reloadSections:withRowAnimation 刷新组只能使用 UITableViewRowAnimationFade 等系统定义的动画，无法自定义动画，和业务需要的效果不匹配，后续考虑舍弃 UITableView，改用自定义的 view 组件
- HSFolderCellDemo：使用方法及原理解析见 [链接](https://www.jianshu.com/p/be18aa86f588)
- WWFoldableTableView：[详细介绍](http://www.jianshu.com/p/b83a29d20277)，我这里用的是这个！！

## 折叠面板优化

新增折叠面板的项的样式处理，包括折叠部分高度、标题部分样式

```xml
<CollapsePanel Key="CollapsePanel1" Width="auto" Height="500px" OverflowY="Scroll">
     <CollapseItem Key="Item10" Caption="设置项目标题部分样式" Icon="p3.jpg" IconLocation="Right" Height="50px" CollapseHeight="200px" TextOff="展开" TextOn="收缩"  Padding="5px" BorderStyle="solid" ExpandIcon="close.png" CollapseIcon="open.png">
	<Format BackColor="#1775fb" ForeColor="#ffffff">
		<Font Size="20" Bold="true" Italic="true"/>
	</Format>
        <Label Key="TestTitleCustom10" Caption="测试自定义内容" />
        <LinearLayoutPanel Key="LinearLayoutPanel10" Orientation="Vertical" Padding="5" BorderStyle="solid" BorderRadius="5">
                <Format BackColor="#f0f0f0"/>
                <Label Key="ItemLabel10" Caption="测试项目1的内容10"/>
                <Label Key="ItemLabel10-1" Caption="测试项目1的内容10-1"/>
                <Label Key="ItemLabel10-2" Caption="测试项目1的内容10-2"/>
        </LinearLayoutPanel>
     </CollapseItem>
</CollapsePanel> 
```

1、背景色：标题部分的背景色  
2、前景色：标题部分的Title和右边收缩文本的颜色  
3、字体相关：标题部分的Title和右边收缩文本的字体  
4、边框：整体整个Item项的边框  
5、Height：标题部分的高度  
6、CollapseHeight：收缩展开部分的高度  
7、ExpandIcon：折叠项标题部分的展开图标  
8、CollapseIcon ： 折叠项标题部分的收缩图标

需要注意的：折叠展开部分的根组件，如果自适应，不应该撑满整个展开部分。

这里核心是：组件的自适应，代码逻辑部分，需要梳理一下

## 折叠面板重构

CollapsePanel默认展开且自适应时显示异常，且展开收缩动画不符合要求，现有框架不能实现预想的效果，于是重构。

主要是CollapsePanel自适应异常

改动的核心是：将 UITableView 组件 和 扩展类删除，改动自定义的组件和动画逻辑

![[折叠面板重构.png]]

主要新增 CollapsePanelItemContentImpl、CollapsePanelItemImpl、CollapsePanelItemTitleImpl 这三个类，摒弃了之前的 UITableView，改用 UIScrollView 作为 容器（CollapsePanelItemContentImpl），UIView作为自定义组件（CollapsePanelItemImpl、CollapsePanelItemTitleImpl ）

在 CollapsePanelItemImpl 类中自定义动画，主要是 doExpandAnim 和 doAnim 方法。

## 总结

> 通过思考需求的本质原理，结合OC运行时的特性，让我们以很小的代码量（除去注释150行代码不到），很低的侵入性（仅引用一个头文件，无需继承，正常定义tableView），十分方便的方式（1行代码用于设置tableView）来优雅地实现可折叠TableView。

另外也有一些容易踩到的坑在这里整理一下，如：

1.  使用运行时特性给tableview添加实例对象的时候要处理好关联的类型，不然容易出现超出预期的结果。
2.  设置了某个section的折叠状态后需要及时更新UI，让UI跟状态保持一致。
3.  可以使用`[self reloadSections:[NSIndexSet indexSetWithIndex:section] withRowAnimation:UITableViewRowAnimationFade];`方法来动态刷新某一section，但要注意如果此时其他section的行数变化了（通过代理方法两次获取到的数目不同，在这里其实就是手动修改了折叠状态，但没有刷新tableView）会引起crash。
4.  这种实现方式其实存在一个隐患，由于我们在`+load`方法中替换** 私有实例方法 **，假如苹果对UITableView进行优化或者重构（虽然可能性比较小），导致逻辑变更、方法名有变等情况，就有可能影响到相关逻辑，我们的方法也会不起作用了。所以需要在每个iOS新版本一直对其进行维护，检查方法是否改名或者逻辑是否改变。在旧版本的iOS系统中则只能在代理方法中根据当前section的折叠状态来返回元素个数了。