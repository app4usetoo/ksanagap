// ksana filesystem
//learned from https://github.com/node-app/Nodelike/blob/master/Nodelike/NLFS.h
//yapcheahshen@gmail.com 2014/10/10
#import "kfs_ios.h"

@implementation kfs_ios {
    NSString *rootPath;
    NSMutableDictionary *opened;
    NSMutableDictionary *opened_fid;
    int32_t fileopened;
}
- (id)init {
    self = [super init];
    opened=[[NSMutableDictionary alloc] init];
    opened_fid=[[NSMutableDictionary alloc] init];
    fileopened=0;
    return self;
}
-(void) setRoot : (NSString*)root {
    //set root
    rootPath = root;
}
-(NSString *)getFullPath :(NSString*)fn {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    documentsDirectory = [NSString stringWithFormat:@"%@/%@/", documentsDirectory, rootPath];
    //append with root
    NSString *file = [documentsDirectory stringByAppendingPathComponent:fn];
    return file;
}

-(NSFileHandle*)handleByFid:(uint32_t)fid {
    for (id fn in opened) {
        NSNumber *obj=[opened_fid objectForKey :fn];
        if ( obj.intValue==fid) {
            return [opened objectForKey :fn];
        };
    }
    return nil;
}
-(NSString*)filenameByFid:(int32_t)fid {
    for (id fn in opened_fid) {
        if ((uint32_t)[opened_fid objectForKey :fn]==fid) return fn;
    }
    return nil;
}

-(void) finalize {
    for (id fn in opened) {
        [[opened objectForKey:fn] closeFile];
        [opened removeObjectForKey:fn];
    }
    fileopened=0;
}

// for Javascripts
-(NSNumber *)open:(NSString*)fn {
    NSFileHandle* handle = [opened objectForKey:fn];
    NSString *fullpath=[self getFullPath:fn];
    if (!handle) {
        handle=[NSFileHandle fileHandleForReadingAtPath:fullpath];
        if (handle) {
            [opened setObject :handle forKey:fn];
            fileopened++;
            [opened_fid setObject :[NSNumber numberWithInt: fileopened] forKey:fn] ;
        } else {
            return [NSNumber numberWithInt:0];
        }
    }
    return [NSNumber numberWithInt:fileopened];
}

-(NSNumber*)close:(NSNumber*)handle {
    NSString* fn=[self filenameByFid :handle.intValue];
    if (fn) {
        [[opened objectForKey:fn] closeFile];
        [opened removeObjectForKey:fn];
        [opened_fid removeObjectForKey:fn];
        return [NSNumber numberWithBool:true];
    }
    return [NSNumber numberWithBool:false];
}

-(NSString*) getFileNameOnly:(NSString*)path{
    NSRange range = [path rangeOfString:@"/" options:NSBackwardsSearch];
    if (range.location==path.length-1) {
        path = [path substringWithRange:NSMakeRange(0, path.length - 1)];
        range = [path rangeOfString:@"/" options:NSBackwardsSearch];
    }

    NSRange newRange = NSMakeRange(range.location + range.length, [path length] - range.location -1);
    return [path substringWithRange:newRange];
}

-(NSString*)readDir:(NSString*)path{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error;
    
    if ([path hasPrefix:@"."]) {
        if ([path isEqualToString:@".."]) {
            path=@"";
        } else {
            path=rootPath;
        }
    
    }
    NSString *stringPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)objectAtIndex:0]stringByAppendingPathComponent:path];
    
    NSArray *subFolders = [fileManager contentsOfDirectoryAtURL:[NSURL URLWithString:stringPath] includingPropertiesForKeys:@[] options:NSDirectoryEnumerationSkipsHiddenFiles error:&error];
    NSString *dirs=@"";
    for (int i = 0; i < [subFolders count]; i++) {
        NSString *urlString = [subFolders[i] absoluteString];
        urlString=[self getFileNameOnly:urlString];
        dirs = [dirs stringByAppendingFormat:@"%@\uffff",urlString];
    }
    return dirs;
};
-(NSNumber *)getFileSize:(NSNumber *)handle {
    NSFileHandle *h=[self handleByFid :handle.intValue];
    uint64_t fileSize = [h seekToEndOfFile];
    return [NSNumber numberWithLongLong:fileSize];
}
-(NSString *)readSignature:(NSNumber *)handle pos:(JSValue *)pos {
    NSFileHandle *h=[self handleByFid :handle.intValue];
    if (!h) return nil;

    [h seekToFileOffset:[pos toUInt32]];
    NSData *data = [h readDataOfLength:1];
    char c = *(char*)([data bytes]);
    return [NSString stringWithFormat:@"%c" , c];
}

