//
//  main.m
//  LinkMap
//
//  Created by Suteki(67111677@qq.com) on 4/8/16.
//  Copyright © 2016 Apple. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "LinkmapParser.h"

int main(int argc, const char * argv[]) {
    
    NSString* usage = @"\n                              \
linkmaper: a tool which help with linkmap file parsing    \
usage: linkmaper [-l outputsize] [-c older_linkmap_file] <linkmap_file>\
options:\
    -c compare two linkmap file(linkmap_file vs. older_linkmap_file)\
    -l limit the minimum size(unit:kilo Bytes) of .o in result file ";\
    
    opterr = 0;
    NSString* pathComparedLinkmap = nil;
    NSString* pathLinkmap = nil;
    NSInteger sizeOutputLimit = 0;  //minimum size of file listed
    int oc; //operation char
    while( (oc = getopt(argc, (char*const*)argv, "c:l:")) != -1 )
    {
        switch ( oc ) {
            case 'c':
            {
                pathComparedLinkmap = optarg?[NSString stringWithUTF8String:optarg]:nil;
            }
                break;
            case 'l':
            {
                sizeOutputLimit = optarg?[NSString stringWithUTF8String:optarg].integerValue:0;
            }
                break;
            case ':':
            case '?':
            {
                if( optopt == 'h' )
                {
                    fprintf(stdout, "%s",usage.UTF8String);
                    exit(0);
                }
                else
                {
                    fprintf(stderr, "invalid option:%c",optopt);
                    exit(1);
                }
            }
                break;
                
            default:
                break;
        }
    }
    if ( optind < argc ) {
        pathLinkmap = [NSString stringWithUTF8String:argv[optind]];
    }
    else
    {
        fprintf(stderr, "please enter linkmap filepath\n");
        exit(1);
    }
    
    if( ![[NSFileManager defaultManager] fileExistsAtPath:pathLinkmap] )
    {
        fprintf(stderr, "cant file linkmap file:%s\n",pathLinkmap.UTF8String);
        exit(1);
    }
    else if( pathComparedLinkmap && ![[NSFileManager defaultManager] fileExistsAtPath:pathComparedLinkmap] )
    {
        fprintf(stderr, "cant file compared linkmap file:%s\n",pathComparedLinkmap.UTF8String);
        exit(1);
    }
    
    [[LinkmapParser sharedParser] parseLinkmap:pathLinkmap compareWith:pathComparedLinkmap withSizeLimit:sizeOutputLimit];
    
    exit(0);
}
