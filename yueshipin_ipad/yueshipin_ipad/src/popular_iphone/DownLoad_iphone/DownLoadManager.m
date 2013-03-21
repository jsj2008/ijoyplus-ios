//
//  DownLoadManager.m
//  yueshipin
//
//  Created by 08 on 13-1-17.
//  Copyright (c) 2013年 joyplus. All rights reserved.
//

#import "DownLoadManager.h"
#import "DownloadItem.h"
#import "SubdownloadItem.h"
#import "AFDownloadRequestOperation.h"
#import "Reachability.h"
#import "CacheUtility.h"
static DownLoadManager *downLoadManager_ = nil;
static NSMutableArray *downLoadQueue_ = nil;
@implementation DownLoadManager
@synthesize downloadThread = downloadThread_;
@synthesize downloadId = downloadId_;
@synthesize allItems = allItems_;
@synthesize allSubItems = allSubItems_;
@synthesize downloadItem = downloadItem_;
@synthesize subdownloadItem = subdownloadItem_;
@synthesize lock = lock_;
+(DownLoadManager *)defaultDownLoadManager{
    if (downLoadManager_ == nil) {
        downLoadManager_ = [[DownLoadManager alloc] init];
        [downLoadManager_ initDownLoadManager];
        
    }
    return downLoadManager_;
}

-(void)initDownLoadManager{
    Reachability *hostReach = [Reachability reachabilityForInternetConnection];
    netWorkStatus = [hostReach currentReachabilityStatus];
   
    downLoadQueue_ = [[NSMutableArray alloc] initWithCapacity:10];
    lock_ = [[NSLock alloc] init];
    [[NSNotificationCenter defaultCenter]
     addObserver:self selector:@selector(addtoDownLoadQueue:) name:@"DOWNLOAD_MSG" object:nil];
}

-(void)addtoDownLoadQueue:(id)sender{
    if ([self getFreeSpace]< 500) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"警告" message:@"剩余磁盘容量已不足500M." delegate:self cancelButtonTitle:@"我知道了" otherButtonTitles:nil, nil];
        [alert show];
        return;
    }
    NSArray *infoArr = (NSArray *)((NSNotification *)sender).object;
    NSString *prodId = [infoArr objectAtIndex:0];
    NSString *urlStr = [infoArr objectAtIndex:1];
    NSString *fileName = [infoArr objectAtIndex:2];
    NSString *imgUrl = [infoArr objectAtIndex:3];
    NSString *type = [infoArr objectAtIndex:4];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr] cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:60];
    AFDownloadRequestOperation *downloadingOperation = nil;
    NSArray  *documentPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDir = [documentPaths objectAtIndex:0];
    NSString *filePath = nil;
    if ([type isEqualToString:@"1"]){
        DownloadItem *item = [[DownloadItem alloc]init];
        item.itemId = prodId;
        item.name = fileName;
        item.percentage = 0;
        item.type = 1;
        item.url = urlStr;
        item.imageUrl = imgUrl;
        item.downloadStatus = @"waiting";
        [item save];
        
        filePath = [NSString stringWithFormat:@"%@/%@.mp4", documentsDir,prodId];
        downloadingOperation = [[AFDownloadRequestOperation alloc] initWithRequest:request targetPath:filePath shouldResume:YES];
        downloadingOperation.operationId = prodId;
        
        
    } else {
        NSArray *itemArr = [DownloadItem allObjects];
        BOOL isHave = NO;
        for (DownloadItem *item in itemArr) {
            if ([item.itemId isEqualToString:prodId]) {
                isHave = YES;
                break;
            }
        }
        if (!isHave) {
            DownloadItem *item = [[DownloadItem alloc]init];
            item.itemId = prodId;
            if ([fileName rangeOfString:@"_"].location != NSNotFound) {
                item.name = [[fileName componentsSeparatedByString:@"_"] objectAtIndex:0];
            }
            
            item.imageUrl = imgUrl;
            [item save];
        }

        SubdownloadItem *subItem = [[SubdownloadItem alloc] init];
        subItem.itemId = prodId;
        subItem.percentage = 0;
        subItem.type = [type intValue];
        subItem.url = urlStr;
        subItem.imageUrl = imgUrl;
        int num = [[infoArr objectAtIndex:5] intValue];
        num++;
        subItem.name = fileName;
        subItem.subitemId = [NSString stringWithFormat:@"%@_%d",prodId,num];
        subItem.downloadStatus = @"waiting";
        [subItem save];
        filePath = [NSString stringWithFormat:@"%@/%@_%d.mp4", documentsDir, prodId,num];
        downloadingOperation = [[AFDownloadRequestOperation alloc] initWithRequest:request targetPath:filePath shouldResume:YES];
        downloadingOperation.operationId = [NSString stringWithFormat:@"%@_%d",prodId,num];
    }
       downloadingOperation.operationStatus = @"waiting";
      [downLoadQueue_ addObject:downloadingOperation];
  
        [self startDownLoad];
        [self waringPlus];
    
}

