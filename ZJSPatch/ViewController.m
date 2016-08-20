//
//  ViewController.m
//  ZJSPatch
//
//  Created by ZangChengwei on 16/8/20.
//  Copyright © 2016年 ZangChengwei. All rights reserved.
//

#import "ViewController.h"
@import JavaScriptCore;
@import ObjectiveC;

@interface ViewController ()

@end

@interface SomeClass : NSObject

- (NSNumber *)someMethod:(NSNumber *)a andParam:(NSNumber *)b;
@end

@implementation SomeClass

// 定义someMethod:andParam:方法，执行加法操作
- (NSNumber *)someMethod:(NSNumber *)a andParam:(NSNumber *)b
{
    return @(a.integerValue + b.integerValue);
}

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // 定义patch的结构为{className: methods:[{name: imp:}]
    // 构建示例脚本
    NSString *script = @"patch = {'className': 'SomeClass', 'methods': [{'name':'someMethod:andParam:', 'imp':function(a, b){return a - b}}]}";
    JSContext *context = [[JSContext alloc] init];
    // 执行脚本，得到一个patch对象
    JSValue *aClass = [context evaluateScript:script];
    
    
    SomeClass *instance = [SomeClass new];
    NSNumber *result = [instance someMethod:@5 andParam:@3];
    
    // 这是还是计算加法，结果为8
    NSLog(@"result is %@", result);
    
    // 从结构中找到className, 映射到OC的Class
    NSString *className = aClass[@"className"].toString;
    Class class = NSClassFromString(className);
    
    // 遍历所有的patch methods
    JSValue *methods = aClass[@"methods"];
    int32_t methodCount = methods[@"length"].toInt32;
    for (int32_t i = 0; i < methodCount; ++i) {
        JSValue *methodInfo = [methods valueAtIndex:i];
        // 找到selectorName，映射到OC的selector
        NSString *selectorName = methodInfo[@"name"].toString;
        SEL sel = NSSelectorFromString(selectorName);
        
        // 关键部分，创建一个闭包函数，捕获context和这个methodInfo
        NSNumber *(^method)(SomeClass *, NSNumber *, NSNumber *) = ^NSNumber *(SomeClass *self, NSNumber *a, NSNumber *b) {
            // 此部分只是一个示意，其实要处理很多内容，包括self，签名，类型转换，由于block没签名，这是最大的难题。
            // 将参数传递到context中
            JSValue *jsA = [JSValue valueWithObject:a inContext:context];
            JSValue *jsB = [JSValue valueWithObject:b inContext:context];
            
            // 执行JSValue对象，得到结果再传回OC
            return [methodInfo[@"imp"] callWithArguments:@[jsA, jsB]].toObject;
        };
        
        // 用block生成IMP
        IMP newImp = imp_implementationWithBlock(method);
        Method oldMethod = class_getClassMethod(class, sel);
        
        // 这里简单粗暴的直接方法替换了，其实应该swizzling
        class_replaceMethod(class, sel, newImp, method_getTypeEncoding(oldMethod));
        
    }
    
    // 再次调用
    result = [instance someMethod:@5 andParam:@3];
    
    // 发现逻辑已经改成减法了！
    NSLog(@"result is %@", result);
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
