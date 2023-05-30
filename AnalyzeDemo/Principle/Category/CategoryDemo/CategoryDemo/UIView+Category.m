//
//  UIView+Category.m
//  CategoryDemo
//
//  Created by 曹素洋 on 2023/5/30.
//

#import "UIView+Category.h"

@implementation UIView (Category)

/// Category 添加的属性不会生成成员变量，只会生成 get 方法、set 方法的声明，需要自己去实现
- (void)setX:(CGFloat)x {
    CGRect frame = self.frame;
    frame.origin.x = x;
    self.frame = frame;
}

- (CGFloat)x {
    return self.frame.origin.x;
}

- (void)instanceMethod {
    NSLog(@"UIView (Category) - instanceMethod");
}

+ (void)classMethod {
    NSLog(@"UIView (Category) - classMethod");
}
@end
