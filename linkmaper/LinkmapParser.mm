//
//  ViewController.m
//  LinkMap
//
//  Created by Suteki(67111677@qq.com) on 4/8/16.
//  Copyright © 2016 Apple. All rights reserved.
//

#import "LinkmapParser.h"
#import "SymbolModel.h"

@interface LinkmapParser()

@property (nonatomic,assign) NSUInteger dataOffset;

@property (nonatomic,assign) NSInteger sizeLimit;

@end

@implementation LinkmapParser

+ (instancetype)sharedParser;
{
    static LinkmapParser* parser = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        parser = [LinkmapParser new];
    });
    return parser;
}

- (void)parseLinkmap:(NSString*)pLinkmap compareWith:(NSString*)pathComparedLinkmap withSizeLimit:(NSInteger)sizelimit;
{
    self.sizeLimit = sizelimit;
    NSString* linkmap = [NSString stringWithContentsOfURL:[NSURL fileURLWithPath:pLinkmap isDirectory:NO] encoding:NSMacOSRomanStringEncoding error:nil];
    
    if( ![self checkContent:linkmap] )
    {
        fprintf(stderr, "invalid content of linkmap:%s",pLinkmap.UTF8String);
        exit(1);
    }
    
    NSMutableString* result = [NSMutableString new];
    
    fprintf(stdout, "start parsing linkmap:%s\n",pLinkmap.UTF8String);
    NSDictionary* groupedLinkmap = [self getGroupedSymbolmap:[self getSymbolmap:linkmap]];
    NSArray* sortedLinkmap = [self sortSymbols:[groupedLinkmap allValues]];
    fprintf(stdout, "done parsing linkmap:%s\n",pLinkmap.UTF8String);
    
    if( pathComparedLinkmap )
    {
        NSString* comparedLinkmap = [NSString stringWithContentsOfURL:[NSURL fileURLWithPath:pathComparedLinkmap isDirectory:NO] encoding:NSMacOSRomanStringEncoding error:nil];
        if( ![self checkContent:comparedLinkmap] )
        {
            fprintf(stderr, "invalid content of linkmap:%s\n",pathComparedLinkmap.UTF8String);
            exit(1);
        }
        fprintf(stdout, "start parsing linkmap:%s\n",pathComparedLinkmap.UTF8String);
        NSDictionary* groupedComparedLinkmap = [self getGroupedSymbolmap:[self getSymbolmap:comparedLinkmap]];
        NSArray* sortedComparedLinkmap = [self sortSymbols:[groupedComparedLinkmap allValues]];
        fprintf(stdout, "done parsing linkmap:%s\n",pathComparedLinkmap.UTF8String);
        
        fprintf(stdout, "start writing result\n");
        [result appendString:@"linkmap对比结果如下:\r\n"];
        [result appendString:[self getComparationResult:[groupedLinkmap mutableCopy] with:[groupedComparedLinkmap mutableCopy]]];
        [result appendString:@"\r\n新linkmap分布如下:\r\n"];
        [result appendString:[self getLinkmapStatistics:sortedLinkmap]];
        [result appendString:@"\r\n旧linkmap分布如下:\r\n"];
        [result appendString:[self getLinkmapStatistics:sortedComparedLinkmap]];
    }
    else
    {
        fprintf(stdout, "start writing result\n");
        [result appendString:[self getLinkmapStatistics:sortedLinkmap]];
    }
    
    NSString* pathResult = @"./linkmapResult.txt";
    [result writeToFile:pathResult atomically:YES encoding:NSUTF8StringEncoding error:nil];
    fprintf(stdout, "linkmap result:%s\n",[NSURL fileURLWithPath:pathResult].absoluteString.UTF8String);
}

- (NSString*)getLinkmapStatistics:(NSArray*)symbols;
{
    NSMutableString* str = [@"库大小\t\t库名称\t\t\t代码段大小\r\n\r\n" mutableCopy];
    NSUInteger totalSize = 0;

    //    NSString *searchKey = _searchField.stringValue;
    NSUInteger codesize = 0;
    for(SymbolModel *symbol in symbols) {
        //        if (searchKey.length > 0) {
        //            if ([symbol.file containsString:searchKey]) {
        //                [self appendResultWithSymbol:symbol result:str];
        //                totalSize += symbol.size;
        //            }
        //        } else
        {
            [self appendResultWithSymbol:symbol result:str];
            totalSize += symbol.size;
            codesize += symbol.codeSize;
        }
    }
    
    [str appendFormat:@"\r\n总大小: %.2fM, 代码:%.2fM\r\n",(totalSize/1024.0/1024.0),(codesize/1024.0/1024)];
    return str;
}

