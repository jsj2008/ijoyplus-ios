//
//  AppDelegate.m
//  yueshipin_ipad
//
//  Created by joyplus1 on 12-11-19.
//  Copyright (c) 2012年 joyplus. All rights reserved.
//

#import "AppDelegate.h"
#import "CommonHeader.h"
#import "OpenUDID.h"
#import "RootViewController.h"
#import "MobClick.h"
#import <Parse/Parse.h>

@interface AppDelegate ()
@property (nonatomic, assign) BOOL foreground;
@property (nonatomic, strong) Reachability *hostReach;
@property (nonatomic, strong) Reachability *internetReach;
@property (nonatomic, strong) Reachability *wifiReach;
@property (nonatomic, readonly) int networkStatus;
@property (strong, nonatomic) NSMutableArray *downloaderArray;
- (void)monitorReachability;

@end

@implementation AppDelegate
@synthesize window;
@synthesize rootViewController;
@synthesize closed;
@synthesize networkStatus;
@synthesize hostReach;
@synthesize internetReach;
@synthesize wifiReach;
@synthesize sinaweibo;
@synthesize downloaderArray;
@synthesize currentDownloadingNum;

+ (AppDelegate *) instance {
	return (AppDelegate *) [[UIApplication sharedApplication] delegate];
}

- (void)addToDownloaderArray:(DownloadItem *)item{
    McDownload *newdownloader = [[McDownload alloc] init];
    newdownloader.idNum = item.itemId;
    if(item.type != 1){
        newdownloader.subidNum = ((SubdownloadItem *)item).pk;
    }
    
    NSURL *url = [NSURL URLWithString:item.url];
    newdownloader.url = url;
    newdownloader.fileName = item.fileName;
    newdownloader.status = 3;
    [self.downloaderArray addObject:newdownloader];
    [[NSNotificationCenter defaultCenter] postNotificationName:ADD_NEW_DOWNLOAD_ITEM object:nil];
}

- (NSMutableArray *)getDownloaderQueue
{
    return self.downloaderArray;
}

- (void)deleteDownloaderInQueue:(DownloadItem *)item
{
    for (McDownload *downloader in self.downloaderArray) {
        if(item.type == 1){
            if([downloader.idNum isEqualToString:item.itemId]){
                [downloader stopAndClear];
                [self.downloaderArray removeObject:downloader];
                break;
            }
        } else {
            if([downloader.idNum isEqualToString:item.itemId] && downloader.subidNum == item.pk){
                [downloader stopAndClear];
                [self.downloaderArray removeObject:downloader];
                break;
            }
        }
    }
}

- (void)initAllDownloaders
{
    NSArray *allItem = [DownloadItem allObjects];
    self.downloaderArray = [[NSMutableArray alloc]initWithCapacity:allItem.count];
    for (DownloadItem *item in allItem) {
        if(item.type == 1){
            McDownload *newdownloader = [[McDownload alloc] init];
            newdownloader.idNum = item.itemId;
            NSURL *url = [NSURL URLWithString:item.url];
            newdownloader.url = url;
            newdownloader.fileName = item.fileName;
            if([item.downloadStatus isEqualToString:@"start"]){
                newdownloader.status = 1;
            } else if([item.downloadStatus isEqualToString:@"waiting"]){
                newdownloader.status = 3;
            } else if([item.downloadStatus isEqualToString:@"error"]){
                newdownloader.status = 4;
            } else if([item.downloadStatus isEqualToString:@"done"]){
                newdownloader.status = 2;
            } else {
                newdownloader.status = 0;
            }
            [self.downloaderArray addObject:newdownloader];
        } else {
            NSArray *subitems = [SubdownloadItem allObjects];
            for(SubdownloadItem *subitem in subitems){
                McDownload *newdownloader = [[McDownload alloc] init];
                newdownloader.idNum = subitem.itemId;
                newdownloader.subidNum = subitem.pk;
                NSURL *url = [NSURL URLWithString:subitem.url];
                newdownloader.url = url;
                newdownloader.fileName = subitem.fileName;
                if([subitem.downloadStatus isEqualToString:@"start"]){
                    newdownloader.status = 1;
                } else if([subitem.downloadStatus isEqualToString:@"waiting"]){
                    newdownloader.status = 3;
                } else if([subitem.downloadStatus isEqualToString:@"error"]){
                    newdownloader.status = 4;
                } else if([subitem.downloadStatus isEqualToString:@"done"]){
                    newdownloader.status = 2;
                } else {
                    newdownloader.status = 0;
                }
                [self.downloaderArray addObject:newdownloader];
            }
            
        }
    }
}