-(void)resumeDownLoad{
    [downLoadQueue_ removeAllObjects];
    NSArray  *documentPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDir = [documentPaths objectAtIndex:0];
    
    NSArray *allItems = [DownloadItem allObjects];
    for ( DownloadItem *item in allItems) {
        if (item.type == 1) {
            if (![item.downloadStatus isEqualToString:@"finish"]) {
                NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:item.url] cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:60];
                 NSString *filePath = [NSString stringWithFormat:@"%@/%@.mp4", documentsDir,item.itemId];
                 AFDownloadRequestOperation *downloadingOperation= [[AFDownloadRequestOperation alloc] initWithRequest:request targetPath:filePath shouldResume:YES];
               
                downloadingOperation.operationId = item.itemId;
                if ([item.downloadStatus isEqualToString:@"stop"]) {
                    downloadingOperation.operationStatus = @"stop";
                }
                else if ([item.downloadStatus isEqualToString:@"loading"]) {
                    downloadingOperation.operationStatus = @"loading";
                }
                else if ([item.downloadStatus isEqualToString:@"finish"]) {
                    downloadingOperation.operationStatus = @"finish";
                }
                else if ([item.downloadStatus isEqualToString:@"waiting"]) {
                    downloadingOperation.operationStatus = @"waiting";
                }
                else if ([item.downloadStatus isEqualToString:@"fail"]) {
                    downloadingOperation.operationStatus = @"fail";
                }
                [downLoadQueue_ addObject:downloadingOperation];
            }
        }
        else{
            NSString *subquery = [NSString stringWithFormat:@"WHERE item_id = '%@' AND download_status != '%@'", item.itemId,@"finish"];
            NSArray *tempArr = [SubdownloadItem findByCriteria:subquery];
            
            for (SubdownloadItem *sub in tempArr) {
                
                NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:sub.url] cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:60];
                NSString *filePath = [NSString stringWithFormat:@"%@/%@.mp4", documentsDir,sub.subitemId];
                AFDownloadRequestOperation *downloadingOperation= [[AFDownloadRequestOperation alloc] initWithRequest:request targetPath:filePath shouldResume:YES];
                //downloadingOperation.operationId = [NSString stringWithFormat:@"%d_%d",[sub.subitemId intValue]/10,[sub.subitemId intValue]%10];
                downloadingOperation.operationId = sub.subitemId;
            
                if ([sub.downloadStatus isEqualToString:@"stop"]) {
                    downloadingOperation.operationStatus = @"stop";
                }
                else if ([sub.downloadStatus isEqualToString:@"loading"]) {
                    downloadingOperation.operationStatus = @"loading";
                }
                else if ([sub.downloadStatus isEqualToString:@"finish"]) {
                    downloadingOperation.operationStatus = @"finish";
                }
                else if ([sub.downloadStatus isEqualToString:@"waiting"]) {
                    downloadingOperation.operationStatus = @"waiting";
                }
                else if ([sub.downloadStatus isEqualToString:@"fail"]) {
                    downloadingOperation.operationStatus = @"fail";
                }

                [downLoadQueue_ addObject:downloadingOperation];
                
            }
        
        }
    
    
    }
    BOOL isdownloading = NO;
    for (AFDownloadRequestOperation *downloadItem in downLoadQueue_) {
        if ([downloadItem.operationStatus isEqualToString:@"loading"] ) {    //0:stop 1:start 2:done 3: waiting 4:fail
             [self beginDownloadTask:downloadItem];
            isdownloading = YES;
            break;
        }
    }
    
    if (!isdownloading) {
        for (AFDownloadRequestOperation *downloadItem in downLoadQueue_) {
            if ([downloadItem.operationStatus isEqualToString:@"waiting"]|| [downloadItem.operationStatus isEqualToString:@"fail"] ) {    //0:stop 1:start 2:done 3: waiting 4:fail
                [self beginDownloadTask:downloadItem];
                break;
            }
        }
    }
    
}

