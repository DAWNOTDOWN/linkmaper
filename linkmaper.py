# coding=utf-8 ##以utf-8编码储存中文字符

import urllib
import sys
import shutil
import getopt
import platform
import time
import os
from sendemail.send_email import Email

#reload(sys)
#sys.setdefaultencoding('utf-8')
dataOffset = 0  #data segment start address
sizelimit = 1024
outputSerializer = ''

class OutputSerializer:
    outputfilehandler = ''
    emailFileHandler = ''
    def __init__(self,outputfile,emailfile):
        self.outputfilehandler = open(outputfile,'w',0)
        self.emailFileHandler = open(emailfile,'w')
    def write(self,content):
        self.outputfilehandler.write(content+'\n')
    def writeHtml(self,content):
        self.emailFileHandler.write(content)
    def closeOutput(self):
        self.outputfilehandler.close()
        self.emailFileHandler.close();

class SymbolModel:
    file = ''
    size = 0
    codeSize = 0

def binarySize(size):
    if size < 1024:
        return '%5.0f'%float(size) +'B'
    elif size < 1024*1024:
        return '%5.1f'%(float(size)/1024) + 'KB'
    else:
        return '%5.1f'%(float(size)/(1024*1024)) + 'MB'

def getSymbolmap(content):
    partition = 0 #part num in linkmap, typically objects:1 sections:2 symbols:3 <<dead>>:4
    models = {};
    print 'len:',len(content)
    for line in content:
        if line.find('# Object files:') > -1:
            partition = 1
            continue
        if line.find('# Sections:') > -1:
            partition = 2
            continue
        if line.find('# Symbols:') > -1:
            print 'Symbols'
            partition = 3
            continue
        if line.find('# Dead') > -1:
            print 'dead'
            break
        if partition == 1:
            index = line.find(']')
            if index > -1:
                model = SymbolModel()
                model.file = line[index+2:len(line)-1]
                models[line[0:index+1]] = model
                #print model.file
        elif partition == 2:
            global dataOffset
            map = line[0:len(line)-1].split('\t')
            if map[2] == '__DATA' and dataOffset <= 0:
                dataOffset = long(map[0],16)
                print 'dataoffset is:',map[0]
                #print '__DATA offset:',dataOffset
        elif partition == 3:
            map = line[0:len(line)-1].split('\t')
            if len(map) >= 3:
                key = map[2];
                lparent = key.find('[')
                rparent = key.find(']')
                if lparent > -1 and rparent > -1:
                    key = key[lparent:rparent+1]
                    #print key
                    if models.has_key(key):
                        models[key].size += long(map[1],16)
                        #print models[key].size
                        offset = int(map[0],16)
                        if offset < dataOffset:
                            models[key].codeSize += long(map[1],16)
            elif len(line) > 1:
                print 'symbols split wrong:',line,'line end'
    return models

def getGroupedSymbolmap(symbolmaps):
    models = {}
    for model in symbolmaps.itervalues():
        name = getGroupedFilename(model.file)
        if models.has_key(name):
            models[name].codeSize += model.codeSize
            models[name].size += model.size
        else:
            m = SymbolModel()
            m.file = name
            m.codeSize = model.codeSize
            m.size = model.size
            models[name] = m
    return models

def getGroupedFilename(filename):
    fragments = filename.split('/')
    name = fragments[len(fragments)-1]
    lparent = name.find('(')
    rparent = name.find(')')
    if lparent > -1 and rparent > -1:
        name = name[0:lparent]
    return name

def symbolSort(model):
    return model.size

def sortSymbols(symbolmodels):
    values = symbolmodels.values()
    values.sort(key=symbolSort,reverse=True)
    return values

def writeSymbolsLayout(symbolModels):
    global sizelimit
    global outputSerializer
    name = ('目标文件名','总数据大小','代码段大小')
    outputSerializer.write('%-40s\t%-30s\t%-20s' % name )
    for i,model in enumerate(symbolModels):
        if model.size > sizelimit:
            outputSerializer.write('%-40s\t%-20s\t%-20s' % (model.file,binarySize(model.size),binarySize(model.codeSize)))