- (NSDictionary*)getGroupedSymbolmap:(NSDictionary*)symbolmap;
{
    NSMutableDictionary *combinationMap = [[NSMutableDictionary alloc] init];
    
    for(SymbolModel *symbol in [symbolmap allValues]) {
        NSString *name = [[symbol.file componentsSeparatedByString:@"/"] lastObject];
        if ([name hasSuffix:@")"] &&
            [name containsString:@"("]) {
            NSRange range = [name rangeOfString:@"("];
            NSString *component = [name substringToIndex:range.location];
            
            SymbolModel *combinationSymbol = [combinationMap objectForKey:component];
            if (!combinationSymbol) {
                combinationSymbol = [[SymbolModel alloc] init];
                [combinationMap setObject:combinationSymbol forKey:component];
            }
            
            combinationSymbol.size += symbol.size;
            combinationSymbol.codeSize += symbol.codeSize;
            combinationSymbol.file = component;
        } else {
            // symbol可能来自app本身的目标文件或者系统的动态库，在最后的结果中一起显示
            [combinationMap setObject:symbol forKey:name];
        }
    }
    return [combinationMap copy];
}

- (NSDictionary*)getSymbolmap:(NSString*)linkmapcontent;
{
    NSMutableDictionary <NSString *,SymbolModel *>*symbolMap = [NSMutableDictionary new];
    // 符号文件列表
    NSArray *lines = [linkmapcontent componentsSeparatedByString:@"\n"];
    
    BOOL reachFiles = NO;
    BOOL reachSymbols = NO;
    BOOL reachSections = NO;
    self.dataOffset = 0;
    NSUInteger size = 0;
    for(NSString *line in lines) {
        if([line hasPrefix:@"#"]) {
            if([line hasPrefix:@"# Object files:"])
                reachFiles = YES;
            else if ([line hasPrefix:@"# Sections:"])
                reachSections = YES;
            else if ([line hasPrefix:@"# Symbols:"])
                reachSymbols = YES;
        } else {
            if(reachFiles == YES && reachSections == NO && reachSymbols == NO) {
                NSRange range = [line rangeOfString:@"]"];
                if(range.location != NSNotFound) {
                    SymbolModel *symbol = [SymbolModel new];
                    symbol.file = [line substringFromIndex:range.location+1];
                    NSString *key = [line substringToIndex:range.location+1];
                    symbolMap[key] = symbol;
                }
            }
            else if( reachFiles == YES && reachSections == YES && reachSymbols == NO )
            {
                NSArray <NSString *>*sectionArray = [line componentsSeparatedByString:@"\t"];
                if ( !self.dataOffset && sectionArray.count == 4  && [sectionArray[2] isEqualToString:@"__DATA"] ) {
                    self.dataOffset = strtoul([sectionArray[0] UTF8String], nil, 16);
                }
            }
            else if (reachFiles == YES && reachSections == YES && reachSymbols == YES) {
                NSArray <NSString *>*symbolsArray = [line componentsSeparatedByString:@"\t"];
                if(symbolsArray.count == 3) {
                    if( [symbolsArray[0] containsString:@"<<dead>>"] )
                    {
                        size++;
                        continue;
                    }
                    NSString *fileKeyAndName = symbolsArray[2];
                    NSUInteger size = strtoul([symbolsArray[1] UTF8String], nil, 16);
                    NSUInteger offset = strtoul([symbolsArray[0] UTF8String], nil, 16);
                    
                    NSRange range = [fileKeyAndName rangeOfString:@"]"];
                    if(range.location != NSNotFound) {
                        NSString *key = [fileKeyAndName substringToIndex:range.location+1];
                        SymbolModel *symbol = symbolMap[key];
                        if(symbol) {
                            symbol.size += size;
                            if( offset < self.dataOffset )
                            {
                                symbol.codeSize += size;
                            }
                        }
                    }
                }
            }
        }
    }
    return symbolMap;
}

