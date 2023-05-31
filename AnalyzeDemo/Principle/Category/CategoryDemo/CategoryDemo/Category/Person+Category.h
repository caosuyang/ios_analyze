//
//  Person+Category.h
//  CategoryDemo
//
//  Created by 曹素洋 on 2023/5/31.
//

#import "Person.h"

NS_ASSUME_NONNULL_BEGIN

/// 协议
@protocol UIViewCategoryDelegate<NSObject>
- (void)viewCategoryDelegate;
@end

@interface Person (Category)
/// 属性
@property (nonatomic, copy) NSString *property;
/// 对象方法
- (void)instanceMethod;
/// 类方法
+ (void)classMethod;
@end

NS_ASSUME_NONNULL_END
