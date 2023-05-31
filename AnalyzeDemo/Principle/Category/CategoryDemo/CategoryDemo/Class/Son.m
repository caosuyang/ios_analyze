//
//  Son.m
//  CategoryDemo
//
//  Created by 曹素洋 on 2023/5/30.
//

#import "Son.h"

@implementation Son
+ (void)load {
    NSLog(@"Son +load");
}

+ (void)initialize {
    NSLog(@"Son +initialize");
}
@end