-(NSNumber *)readInt32:(NSNumber *)handle pos:(JSValue *)pos {
    NSFileHandle *h=[self handleByFid :handle.intValue];
    if (!h) return nil;

    [h seekToFileOffset:[pos toUInt32]];
    NSData *data = [h readDataOfLength:4];

    int32_t i = *(int*)([data bytes]);
    i=CFSwapInt32HostToBig(i);
    return [NSNumber numberWithInt:i];
}

-(NSNumber *)readUInt32:(NSNumber *)handle pos:(JSValue *)pos {
    NSFileHandle *h=[self handleByFid :handle.intValue];
    if (!h) return nil;
    int64_t p=[pos toUInt32];
    [h seekToFileOffset:p];
    NSData *data = [h readDataOfLength:4];
    unsigned char *t=[data bytes];

    uint32_t i = *(unsigned int*)([data bytes]);
    i=CFSwapInt32HostToBig(i);
    return [NSNumber numberWithUnsignedInt:i];
}

-(NSNumber *)readUInt8:(NSNumber *)handle pos:(JSValue *)pos {
    NSFileHandle *h=[self handleByFid :handle.intValue];
    if (!h) return nil;

    [h seekToFileOffset:[pos toUInt32]];
    NSData *data = [h readDataOfLength:1];

    uint8_t i =(uint8_t)(*(uint8_t*)([data bytes]));
    return [NSNumber numberWithUnsignedInt:i];
}

-(NSString *)readUTF8String:(NSNumber *)handle pos:(JSValue *)pos size:(JSValue *)size {
    NSFileHandle *h=[self handleByFid :handle.intValue];
    uint64_t p=[pos toUInt32];
    [h seekToFileOffset:p];
    uint64_t sz=[size toUInt32];
    NSData *data = [h readDataOfLength:sz];

    NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return str;
}
-(NSString *)readULE16String:(NSNumber *)handle pos:(JSValue *)pos size:(JSValue *)size {
    NSFileHandle *h=[self handleByFid :handle.intValue];
    [h seekToFileOffset:[pos toUInt32]];
    NSData *data = [h readDataOfLength:[size toUInt32]];

    NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF16LittleEndianStringEncoding];
    return str;
}

-(NSArray *)readBuf:(NSNumber *)handle pos:(JSValue *)pos size:(JSValue *)size {
    NSFileHandle *h=[self handleByFid :handle.intValue];
    if (!h) return nil;

    [h seekToFileOffset:[pos toUInt32]];
    NSData *data = [h readDataOfLength:[size toUInt32]];

    NSMutableArray* out=[NSMutableArray arrayWithCapacity :[size toUInt32]];
    uint8_t * c = (uint8_t*)([data bytes]);
    for(int i=0;i<[size toUInt32];i++) {
        [out addObject :[NSNumber numberWithUnsignedInt :*(c+i)]];
    }
    return out;
}


void hex_dump(uint32_t *ints, unsigned char *chars, int cnt){
    /*
    for (int i=0;i<cnt;i++){
        char b=*bytes++, c;
        char B=(b>>4) &0xf;
        if (B<9) c=B+'0'; else c=B - 10+'A' ; *chars++=c;
        B=b&0xf;
        if (B<9) c=B+'0'; else c=B - 10+'A' ; *chars++=c;
    }
     */

    uint32_t *end=ints+cnt;
    uint32_t b=0;
    unsigned char B,c;
    while(ints<end) {
        b=*ints;
        *chars++='0';
        *chars++='x';
        B=(b>>28)&0xF;if(B<=9) c=B+'0';else c=B-10+'A'; *chars++=c;
        B=(b>>24)&0xF;if(B<=9) c=B+'0';else c=B-10+'A'; *chars++=c;
        B=(b>>20)&0xF;if(B<=9) c=B+'0';else c=B-10+'A'; *chars++=c;
        B=(b>>16)&0xF;if(B<=9) c=B+'0';else c=B-10+'A'; *chars++=c;
        B=(b>>12)&0xF;if(B<=9) c=B+'0';else c=B-10+'A'; *chars++=c;
        B=(b>>8)&0xF;if(B<=9) c=B+'0';else c=B-10+'A'; *chars++=c;
        B=(b>>4)&0xF;if(B<=9) c=B+'0';else c=B-10+'A'; *chars++=c;
        B=(b>>0)&0xF;if(B<=9) c=B+'0';else c=B-10+'A'; *chars++=c;
        *chars++=',';
        ints++;
    }
}
-(NSDictionary*) unpack_int_hex:(uint8_t*)data length:(int)length count:(int)count reset:(bool)reset {
    //NSMutableArray* output=[NSMutableArray arrayWithCapacity:count];
    
    uint32_t *p= (uint32_t*)malloc(count*4);
    uint32_t adv = 0, n=0 , cnt=0;
    do {
        int S = 0;
        do {
            n += ( data[adv] & 0x7f) << S;
            S += 7;
            adv++;
            if (adv>=length) break;
        } while (( data[adv] & 0x80)!=0 );
        
        
        //[output addObject: [NSNumber numberWithUnsignedInt:n]];
        //[outputstr appendFormat:@"%i,",n];
        //n=CFSwapInt32HostToBig(n);
        *(p+cnt)=n;
        cnt++;
        if (reset) n=0;
        count--;
    } while (adv<length && count>0);
    
    unsigned char *r=(unsigned char*)malloc(cnt*11+1);

    hex_dump((uint32_t*)p, r , cnt);
    free(p);

    //NSString *outputstr=[NSString stringWithCString:r];
    //free(r);
    NSString *outputstr=[[NSString alloc] initWithBytesNoCopy:r length:cnt*11 encoding:1 freeWhenDone:YES];
    return [NSDictionary dictionaryWithObjectsAndKeys:outputstr ,@"data",
            [NSNumber numberWithUnsignedInt:adv],@"adv",nil];
}