-(void)startDownLoad{
        [lock_ lock];
        BOOL isDownloading = NO;
        for (AFDownloadRequestOperation  *downloadRequestOperation in downLoadQueue_){
            if ([downloadRequestOperation.operationStatus isEqualToString:@"loading"]) {
                isDownloading = YES;
                break;
            }
            
        }
        if (!isDownloading) {
            for (AFDownloadRequestOperation  *downloadRequestOperation in downLoadQueue_){
                if ([downloadRequestOperation.operationStatus isEqualToString:@"waiting"]|| [downloadRequestOperation.operationStatus isEqualToString:@"fail"]) {
                    
                    [self beginDownloadTask:downloadRequestOperation];
                    break;
                }
                
            }
        }
    [lock_ unlock];
}

-(void)restartDownload{
     for (AFDownloadRequestOperation  *downloadRequestOperation in downLoadQueue_){
        if ([downloadRequestOperation.operationStatus isEqualToString:@"loading"]) {
           [self beginDownloadTask:downloadRequestOperation];
            return;
        }
        
    }
    for (AFDownloadRequestOperation  *downloadRequestOperation in downLoadQueue_){
         if ([downloadRequestOperation.operationStatus isEqualToString:@"waiting"]|| [downloadRequestOperation.operationStatus isEqualToString:@"fail"]) {
            [self beginDownloadTask:downloadRequestOperation];
            return;
        }
        
    }
}

