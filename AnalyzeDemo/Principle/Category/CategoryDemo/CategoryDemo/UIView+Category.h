//
//  UIView+Category.h
//  CategoryDemo
//
//  Created by 曹素洋 on 2023/5/30.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 协议
@protocol UIViewCategoryDelegate<NSObject>
- (void)viewCategoryDelegate;
@end

/// Category
@interface UIView (Category)
/// 属性
@property (nonatomic, assign) CGFloat x;
@property (nonatomic, weak) id<UIViewCategoryDelegate> delegate;
/// 对象方法
- (void)instanceMethod;
/// 类方法
+ (void)classMethod;
@end

NS_ASSUME_NONNULL_END
