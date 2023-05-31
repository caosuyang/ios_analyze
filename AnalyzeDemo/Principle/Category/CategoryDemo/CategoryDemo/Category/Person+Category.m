//
//  Person+Category.m
//  CategoryDemo
//
//  Created by 曹素洋 on 2023/5/31.
//

#import "Person+Category.h"

@implementation Person (Category)
/// Category 添加的属性不会生成成员变量，只会生成 get 方法、set 方法的声明，需要自己去实现
- (void)setProperty:(NSString *)property {
    
}

- (NSString *)property {
    return @"";
}

- (void)instanceMethod {
    NSLog(@"UIView (Category) - instanceMethod");
}

+ (void)classMethod {
    NSLog(@"UIView (Category) - classMethod");
}
@end
