//
//  SymbolModel.h
//  LinkMap
//
//  Created by Suteki(67111677@qq.com) on 4/8/16.
//  Copyright © 2016 Apple. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SymbolModel : NSObject

@property (nonatomic, copy) NSString *file;//文件
@property (nonatomic, assign) NSInteger size;//大小
@property (nonatomic, assign) NSInteger codeSize;//代码大小

@end
