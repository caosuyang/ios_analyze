//
//  Son+Association.h
//  CategoryDemo
//
//  Created by 曹素洋 on 2023/5/31.
//

#import "Son.h"

NS_ASSUME_NONNULL_BEGIN

@interface Son (Association)
@property (nonatomic, strong) NSMutableDictionary *map;

- (void)setMap:(NSMutableDictionary * _Nonnull)map;
- (NSMutableDictionary * _Nonnull)map;
@end

NS_ASSUME_NONNULL_END
