## 配置说明

选项卡面板(TabPanel)

```xml
<TabPanel Key="" TabPosition="Bottom" TabMode="Fixed" IndicatorHeight="5px" IndicatorColor="#904125" ShowHead="true">
	<Component/>
	...
</TabPanel>
```

- 定义同PC端基本一致。但需要注意的是不建议把所有配置都封装在一个Tab中，不利于后期维护。
- 和平台相比有以下不同：
  - TabPosition：Tab指示器在面板中的位置，默认值为Top，取值范围如下：
  - Top：上方
  -  Bottom：下方
  - TabMode：和TabGroup中相似，为Tab指示器显示样式，默认值为Fixed，取值范围如下：
  - Fixed：固定Tab按钮
  - Scrollable：可左右滚动的Tab按钮，用于Tab按钮很多时
  - IndicatorHeight：和TabGroup中相似，为Tab指示器高度
  - IndicatorColor：和TabGroup中相似，为Tab指示器颜色
  - ShowHead：是否显示Tab指示器，默认值为true
  - ItemChanged：项切换事件，注意只有面板生效，布局TabLayout中该属性无效
  - HoverHead：是否悬停tab头，效果即当TabPanel在可滚动组件内垂直滚动时，tab头悬停不动，默认是false。只在ShowHead为true且TabPosition为top下有效。

## bug 现象

- Mobile_TabPanel_Own_005：界面下滑后切换tab，悬停的tab头消失
- HoverHeadTP：上划列表，tab 头部悬停效果，点击 tab 头上的项，悬停的 tab 头消失

## 定位 bug

1. 切换tab，tab头消失，那么首先要找到切换tab后，tab头去了哪里
2. 那么使用 debug view hierarchy 功能，找到 tab 头对象，然后 print 出 frame（此步骤很重要）

![[TabPanel 组件tab头切换前.png]]

3. 由上图可见，没有切换前，TYTabPagerBar: 0x107f045f0 的 frame = (0 448.5; 414 40)

![[TabPanel 组件tab头切换后.png]]

4. 由上图可见，找到 TYTabPagerBar: 0x10645ff40，打印 frame 得出 frame = (0 0; 414 40)，得知 tab 头部跑到了父容器的顶部
5. 一开始定位 bug 的误区，直接分析代码逻辑流程
6. 切换 tab 流程如下，首先找到 tab 点击事件 pagerTabBar:didSelectItemAtIndex，然后跟到 TYPagerView 三方库，找到 scrollViewWillScrollToView 和 scrollViewDidScrollToView，这两个事件被 delegate 委托出去给 TYPagerController
7. 委托给 TYPagerController 后并没有做任何事情，显然这个思路是不对的
8. 那么这时使用 debug view hierarchy 功能，找 tab 头对象，这里又存在一个误区，如果不通过左侧 debug navigator 从 TabPanelImpl 中找到 TYTabPagerBar，在图形界面是无法找到 TYTabPagerBar 的，那么就无法得知 frame 发生了改变，这个其实很重要
9. 定位要根本本质原因后，可以进行代码 debug了

## debug 代码

1. 首先，找到 hoverHead 代码，可以先找到 setMaskView 初始化 以及 addScrollListener 对滚动的监听
2. 跟到 onScroll 方法，里面逻辑是对滚动过程高度差值判断和frame处理，这块不是
3. tab 点击事件 pagerTabBar:didSelectItemAtIndex，然后跟到 TYPagerView 三方库，这部分也不是
4. 找到 pagerView:viewForIndex:prefetching 方法，内部每次滚动移除销毁后，都要再次创建头部 createView 然后刷新 refresh，这里的 refresh 是重点
5. refresh 通过 caller，跟到 BaseComponent 内部 refresh 方法
6. refresh 方法 调用 needRelayout
7. needRelayout 通过 jump 跟到 needRelayout 私有方法，内部调用 setRelayout
8. setRelayout 通过 jump 跟到 UIView (BKFrame) 扩展类，核心来了
9. 跟到 UIView (BKFrame) 扩展类 setRelayout 方法，递归调用子类的 layoutView 方法
10. 即最终会调用 TabPanelImpl 类的 layoutView 方法，layoutView 内部调用 setNeedsLayout
11. setNeedsLayout 方法，会系统调用 layoutSubviews 方法
12. layoutSubviews 方法内部，将 maskTabBar.frame 的 y 值 重置 为 0，即出现上述情况

