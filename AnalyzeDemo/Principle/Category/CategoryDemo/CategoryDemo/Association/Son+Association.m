//
//  Son+Association.m
//  CategoryDemo
//
//  Created by 曹素洋 on 2023/5/31.
//

#import "Son+Association.h"
#import <objc/runtime.h>

// 使用属性名作为key
static const NSString *mapKey = @"map";

@implementation Son (Association)

- (void)setMap:(NSMutableDictionary * _Nonnull)map {
    objc_setAssociatedObject(self, (__bridge const void * _Nonnull)(mapKey), map, OBJC_ASSOCIATION_RETAIN_NONATOMIC); // 添加关联对象
}

- (NSMutableDictionary * _Nonnull)map {
    return objc_getAssociatedObject(self, (__bridge const void * _Nonnull)(mapKey)); // 获得关联对象
}
@end