-(void)beginDownloadTask:(AFDownloadRequestOperation*)downloadRequestOperation{
    
    [downloadRequestOperation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        if ([downLoadQueue_ containsObject:operation]) {
            [downLoadQueue_ removeObject:operation];
        }
        
        NSRange range = [downloadId_ rangeOfString:@"_"];
        if (range.location == NSNotFound){
             [self saveDataBaseIntable:@"DownloadItem" withId:downloadId_ withStatus:@"finish" withPercentage:100];
             [self.downLoadMGdelegate downloadFinishwithId:downloadId_ inClass:@"IphoneDownloadViewController"];
            
        }
        else{
            [self saveDataBaseIntable:@"SubdownloadItem" withId:downloadId_ withStatus:@"finish" withPercentage:100];
            [self.downLoadMGdelegate downloadFinishwithId:downloadId_ inClass:@"IphoneSubdownloadViewController"];
            
        }
        [self waringReduce];
        [self startDownLoad];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Error: %@", error);
        [operation cancel];
        if (error.code == -1011) {
            downloadRequestOperation.operationStatus = @"fail_1011";
            
            NSRange range = [downloadId_ rangeOfString:@"_"];
            if (range.location == NSNotFound){
                [self saveDataBaseIntable:@"DownloadItem" withId:downloadId_ withStatus:@"fail_1011" withPercentage:-1];
                [self.downLoadMGdelegate downloadUrlTnvalidWithId:downloadId_ inClass:@"IphoneDownloadViewController"];
                
            }
            else{
                [self saveDataBaseIntable:@"SubdownloadItem" withId:downloadId_ withStatus:@"fail_1011" withPercentage:-1];
                [self.downLoadMGdelegate downloadUrlTnvalidWithId:downloadId_ inClass:@"IphoneSubdownloadViewController"];
                
            }

            
        }
        else{
            downloadRequestOperation.operationStatus = @"fail";
            NSRange range = [downloadId_ rangeOfString:@"_"];
            if (range.location == NSNotFound){
                [self saveDataBaseIntable:@"DownloadItem" withId:downloadId_ withStatus:@"fail" withPercentage:-1];
                [self.downLoadMGdelegate downloadFailedwithId:downloadId_ inClass:@"IphoneDownloadViewController"];
                
            }
            else{
                [self saveDataBaseIntable:@"SubdownloadItem" withId:downloadId_ withStatus:@"fail" withPercentage:-1];
                [self.downLoadMGdelegate downloadFailedwithId:downloadId_ inClass:@"IphoneSubdownloadViewController"];
                
            }
}
        if ([downLoadQueue_ containsObject:downloadRequestOperation]) {
            [downLoadQueue_ removeObject:downloadRequestOperation];
        }
        
                
        [self startDownLoad];
    }];
    
    [downloadRequestOperation setProgressiveDownloadProgressBlock:^(NSInteger bytesRead, long long totalBytesRead, long long totalBytesExpected, long long totalBytesReadForFile, long long totalBytesExpectedToReadForFile) {
        
        float percentDone = totalBytesReadForFile/(float)totalBytesExpectedToReadForFile;
           
            NSRange range = [downloadId_ rangeOfString:@"_"];
            if (range.location == NSNotFound) {
             int count = (int)(percentDone*100) - downloadItem_.percentage;
//                NSLog(@"!!!!!!!!!!!!!!!!%d",(int)(percentDone*100));
                downloadItem_.percentage = (int)(percentDone*100);
                if (count >= 1){     
                    [self.downLoadMGdelegate reFreshProgress:percentDone withId:downloadId_ inClass:@"IphoneDownloadViewController"];
                    if (count >=5) {
                        [downloadItem_ save];
                    }
                }
            }else{
                 int count = (int)(percentDone*100) - subdownloadItem_.percentage;
//                 NSLog(@"!!!!!!!!!!!!!!!!%d",(int)(percentDone*100));
                 subdownloadItem_.percentage = (int)(percentDone*100);
                  if (count >= 1) {
                    [self.downLoadMGdelegate reFreshProgress:percentDone withId:downloadId_ inClass:@"IphoneSubdownloadViewController"];
                    if (count >=5) {
                        [subdownloadItem_ save];
                    }
                }
         }
            
      }];
    
    [downloadRequestOperation start];
    downloadId_ = downloadRequestOperation.operationId;
    downloadRequestOperation.operationStatus = @"loading";
     NSRange range = [downloadId_ rangeOfString:@"_"];
    if (range.location == NSNotFound) {
         NSString *query = [NSString stringWithFormat:@"WHERE item_id ='%@'",downloadId_];
         NSArray *itemArr = [DownloadItem findByCriteria:query];
        if ([itemArr count]>0) {
            int percet = ((DownloadItem *)[itemArr objectAtIndex:0]).percentage;
             downloadItem_ = (DownloadItem *)[itemArr objectAtIndex:0];
            [self saveDataBaseIntable:@"DownloadItem" withId:downloadId_ withStatus:@"loading" withPercentage:percet];
        }
        else{
            [self saveDataBaseIntable:@"DownloadItem" withId:downloadId_ withStatus:@"loading" withPercentage:0];
        }
        
         [self.downLoadMGdelegate downloadBeginwithId:downloadId_ inClass:@"IphoneDownloadViewController"];

    }
    else{
        NSString *query = [NSString stringWithFormat:@"WHERE subitem_id ='%@'",downloadId_];
        NSArray *itemArr = [SubdownloadItem findByCriteria:query];
        if ([itemArr count]>0) {
            int percet = ((SubdownloadItem *)[itemArr objectAtIndex:0]).percentage;
            subdownloadItem_ = (SubdownloadItem *)[itemArr objectAtIndex:0];
            [self saveDataBaseIntable:@"SubdownloadItem" withId:downloadId_ withStatus:@"loading" withPercentage:percet];
        }
        else{
            [self saveDataBaseIntable:@"SubdownloadItem" withId:downloadId_ withStatus:@"loading" withPercentage:0];
        }
        [self.downLoadMGdelegate downloadBeginwithId:downloadId_ inClass:@"IphoneSubdownloadViewController"];

    }
    
    
}