-(NSDictionary*) unpack_int:(uint8_t*)data length:(int)length count:(int)count reset:(bool)reset {
    //NSMutableArray* output=[NSMutableArray arrayWithCapacity:count];
    NSMutableString *outputstr = [[NSMutableString alloc]init];
    unsigned int adv = 0, n=0;
    do {
        int S = 0;
        do {
            n += ( data[adv] & 0x7f) << S;
            S += 7;
            adv++; 
            if (adv>=length) break;
        } while (( data[adv] & 0x80)!=0 );

        //[output addObject: [NSNumber numberWithUnsignedInt:n]];
        [outputstr appendFormat:@"%i,",n];
        if (reset) n=0;
        count--;
    } while (adv<length && count>0);
    return [NSDictionary dictionaryWithObjectsAndKeys:outputstr                        ,@"data",
                                                     [NSNumber numberWithUnsignedInt:adv],@"adv",nil];
}

-(NSDictionary *)readBuf_packedint:(NSNumber *)handle pos:(JSValue *)pos size:(JSValue *)size  count:(JSValue *)count  reset:(JSValue *)reset {
    NSFileHandle *h=[self handleByFid :handle.intValue];    if (!h) return nil;

    
    uint64_t p=[pos toUInt32];
    [h seekToFileOffset:p];
    uint64_t sz=[size toUInt32];
    NSData *data = [h readDataOfLength:sz];
    

    uint8_t * c = (uint8_t*)([data bytes]);
    NSDictionary *r=[self unpack_int_hex :c length:[size toUInt32] count:[count toUInt32] reset:[reset toBool] ];
    

    return r;
}

-(NSArray *)readFixedArray:(NSNumber *)handle pos:(JSValue *)pos count:(JSValue *)count unitsz:(JSValue *)unitsz {
    NSFileHandle *h=[self handleByFid :handle.intValue];
    if (!h) return nil;

    [h seekToFileOffset:[pos toUInt32]];
    uint32_t blocksize=[unitsz toUInt32] * [count toUInt32];
    NSData *data = [h readDataOfLength :blocksize];

    NSMutableArray* out=[NSMutableArray arrayWithCapacity :[count toUInt32]];

    uint32_t unit=[unitsz toUInt32];
    uint32_t cnt=[count toUInt32];
    int i;
    if (unit==1) {
        uint8_t* b1 = (uint8_t*)([data bytes]);
        for(i=0;i<cnt;i++) {
            [out addObject: [NSNumber numberWithUnsignedInt:*(b1+i)]];
        }
    } else if (unit==2) {
        uint16_t* b2 = (uint16_t*)([data bytes]);
        for(i=0;i<cnt;i++) {
            [out addObject: [NSNumber numberWithUnsignedInt:*(b2+i)]];
        }
    } else if (unit==4) {
        uint32_t* b4 = (uint32_t*)([data bytes]);
        for(i=0;i<cnt;i++) {
            [out addObject: [NSNumber numberWithUnsignedInt:*(b4+i)]];
        }
    } else {
        //throw unsuppoted unit sz
    }
    return out;
}
-(NSString*) readStringArray:(NSNumber *)handle pos:(JSValue *)pos  size:(JSValue *)size enc:(JSValue *)enc {
    NSString *s;

    if ( [[enc toString] isEqualToString:@"utf8"]) {
        s=[self readUTF8String :handle pos:pos size:size];
    } else{
        s=[self readULE16String :handle pos:pos size:size];
    }
      
    //NSArray *out= [s componentsSeparatedByString:@"\0"]; //client split , much faster
    return s;
}

@end