- (NSString*)getComparationResult:(NSMutableDictionary*)linkmap with:(NSMutableDictionary*)comparedLinkmap
{
    NSMutableString* result = [NSMutableString new];
    NSMutableArray* increase = [NSMutableArray new],*decrease = [NSMutableArray new],*gone = [NSMutableArray new],*news= [NSMutableArray new];
    NSInteger incsize = 0,decsize = 0,gonesize = 0,newsize = 0;
    NSInteger inccodesize = 0,deccodesize=0,gonecodesize = 0,newcodesize=0;
    for( NSString* key in [comparedLinkmap allKeys] )
    {
        SymbolModel* oldModel = comparedLinkmap[key];
        SymbolModel* newmodel = linkmap[key];
        SymbolModel* model = [SymbolModel new];
        if( newmodel )
        {
            model.size = newmodel.size - oldModel.size;
            model.codeSize = newmodel.codeSize - oldModel.codeSize;
            model.file = key;
            if( model.size < 0 )
            {
                if( labs(model.size) > 1024 )
                {
                    [decrease addObject:model];
                }
                decsize -= model.size;
                deccodesize -= model.codeSize;
            }
            else if( model.size > 0 )
            {
                if( labs(model.size) > 1024 )
                {
                    [increase addObject:model];
                }
                incsize += model.size;
                inccodesize += model.codeSize;
            }
            [linkmap removeObjectForKey:key];
        }
        else
        {
            [gone addObject:oldModel];
            gonesize += oldModel.size;
            gonecodesize += oldModel.codeSize;
        }
    }
    for( SymbolModel* model in [linkmap allValues] )
    {
        [news addObject:model];
        newsize+= model.size;
        newcodesize += model.codeSize;
    }
    
    [increase sortUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        SymbolModel* m1 = obj1,*m2 = obj2;
        if( m1.size > m2.size )
        {
            return NSOrderedAscending;
        }
        else if( m1.size == m2.size )
        {
            return NSOrderedSame;
        }
        else
        {
            return NSOrderedDescending;
        }
    }];
    [decrease sortUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        SymbolModel* m1 = obj1,*m2 = obj2;
        if( m1.size < m2.size )
        {
            return NSOrderedAscending;
        }
        else if( m1.size == m2.size )
        {
            return NSOrderedSame;
        }
        else
        {
            return NSOrderedDescending;
        }
    }];
    [gone sortUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        SymbolModel* m1 = obj1,*m2 = obj2;
        if( m1.size > m2.size )
        {
            return NSOrderedAscending;
        }
        else if( m1.size == m2.size )
        {
            return NSOrderedSame;
        }
        else
        {
            return NSOrderedDescending;
        }
    }];
    [news sortUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        SymbolModel* m1 = obj1,*m2 = obj2;
        if( m1.size > m2.size )
        {
            return NSOrderedAscending;
        }
        else if( m1.size == m2.size )
        {
            return NSOrderedSame;
        }
        else
        {
            return NSOrderedDescending;
        }
    }];
    [result appendString:[NSString stringWithFormat:@"\n\n 新增部分:%.2fM, 代码:%.2fM\n\n",newsize*1.0/1024/1024,newcodesize/1024.0/1024]];
    for( SymbolModel* model in news )
    {
        [self appendResultWithSymbol:model result:result];
    }
    [result appendString:[NSString stringWithFormat:@"\n\n 删除部分:%.2fM, 代码:%.2fM\n\n",gonesize*1.0/1024/1024,gonecodesize/1024.0/1024.0]];
    for( SymbolModel* model in gone )
    {
        [self appendResultWithSymbol:model result:result];
    }
    [result appendString:[NSString stringWithFormat:@"\n\n 增加部分:%.2fM, 代码:%.2fM\n\n",incsize*1.0/1024/1024,inccodesize/1024.0/1024.0]];
    for( SymbolModel* model in increase )
    {
        [self appendResultWithSymbol:model result:result];
    }
    [result appendString:[NSString stringWithFormat:@"\n\n 减少部分:%.2fM, 代码:%.2fM\n\n",decsize*1.0/1024/1024,deccodesize/1024.0/1024.0]];
    for( SymbolModel* model in decrease )
    {
        [self appendResultWithSymbol:model result:result];
    }
    return [result copy];
}

- (NSArray *)sortSymbols:(NSArray *)symbols {
    NSArray *sortedSymbols = [symbols sortedArrayUsingComparator:^NSComparisonResult(SymbolModel *  _Nonnull obj1, SymbolModel *  _Nonnull obj2) {
        if(obj1.size > obj2.size) {
            return NSOrderedAscending;
        } else if (obj1.size < obj2.size) {
            return NSOrderedDescending;
        } else {
            return NSOrderedSame;
        }
    }];
    
    return sortedSymbols;
}

- (void)appendResultWithSymbol:(SymbolModel *)model result:(NSMutableString*)result{
    NSString *size = nil;
    NSString* codesize = nil;
    if( labs(model.size) < self.sizeLimit )
    {
        return;
    }
    if (model.size / 1024.0 / 1024.0 > 1) {
        size = [NSString stringWithFormat:@"%.2fM", model.size / 1024.0 / 1024.0];
    } else {
        size = [NSString stringWithFormat:@"%.2fK", model.size / 1024.0];
    }
    if( model.codeSize / 1024.0/1024.0 > 1 )
    {
        codesize = [NSString stringWithFormat:@"%.2fM", model.codeSize / 1024.0 / 1024.0];
    }else {
        codesize = [NSString stringWithFormat:@"%.2fK", model.codeSize / 1024.0];
    }
    [result appendFormat:@"%-10s%-40s%-10s\r\n",[size UTF8String], [[[model.file componentsSeparatedByString:@"/"] lastObject] UTF8String],[codesize UTF8String]];
}

- (BOOL)checkContent:(NSString *)content {
    NSRange objsFileTagRange = [content rangeOfString:@"# Object files:"];
    if (objsFileTagRange.length == 0) {
        return NO;
    }
    NSString *subObjsFileSymbolStr = [content substringFromIndex:objsFileTagRange.location + objsFileTagRange.length];
    NSRange symbolsRange = [subObjsFileSymbolStr rangeOfString:@"# Symbols:"];
    if ([content rangeOfString:@"# Path:"].length <= 0||objsFileTagRange.location == NSNotFound||symbolsRange.location == NSNotFound) {
        return NO;
    }
    return YES;
}
@end
