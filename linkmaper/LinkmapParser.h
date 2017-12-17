//
//  LinkmapParser.h
//  LinkMap
//
//  Created by jeff on 17/12/16.
//  Copyright © 2017 Apple. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LinkmapParser : NSObject

+ (instancetype)sharedParser;

- (void)parseLinkmap:(NSString*)pLinkmap compareWith:(NSString*)pathComparedLinkmap withSizeLimit:(NSInteger)sizelimit;

@end