## 修改 bug

在 layoutSubviews 代码内部 对 maskTabBar.frame 逻辑做修改即可，代码如下所示：

```objc
// 原来代码
- (void)layoutSubviews{
    [super layoutSubviews];
    CGRect frame =  UIEdgeInsetsInsetRect(self.bounds, self.insets);
    CGFloat tabHeight = _showHead?kTopHeight:0;
    BOOL tabTop = _direction == DTOP;
    if (tabTop) {
        _tabBar.frame = CGRectMake(self.insets.left,self.insets.top,CGRectGetWidth(frame), tabHeight);
        _maskTabBar.frame = CGRectMake(self.insets.left,self.insets.top,CGRectGetWidth(frame), tabHeight);
        _tabContentView.frame = CGRectMake(self.insets.left, CGRectGetMaxY(_tabBar.frame), CGRectGetWidth(frame), frame.size.height-tabHeight);
    }else{
        _tabContentView.frame = CGRectMake(self.insets.left, self.insets.top, CGRectGetWidth(frame), frame.size.height-tabHeight);
        _tabBar.frame = CGRectMake(self.insets.left,CGRectGetMaxY(_tabContentView.frame),CGRectGetWidth(frame), tabHeight);
        _maskTabBar.frame =  CGRectMake(self.insets.left,CGRectGetMaxY(_tabContentView.frame),CGRectGetWidth(frame), tabHeight);
    }
    [_tabBar reloadData];
    if (_tabContentView.curIndex >= 0 && _visibleCompArray.count > _tabContentView.curIndex) {
        [[[_visibleCompArray objectAtIndex:_tabContentView.curIndex] toView] setFrame:_tabContentView.bounds];
        [[[_visibleCompArray objectAtIndex:_tabContentView.curIndex] toView] layoutView];
    }
    [self setBackgroundColor:self.backgroundColor];
}

// 修复之后
- (void)layoutSubviews{
    [super layoutSubviews];
    CGRect frame =  UIEdgeInsetsInsetRect(self.bounds, self.insets);
    CGFloat tabHeight = _showHead?kTopHeight:0;
    BOOL tabTop = _direction == DTOP;
    if (tabTop) {
        _tabBar.frame = CGRectMake(self.insets.left,self.insets.top,CGRectGetWidth(frame), tabHeight);
        // Fixed：Mobile_TabPanel_Own_005：界面下滑后切换tab，悬停的tab头消失
        _maskTabBar.frame = CGRectMake(self.insets.left, _maskTabBar?_maskTabBar.y:self.insets.top, CGRectGetWidth(frame), tabHeight);
        _tabContentView.frame = CGRectMake(self.insets.left, CGRectGetMaxY(_tabBar.frame), CGRectGetWidth(frame), frame.size.height-tabHeight);
    }else{
        _tabContentView.frame = CGRectMake(self.insets.left, self.insets.top, CGRectGetWidth(frame), frame.size.height-tabHeight);
        _tabBar.frame = CGRectMake(self.insets.left,CGRectGetMaxY(_tabContentView.frame),CGRectGetWidth(frame), tabHeight);
        // Fixed：Mobile_TabPanel_Own_005：界面下滑后切换tab，悬停的tab头消失
        _maskTabBar.frame =  CGRectMake(self.insets.left, _maskTabBar?_maskTabBar.y:CGRectGetMaxY(_tabContentView.frame), CGRectGetWidth(frame), tabHeight);
    }
    [_tabBar reloadData];
    if (_tabContentView.curIndex >= 0 && _visibleCompArray.count > _tabContentView.curIndex) {
        [[[_visibleCompArray objectAtIndex:_tabContentView.curIndex] toView] setFrame:_tabContentView.bounds];
        [[[_visibleCompArray objectAtIndex:_tabContentView.curIndex] toView] layoutView];
    }
    [self setBackgroundColor:self.backgroundColor];
}
```

由代码可见，如果存在 maskTabBar，那么 maskTabBar.frame.y = maskTabBar.y，否则 maskTabBar.frame.y = insets.top