def writeComparation(newModelMap,oldModelMap):
    global sizelimit
    global outputSerializer
    newmap = newModelMap.copy()
    oldmap = oldModelMap.copy()
    newappears = {}
    increase = {}
    decrease = {}
    deleted = {}
    newsize = incsize = decsize = delsize = 0
    newcodesize = inccodesize = deccodesize = delcodesize = 0
    for key in newmap.keys():
        if not oldmap.has_key(key):
            if newmap[key].size > sizelimit:
                newappears[key] = newmap[key]
                newsize += newmap[key].size
                newcodesize += newmap[key].codeSize
        elif oldmap[key].size > newmap[key].size:
            model = SymbolModel()
            model.file = oldmap[key].file
            model.size = oldmap[key].size-newmap[key].size
            model.codeSize = oldmap[key].codeSize - newmap[key].codeSize
            oldmap.pop(key)
            if model.size > sizelimit:
                decrease[key] = model
                decsize += model.size
                deccodesize += model.codeSize
        elif oldmap[key].size < newmap[key].size:
            model = SymbolModel()
            model.file = oldmap[key].file
            model.size = newmap[key].size-oldmap[key].size
            model.codeSize = newmap[key].codeSize - oldmap[key].codeSize
            oldmap.pop(key)
            if model.size > sizelimit:
                increase[key] = model
                incsize += model.size
                inccodesize += model.codeSize
        else:
            oldmap.pop(key)
    for key in oldmap.keys():
        if oldmap[key].size > sizelimit:
            deleted[key] = oldmap[key]
            delsize += oldmap[key].size
            delcodesize += oldmap[key].codeSize

#    outputSerializer.write('对比结果如下：',True)
    newlist = newappears.values()
    inclist = increase.values()
    declist = decrease.values()
    dellist = deleted.values()
    newlist.sort(key=symbolSort,reverse=True)
    declist.sort(key=symbolSort,reverse=True)
    inclist.sort(key=symbolSort,reverse=True)
    dellist.sort(key=symbolSort,reverse=True)

    result = []
    if newsize:
        result.append(('新增',newsize,newcodesize,newappears,newlist))
    if incsize:
        result.append(('增加',incsize,inccodesize,increase,inclist))
    if decsize:
        result.append(('减少',decsize,deccodesize,decrease,declist))
    if delsize:
        result.append(('删除',delsize,delcodesize,deleted,dellist))
    for i,tup in enumerate(result):
        outputSerializer.write('%s部分：%-20s,代码：%-20s(%d项)' % (tup[0],binarySize(tup[1]),binarySize(tup[2]),len(tup[3])))
        outputSerializer.writeHtml('<h5>%s部分：%-20s,代码：%-20s(%d项)</h5>' % (tup[0],binarySize(tup[1]),binarySize(tup[2]),len(tup[3])))
#        outputSerializer.writeHtml()
        hasPrintHead = False
        for i,model in enumerate(tup[4]):
            if not hasPrintHead:
                outputSerializer.writeHtml('<table border="1">')
                hasPrintHead = True
                name = ('目标文件名','总数据大小','代码段大小')
                outputSerializer.write('%-40s\t%-30s\t%-20s' % name )
                outputSerializer.writeHtml('<tr><th>目标文件名</th><th>总数据大小</th><th>代码段大小</th>')
            outputSerializer.write('%-40s\t%-20s\t%-20s' % (model.file,binarySize(model.size),binarySize(model.codeSize)))
            outputSerializer.writeHtml('<tr><td>%s</td><td>%s</td><td>%s</td></tr>'%(model.file,binarySize(model.size),binarySize(model.codeSize)))
        if hasPrintHead:
            outputSerializer.writeHtml('</table>')

def getLinkmapComparation(newlinkmapurl,oldlinkmapurl,writeOriginal):
    return getLinkmapComparationWithSizelimit(newlinkmapurl,oldlinkmapurl,writeOriginal,sizelimit)

