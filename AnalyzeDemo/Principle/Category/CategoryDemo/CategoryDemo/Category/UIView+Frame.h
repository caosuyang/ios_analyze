//
//  UIView+Frame.h
//  CategoryDemo
//
//  Created by 曹素洋 on 2023/5/31.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 最主要的应用：给系统自带的类扩展方法，比如 UIView、NSString 等
@interface UIView (Frame)
@property (nonatomic, assign) CGFloat     centerY;
@property (nonatomic, assign) CGFloat     centerX;
@property (nonatomic, assign) CGSize      size;
@property (nonatomic, assign) CGFloat     width;
@property (nonatomic, assign) CGFloat     height;
@property (nonatomic, assign) CGFloat     x;
@property (nonatomic, assign) CGFloat     y;
@property (nonatomic, assign) CGFloat     top;
@property (nonatomic, assign) CGFloat    left;
@property (nonatomic, assign) CGFloat     right;
@property (nonatomic, assign) CGFloat    bottom;
@end

NS_ASSUME_NONNULL_END