-(void)saveDataBaseIntable:(NSString *)tableName withId:(NSString *)itenId withStatus:(NSString *)status withPercentage:(int)percentage{
    if ([tableName isEqualToString:@"DownloadItem"]) {
        allItems_ = [DownloadItem allObjects];
        for (DownloadItem *item in allItems_) {
            if ([item.itemId isEqualToString:itenId]) {
                item.downloadStatus = status;
                if (percentage >= 0) {
                item.percentage = percentage;
                    
                }
                if (percentage == 0) {
                    downloadItem_ = item;
                }
               // downloadItem_ = item;
                [item save];
                break;
            }
            
        }

    }
    else if ([tableName isEqualToString:@"SubdownloadItem"]){
        allSubItems_ = [SubdownloadItem allObjects];
        for (SubdownloadItem *item in allSubItems_) {
            if ([item.subitemId isEqualToString:itenId]){
                item.downloadStatus = status;
                if (percentage >= 0) {
                    item.percentage = percentage;
                }
                if (percentage == 0) {
                    subdownloadItem_ = item;
                }
                //subdownloadItem_ = item;
                [item save];
                break;
            }
        }

    
    
    }

}


//停止下载并清除缓存
+(void)stopAndClear:(NSString *)downloadId{
    AFDownloadRequestOperation *downloadOperation = nil;
    for (AFDownloadRequestOperation *mc in downLoadQueue_) {
        if ([mc.operationId isEqualToString:downloadId]) {
            downloadOperation = mc;
            break;
        }
    }
    if (downloadOperation != nil) {
         [downloadOperation pause];
         [downloadOperation cancel];
        [downLoadQueue_ removeObject:downloadOperation];
    }
    [[DownLoadManager defaultDownLoadManager] startDownLoad];
    [[DownLoadManager defaultDownLoadManager] waringReduce];
}

//停止下载不清除缓存
+(void)stop:(NSString *)downloadId{
    if ([DownLoadManager defaultDownLoadManager].downloadItem != nil) {
         [[DownLoadManager defaultDownLoadManager].downloadItem save];
    }
    
    if ([DownLoadManager defaultDownLoadManager].subdownloadItem != nil) {
        [[DownLoadManager defaultDownLoadManager].subdownloadItem save];
    }
    
   AFDownloadRequestOperation *downloadOperation = nil;
    for (AFDownloadRequestOperation *mc in downLoadQueue_) {
        if ([mc.operationId isEqualToString:downloadId]) {
            downloadOperation = mc;
            break;
        }
    }
    if (downloadOperation != nil) {
        downloadOperation.operationStatus = @"stop";
        [downloadOperation pause];
        [downloadOperation cancel];
        
        //AFDownloadRequestOperation cancel 之后就不能再连接了，重新初始化一个新的AFDownloadRequestOperation对象，替换原有对象；
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:downloadOperation.request.URL cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:60];
        AFDownloadRequestOperation *newDownloadingOperation = [[AFDownloadRequestOperation alloc] initWithRequest:request targetPath:downloadOperation.targetPath shouldResume:YES];
        newDownloadingOperation.operationId = downloadOperation.operationId;
        newDownloadingOperation.operationStatus = @"stop";
        int index = [downLoadQueue_ indexOfObject:downloadOperation];
        [downLoadQueue_ replaceObjectAtIndex:index withObject:newDownloadingOperation];
        
        BOOL isloading = NO;
        for (AFDownloadRequestOperation *mc in downLoadQueue_){
            if ([mc.operationStatus isEqualToString:@"loading"]) {
                isloading = YES;
                break;
            }
        }
        
        if (!isloading) {
            for (AFDownloadRequestOperation *mc in downLoadQueue_) {
                if (![mc.operationStatus isEqualToString:@"stop"]&&![mc.operationStatus isEqualToString:@"fail_1011"] ) {
                    [[DownLoadManager defaultDownLoadManager] beginDownloadTask:mc];
                    break;
                }
            }

        }
    }

}
+(void)continueDownload:(NSString *)downloadId{
    for (AFDownloadRequestOperation *mc in downLoadQueue_) {
        if ([mc.operationId isEqualToString:downloadId]) {
            mc.operationStatus = @"waiting";
            break;
        }
    
    }
    BOOL isLoading = NO;
    for (AFDownloadRequestOperation *mc in downLoadQueue_){
        if ([mc.operationStatus isEqualToString:@"loading"]) {
            isLoading = YES;
            break;
        }
    }
    if (!isLoading) {
        for (AFDownloadRequestOperation *mc in downLoadQueue_) {
            if (![mc.operationStatus isEqualToString:@"stop"]&&![mc.operationStatus isEqualToString:@"fail_1011"]) {
                [[DownLoadManager defaultDownLoadManager] beginDownloadTask:mc];
                break;
            }
        }
    }
  
    
}