def getLinkmapComparationWithSizelimit(newlinkmapurl,oldlinkmapurl,writeOriginal,itemsizelimit):
    global sizelimit
    sizelimit = itemsizelimit
    global outputSerializer
    
    globaldir = '/Library/WebServer/Documents/'
    if platform.platform().find('Windows') > -1:
        globaldir = 'E:/wamp64/tmp/'

    globaldir += str(time.time()) + '/'

    if not os.path.exists(globaldir):   #make tmp dir
        os.makedirs(globaldir)

    outputSerializer = OutputSerializer(globaldir+'result.txt',globaldir+'emailresult.html')
    if writeOriginal:
        outputSerializer.write('新linkmap(%s) 相比于 旧linkmap(%s) 执行文件变化如下:' % (newlinkmapurl,oldlinkmapurl))

    newurl = newlinkmapurl
    oldurl = oldlinkmapurl
    newpath = globaldir + 'linkmap.txt'
    oldpath = globaldir + 'linkmap_compared.txt'

    urllib.urlretrieve(newurl, newpath)
    
    filelinkmap = open(newpath,'rb')
    newmodelmap = getSymbolmap(filelinkmap.readlines())
    newmodelmap = getGroupedSymbolmap(newmodelmap)
    sortedNewSymbols = sortSymbols(newmodelmap)
    filelinkmap.close()
    
    if len(oldurl) > 0:
        urllib.urlretrieve(oldurl, oldpath)
        
        oldfilelinkmap = open(oldpath,'rb')
        oldmodelmap = getSymbolmap(oldfilelinkmap.readlines())
        oldmodelmap = getGroupedSymbolmap(oldmodelmap)
        sortedOldSymbols = sortSymbols(oldmodelmap)
        oldfilelinkmap.close()
        
        writeComparation(newmodelmap,oldmodelmap)
        if writeOriginal:
            outputSerializer.write('\n新linkmap分布如下：\n')
            writeSymbolsLayout(sortedNewSymbols)
            outputSerializer.write('\n旧linkmap分布如下：\n')
            writeSymbolsLayout(sortedOldSymbols)
    else:
        writeSymbolsLayout(sortedNewSymbols)
    outputSerializer.closeOutput()
    return [globaldir,'result.txt','emailresult.html']

def main(argv=None):
    if argv is None:
        argv = sys.argv
    try:
        try:
            opts, args = getopt.getopt(argv[1:], "hc:e:l:", ["help"])
        except getopt.error, msg:
            raise Usage(msg)

        newurl = ''
        oldurl = ''
        emailaddr = []
        usagemsg ='''
linkmaper.py:
serves as a tool for executable layout parsing with linkmapfile
usage:
linkmaper.py [-c comparedlinkmapurl] [-e emailaddr] linkmapurl

-c      用于对比的旧版本
-h      帮助文档
-e      结果接收邮箱地址，以分号分隔
-l      指定输出的项最小字节数
    '''
        global sizelimit
        for name,value in opts:
            if name in ('-h','--help'):
                raise Usage(usagemsg)
            elif name in ('-c'):
                oldurl = value
            elif name in ('-e'):
                emailaddr = value.split(';')
            elif name in ('-l'):
                sizelimit = int(value)
        if len(args) <= 0:
            raise Usage(usagemsg)

        newurl = args[0]
        
        tuple = getLinkmapComparation(newurl,oldurl,True)
        if len(emailaddr) > 0:
            emailhandler = Email('yy-pgone@yy.com','Guozhi1221')
            comparationfile = open(tuple[0]+tuple[2])
            emailcontent = ''
            for line in comparationfile:
                emailcontent += line
            comparationfile.close()
            emailhandler.sendmail('linkmap compare result',emailaddr,['fangyang@yy.com'],[tuple[0]+tuple[1]],emailcontent)
		
        shutil.rmtree(tuple[0])
	
    except Usage, err:
        print >>sys.stderr, err.msg
        print >>sys.stderr, "for help use --help"
        return 2

class Usage(Exception):
    def __init__(self, msg):
        self.msg = msg

if __name__ == '__main__':
    sys.exit(main())
