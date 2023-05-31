//
//  Person.m
//  CategoryDemo
//
//  Created by 曹素洋 on 2023/5/30.
//

#import "Person.h"

@implementation Person

+ (void)load {
    NSLog(@"Person +load");
}

+ (void)initialize {
    NSLog(@"Person +initialize");
}
@end