- (void)customizeAppearance
{
    // Set the background image for *all* UINavigationBars
    UIImage *gradientImage44 = [[UIImage imageNamed:@"nav_bar_bg_44"]resizableImageWithCapInsets:UIEdgeInsetsMake(0, 0, 0, 0)];
    [[UINavigationBar appearance] setBackgroundImage:gradientImage44 forBarMetrics:UIBarMetricsDefault];
}
- (void)initSinaweibo
{
    self.sinaweibo = [[SinaWeibo alloc] initWithAppKey:kSinaWeiboAppKey appSecret:kSinaWeiboAppSecret appRedirectURI:kSinaWeiboRedirectURL andDelegate:nil];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *sinaweiboInfo = [defaults objectForKey:@"SinaWeiboAuthData"];
    if ([sinaweiboInfo objectForKey:@"AccessTokenKey"] && [sinaweiboInfo objectForKey:@"ExpirationDateKey"] && [sinaweiboInfo objectForKey:@"UserIDKey"])
    {
        sinaweibo.accessToken = [sinaweiboInfo objectForKey:@"AccessTokenKey"];
        sinaweibo.expirationDate = [sinaweiboInfo objectForKey:@"ExpirationDateKey"];
        sinaweibo.userID = [sinaweiboInfo objectForKey:@"UserIDKey"];
    }
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [[AFHTTPRequestOperationLogger sharedLogger] startLogging];
    //    [MobClick startWithAppkey:umengAppKey reportPolicy:REALTIME channelId:nil];
    [MobClick checkUpdate];
    [self generateUserId];
    [self initSinaweibo];
    [self monitorReachability];
    [self isParseReachable];
    [Parse setApplicationId:@"FtAzML5ln4zKkcL28zc9XR6kSlSGwXLdnsQ2WESB" clientKey:@"YzMYsyKNV7ibjZMfIDSGoV5zxsylV4evtO8x64tl"];
    [application registerForRemoteNotificationTypes:UIRemoteNotificationTypeAlert|UIRemoteNotificationTypeBadge|UIRemoteNotificationTypeSound];
    if (application.applicationIconBadgeNumber != 0) {
        application.applicationIconBadgeNumber = 0;
        [[PFInstallation currentInstallation] saveEventually];
    }
    [self customizeAppearance];
    self.closed = YES;
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    [self initAllDownloaders];
    self.rootViewController = [[RootViewController alloc] initWithNibName:nil bundle:nil];
    self.window.rootViewController = self.rootViewController;
    [self.window makeKeyAndVisible];
    return YES;
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    [PFPush storeDeviceToken:deviceToken];
    if (application.applicationIconBadgeNumber != 0) {
        application.applicationIconBadgeNumber = 0;
    }
    [PFPush subscribeToChannelInBackground:@"" block:^(BOOL succeeded, NSError *error) {
        if (succeeded)
            NSLog(@"Successfully subscribed to broadcast channel!");
        else
            NSLog(@"Failed to subscribe to broadcast channel; Error: %@",error);
    }];
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    if (error.code == 3010) {
        NSLog(@"Push notifications are not supported in the iOS Simulator.");
    } else {
        // show some alert or otherwise handle the failure to register.
        NSLog(@"application:didFailToRegisterForRemoteNotificationsWithError: %@", error);
	}
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo {
    NSString *prodId = [NSString stringWithFormat:@"%@", [userInfo objectForKey:@"prod_id"]];
    NSString *prodType = [NSString stringWithFormat:@"%@", [userInfo objectForKey:@"prod_type"]];
    [PFPush handlePush:userInfo];
    if(!self.foreground && prodId != nil && prodType != nil){
        userInfo = [NSDictionary dictionaryWithObjectsAndKeys:prodId, @"prod_id", prodType, @"prod_type", nil];
        [[NSNotificationCenter defaultCenter]postNotificationName:@"push_notification" object:nil userInfo:userInfo];
    }
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    self.foreground = NO;
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    if (application.applicationIconBadgeNumber != 0) {
        application.applicationIconBadgeNumber = 0;
        [[PFInstallation currentInstallation] saveEventually];
    }
    [self.sinaweibo applicationDidBecomeActive];
    self.foreground = YES;
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

- (BOOL)isParseReachable {
    return self.networkStatus != NotReachable;
}
- (BOOL)isWifiReachable {
    return self.networkStatus == ReachableViaWiFi;
}
- (void)monitorReachability {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reachabilityChanged:) name:kReachabilityChangedNotification object:nil];
    
    self.hostReach = [Reachability reachabilityWithHostname: @"www.baidu.com"];
    [self.hostReach startNotifier];
    
    self.internetReach = [Reachability reachabilityForInternetConnection];
    [self.internetReach startNotifier];
    
    self.wifiReach = [Reachability reachabilityForLocalWiFi];
    [self.wifiReach startNotifier];
}
//Called by Reachability whenever status changes.
- (void)reachabilityChanged:(NSNotification* )note {
    Reachability *curReach = (Reachability *)[note object];
    NSParameterAssert([curReach isKindOfClass: [Reachability class]]);
    networkStatus = [curReach currentReachabilityStatus];
    if(self.networkStatus != NotReachable){
        NSLog(@"Network is fine.");
        [self generateUserId];
    }
}

