//
//  VideoDetailViewController.h
//  yueshipin_ipad
//
//  Created by joyplus1 on 12-11-29.
//  Copyright (c) 2012年 joyplus. All rights reserved.
//

#import "GenericBaseViewController.h"
#import "SinaWeibo.h"

@protocol VideoDetailViewControllerDelegate <NSObject>

- (void)refreshCommentListView:(int)tableHeight;
- (void)getTopComments:(int)num;
- (void)showSublistView:(int)num;
@end

@interface VideoDetailViewController : GenericBaseViewController  <SinaWeiboDelegate, SinaWeiboRequestDelegate, VideoDetailViewControllerDelegate>{
        SinaWeibo *_sinaweibo;
        NSDictionary *video;
        NSArray *topics;
}
@property (strong, nonatomic)NSString *prodId;
- (void)shareBtnClicked;
- (NSString *)parseVideoUrl:(NSDictionary *)tempVideo;
- (void)addListBtnClicked;
@end