+(int)downloadTaskCount{
    int count = 0;
    for (AFDownloadRequestOperation *mc in downLoadQueue_) {
        if (![mc.operationStatus isEqualToString:@"finish" ]) { //0:stop 1:start 2:done 3: waiting 4:error
            count++;
        }
    }
    return count;
}
-(void)appDidEnterBackground{
    for (AFDownloadRequestOperation *mc in downLoadQueue_){
        [mc pause];
        [mc cancel];
    }
}
-(void)appDidEnterForeground{
    NSMutableArray *tempQueue = [NSMutableArray arrayWithArray:downLoadQueue_];
    [downLoadQueue_ removeAllObjects];
    for (AFDownloadRequestOperation *downloadOperation in tempQueue){
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:downloadOperation.request.URL cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:60];
        AFDownloadRequestOperation *newDownloadingOperation = [[AFDownloadRequestOperation alloc] initWithRequest:request targetPath:downloadOperation.targetPath shouldResume:YES];
        newDownloadingOperation.operationId = downloadOperation.operationId;
        newDownloadingOperation.operationStatus = downloadOperation.operationStatus;
        [downLoadQueue_ addObject:newDownloadingOperation];

    }
    
    for (AFDownloadRequestOperation  *downloadRequestOperation in downLoadQueue_){
        if ([downloadRequestOperation.operationStatus isEqualToString:@"loading"]) {
            [self beginDownloadTask:downloadRequestOperation];
            return;
        }
        
    }
    for (AFDownloadRequestOperation  *downloadRequestOperation in downLoadQueue_){
        if ([downloadRequestOperation.operationStatus isEqualToString:@"fail"]) {
            [self beginDownloadTask:downloadRequestOperation];
            return;
        }
        
    }
    
    for (AFDownloadRequestOperation  *downloadRequestOperation in downLoadQueue_){
        if ([downloadRequestOperation.operationStatus isEqualToString:@"waiting"]) {
            [self beginDownloadTask:downloadRequestOperation];
            return;
        }
        
        
    }
    
    
}

-(void)networkChanged:(int)status{
    if (status == netWorkStatus) {
        return;
    }
    else{
        netWorkStatus = status;
        if(netWorkStatus == 0){
            [self appDidEnterBackground];
        }
        else{
            [self appDidEnterForeground];
        }
    }
}
-(float)getFreeSpace{
    NSError *error = nil;
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    
    NSDictionary *dictionary = [[NSFileManager defaultManager] attributesOfFileSystemForPath:[paths lastObject] error: &error];
    
    if (dictionary) {
          
        NSNumber *freeFileSystemSizeInBytes = [dictionary objectForKey:NSFileSystemFreeSize];
       return [freeFileSystemSizeInBytes floatValue]/1024.0f/1024.0f;
    }
    return 0.0;


}
-(void)waringPlus{
    NSString *numStr = [[CacheUtility sharedCache] loadFromCache:@"warning_number"];
    int num = 0;
    if (numStr != nil) {
        num = [numStr intValue];
        num++;
    }
    [[CacheUtility sharedCache] putInCache:@"warning_number" result:[NSString stringWithFormat:@"%d",num]];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"SET_WARING_NUM" object:nil];
}
-(void)waringReduce{
    NSString *numStr = [[CacheUtility sharedCache] loadFromCache:@"warning_number"];
    int num = 0;
    if (numStr != nil) {
        num = [numStr intValue];
        if (num >0) {
            num --;
        }
    }
 [[CacheUtility sharedCache] putInCache:@"warning_number" result:[NSString stringWithFormat:@"%d",num]];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"SET_WARING_NUM" object:nil];
}
@end