- (void)generateUserId
{
    NSString *userId = (NSString *)[[ContainerUtility sharedInstance]attributeForKey:kUserId];
    if(userId == nil){
        Reachability *tempHostReach = [Reachability reachabilityForInternetConnection];
        if([tempHostReach currentReachabilityStatus] != NotReachable) {
            NSDictionary *parameters = [NSDictionary dictionaryWithObjectsAndKeys:  [OpenUDID value], @"uiid", nil];
            [[AFServiceAPIClient sharedClient] postPath:kPathGenerateUIID parameters:parameters success:^(AFHTTPRequestOperation *operation, id result) {
                NSString *responseCode = [result objectForKey:@"res_code"];
                if (responseCode == nil) {
                    NSString *user_id = [result objectForKey:@"user_id"];
                    NSString *nickname = [result objectForKey:@"nickname"];
                    NSString *username = [result objectForKey:@"username"];
                    [[ContainerUtility sharedInstance] setAttribute:user_id forKey:kUserId];
                    [[ContainerUtility sharedInstance] setAttribute:[NSString stringWithFormat:@"%@", nickname] forKey:kUserNickName];
                    [[ContainerUtility sharedInstance] setAttribute:username forKey:kUserName];
                    [[AFServiceAPIClient sharedClient] setDefaultHeader:@"user_id" value:user_id];
                }
            } failure:^(__unused AFHTTPRequestOperation *operation, NSError *error) {
                NSLog(@"%@", error);
            }];
        }
    } else {
        [[AFServiceAPIClient sharedClient] setDefaultHeader:@"user_id" value:userId];
    }
}

- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url
{
    return [self.sinaweibo handleOpenURL:url];
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
    return [self.sinaweibo handleOpenURL:url];
}

//下载失败
- (void)downloadFaild:(McDownload *)aDownload didFailWithError:(NSError *)error
{
    NSLog(@"下载失败 %@", error);
    aDownload.status = 4;
    [AppDelegate instance].currentDownloadingNum--;
    if([AppDelegate instance].currentDownloadingNum < 0){
        [AppDelegate instance].currentDownloadingNum = 0;
    }
    NSString *subquery = [NSString stringWithFormat:@"WHERE item_id = '%@'", aDownload.idNum];
    NSArray *subitems = [SubdownloadItem findByCriteria:subquery];
    for (int i = 0; i < subitems.count; i++) {
        SubdownloadItem *item = [subitems objectAtIndex:i];
        if ([item.itemId isEqualToString:aDownload.idNum] && aDownload.subidNum == item.pk) {
            item.downloadStatus = @"error";
            [item save];
        }
        
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:ADD_NEW_DOWNLOAD_ITEM object:nil];
}
//下载结束
- (void)downloadFinished:(McDownload *)aDownload
{
    NSLog(@"下载完成");
    aDownload.status = 2;
    [AppDelegate instance].currentDownloadingNum--;
    if([AppDelegate instance].currentDownloadingNum < 0){
        [AppDelegate instance].currentDownloadingNum = 0;
    }
    NSString *subquery = [NSString stringWithFormat:@"WHERE item_id = '%@'", aDownload.idNum];
    NSArray *subitems = [SubdownloadItem findByCriteria:subquery];
    for (int i = 0; i < subitems.count; i++) {
        SubdownloadItem *item = [subitems objectAtIndex:i];
        if ([item.itemId isEqualToString:aDownload.idNum] && aDownload.subidNum == item.pk) {
            item.percentage = 100;
            item.downloadStatus  = @"done";
            [item save];
        }
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:ADD_NEW_DOWNLOAD_ITEM object:nil];
}

@end
