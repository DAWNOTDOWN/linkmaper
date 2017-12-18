### 用途
linkmaper 是一个用于分析linkmap文件中各.a，.o文件在mach-o文件中所占总大小(TEXT与DATA段)及代码段(TEXT段)的命令行工具
### usage

~~~~
linkmaper: a tool which help with linkmap file parsing    
usage: linkmaper [-l outputsize] [-c older_linkmap_file] <linkmap_file>
options:
    -c compare two linkmap file(linkmap_file vs. older_linkmap_file)
    -l limit the minimum size(unit:kilo Bytes) of .o in result file
~~~~

具体使用实例如下：
~~~~
  linkmaper -h      #linkmaper帮助信息
  linkmaper filename   #分析filename中各.a/.o大小分布
  linkmaper -c comparedfile filename  #分析filename相对于comparedfile各.a/.o大小分布变化情况
~~~~
