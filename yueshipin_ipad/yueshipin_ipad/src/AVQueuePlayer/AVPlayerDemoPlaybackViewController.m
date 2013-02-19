
#import "AVPlayerDemoPlaybackViewController.h"
#import "AVPlayerDemoPlaybackView.h"
#import <MediaPlayer/MediaPlayer.h>
#import "EpisodeListViewController.h"
#import "CommonHeader.h"
#import "CMPopTipView.h"

#define TOP_TOOLBAR_HEIGHT 50
#define BOTTOM_TOOL_VIEW_HEIGHT 150
#define BOTTOM_TOOLBAR_HEIGHT 100
#define BUTTON_HEIGHT 50
#define EPISODE_ARRAY_VIEW_TAG 76892367

/* Asset keys */
NSString * const kTracksKey         = @"tracks";
NSString * const kPlayableKey		= @"playable";

/* PlayerItem keys */
NSString * const kStatusKey         = @"status";

/* AVPlayer keys */
NSString * const kRateKey			= @"rate";
NSString * const kCurrentItemKey	= @"currentItem";


@interface AVPlayerDemoPlaybackViewController () <UIGestureRecognizerDelegate>
@property (nonatomic, strong) UIToolbar *topToolbar;
@property (nonatomic, strong) UIView *bottomView;
@property (nonatomic, strong) MPVolumeView *volumeSlider;
@property (nonatomic, strong) MPVolumeView *routeBtn;
@property (nonatomic, strong) UILabel *currentPlaybackTimeLabel;
@property (nonatomic, strong) UILabel *totalTimeLabel;
@property (nonatomic, strong) UIButton *volumeBtn;
@property (nonatomic, strong) UIButton *selectButton;
@property (nonatomic, strong) UIButton *qualityBtn;
@property (nonatomic, strong) UIView *playCacheView;
@property (nonatomic, strong) NSLock *theLock;
@property (nonatomic, strong) NSTimer *controlVisibilityTimer;
@property (nonatomic, strong) MBProgressHUD *myHUD;
@property (nonatomic, strong) EpisodeListViewController *episodeListviewController;
@property (nonatomic, strong) CMPopTipView *resolutionPopTipView;
@property (nonatomic, strong) UIButton *biaoqingBtn;
@property (nonatomic, strong) UIButton *gaoqingBtn;
@property (nonatomic, strong) UIButton *chaoqingBtn;
@property (nonatomic, strong) UILabel *vidoeTitle;
@property (atomic, strong) NSURL *workingUrl;
@property (atomic) int errorUrlNum;
@property (nonatomic) NSString *resolution;
@end

@interface AVPlayerDemoPlaybackViewController (Player)
- (void)removePlayerTimeObserver;
- (CMTime)playerItemDuration;
- (BOOL)isPlaying;
- (void)playerItemDidReachEnd:(NSNotification *)notification ;
- (void)observeValueForKeyPath:(NSString*) path ofObject:(id)object change:(NSDictionary*)change context:(void*)context;
- (void)prepareToPlayAsset:(AVURLAsset *)asset withKeys:(NSArray *)requestedKeys;
@end

static void *AVPlayerDemoPlaybackViewControllerRateObservationContext = &AVPlayerDemoPlaybackViewControllerRateObservationContext;
static void *AVPlayerDemoPlaybackViewControllerStatusObservationContext = &AVPlayerDemoPlaybackViewControllerStatusObservationContext;
static void *AVPlayerDemoPlaybackViewControllerCurrentItemObservationContext = &AVPlayerDemoPlaybackViewControllerCurrentItemObservationContext;

#pragma mark -
@implementation AVPlayerDemoPlaybackViewController
@synthesize mPlayer, mPlayerItem, mPlaybackView;
@synthesize mToolbar, topToolbar, mPlayButton, mStopButton, mScrubber, mNextButton, mPrevButton, volumeSlider, mSwitchButton;
@synthesize currentPlaybackTimeLabel, totalTimeLabel, volumeBtn, qualityBtn, videoUrls, selectButton;
@synthesize playCacheView, resolution, videoHttpUrl;
@synthesize type, isDownloaded, currentNum, errorUrlNum, theLock, closeAll;
@synthesize workingUrl, myHUD, bottomView, controlVisibilityTimer;
@synthesize episodeListviewController, name, subnameArray;
@synthesize resolutionPopTipView, biaoqingBtn, chaoqingBtn, gaoqingBtn, routeBtn;
@synthesize vidoeTitle, videoWebViewControllerDelegate;

#pragma mark
#pragma mark View Controller

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
	if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]))
	{
		mPlayer = nil;
		
		[self setWantsFullScreenLayout:YES];
	}
	
	return self;
}

- (id)init
{
    self = [super init];
    mPlayer = nil;
    [self setWantsFullScreenLayout:YES];
    return self;
}

- (void)viewDidUnload
{
    [self removePlayerTimeObserver];
	[mPlayer removeObserver:self forKeyPath:@"rate"];
	[mPlayer.currentItem removeObserver:self forKeyPath:@"status"];
	[mPlayer pause];
    topToolbar = nil;
    self.mPlaybackView = nil;
    self.mToolbar = nil;
    self.mPlayButton = nil;
    self.mStopButton = nil;
    self.mScrubber = nil;
    [super viewDidUnload];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    resolution = GAO_QING;
    [self showPlayVideoView];
    [self customizeBottomToolbar];
    [self playVideo];
    [self customizeTopToolbar];
    
    episodeListviewController = [[EpisodeListViewController alloc]init];
    [self addChildViewController:episodeListviewController];
    episodeListviewController.type = self.type;
    episodeListviewController.delegate = self;
    episodeListviewController.view.tag = EPISODE_ARRAY_VIEW_TAG;
    episodeListviewController.table.frame = CGRectMake(0, 0, EPISODE_TABLE_WIDTH, 0);
    episodeListviewController.view.frame = CGRectMake(topToolbar.frame.size.width - 20 - EPISODE_TABLE_WIDTH, TOP_TOOLBAR_HEIGHT + 24, EPISODE_TABLE_WIDTH, 0);
    
    UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(showToolview)];
    tapRecognizer.numberOfTapsRequired = 1;
    tapRecognizer.delegate = self;
    tapRecognizer.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:tapRecognizer];
}

- (void)playVideo
{
    if(videoUrls.count > 0){
        [self showPlayCacheView];
        if (isDownloaded) {
            workingUrl = [[NSURL alloc] initFileURLWithPath:[videoUrls objectAtIndex:0]];
            [self setURL:workingUrl];
        } else {
            theLock = [[NSLock alloc]init];
            for (NSString *url in [[videoUrls objectAtIndex:currentNum] objectForKey:resolution]) {
                int nowDate = [[NSDate date] timeIntervalSince1970];
                NSString *formattedUrl = url;
                if([url rangeOfString:@"{now_date}"].location != NSNotFound){
                    formattedUrl = [url stringByReplacingOccurrencesOfString:@"{now_date}" withString:[NSString stringWithFormat:@"%i", nowDate]];
                }
                NSURLRequest *request = [[NSURLRequest alloc]initWithURL:[NSURL URLWithString:formattedUrl] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:5];
                [NSURLConnection connectionWithRequest:request delegate:self];
            }
        }
    } else if (videoHttpUrl){
        //        [self showWebView];
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
	[mPlayer pause];
	[super viewWillDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    if([NSStringFromClass([touch.view class]) isEqualToString:@"UITableViewCellContentView"]){
        return NO;
    } else if ([NSStringFromClass([touch.view class]) isEqualToString:@"UIButton"]){
        [self resetControlVisibilityTimer];
        return NO;
    } else if ([NSStringFromClass([touch.view class]) isEqualToString:@"MPButton"]){
        [self resetControlVisibilityTimer];
        return NO;
    } else if ([NSStringFromClass([touch.view class]) isEqualToString:@"UIToolbar"]){
        [self resetControlVisibilityTimer];
        return NO;
    }else {
        return YES;
    }
}

- (void)resetControlVisibilityTimer
{
    [controlVisibilityTimer invalidate];
    controlVisibilityTimer = [NSTimer scheduledTimerWithTimeInterval:4 target:self selector:@selector(showToolview) userInfo:nil repeats:NO];
}

- (void)showToolview
{
    if (bottomView.hidden) {
        topToolbar.alpha = 1;
        bottomView.alpha = 1;
        resolutionPopTipView.alpha = 0.9;
        [topToolbar setHidden:NO];
        [bottomView setHidden:NO];
        [resolutionPopTipView setHidden:NO];
        [self resetControlVisibilityTimer];
    } else {
        [controlVisibilityTimer invalidate];
        [UIView animateWithDuration:0.5 delay:0.0 options:UIViewAnimationCurveEaseOut animations:^{
            UIView *epsideArrayView = (UIView *)[self.view viewWithTag:EPISODE_ARRAY_VIEW_TAG];
            if (epsideArrayView == nil) {
                topToolbar.alpha = 0;
            }
            bottomView.alpha = 0;
            resolutionPopTipView.alpha = 0;
        } completion:^(BOOL finished) {
            UIView *epsideArrayView = (UIView *)[self.view viewWithTag:EPISODE_ARRAY_VIEW_TAG];
            if (epsideArrayView == nil) {
                [topToolbar setHidden:YES];
            }
            [resolutionPopTipView setHidden:YES];
            [bottomView setHidden:YES];
        }];
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    NSLog(@"error url");
    [connection cancel];
    //如果所有的视频地址都无效，则播放网页地址
    [self checkIfShowWebView];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    @synchronized(workingUrl){
        if(workingUrl == nil){
            NSDictionary *headerFields = [(NSHTTPURLResponse *)response allHeaderFields];
            NSString *contentLength = [NSString stringWithFormat:@"%@", [headerFields objectForKey:@"Content-Length"]];
            if (contentLength.intValue > 100) {
                NSLog(@"working = %@", connection.originalRequest.URL);
                workingUrl = connection.originalRequest.URL;
                [self performSelectorOnMainThread:@selector(setURL:) withObject:workingUrl waitUntilDone:NO];
                [connection cancel];
            } else {
                [self checkIfShowWebView];
            }
        }
    }
}

- (void)checkIfShowWebView
{
    [theLock lock];
    errorUrlNum++;
    if (errorUrlNum == videoUrls.count) {
        [myHUD hide:NO];
        MBProgressHUD *HUD = [[MBProgressHUD alloc] initWithView:self.view];
        [self.view addSubview:HUD];
        HUD.mode = MBProgressHUDModeCustomView;
        HUD.opacity = 0.5;
        HUD.labelText = @"即将使用网页播放";
        [HUD show:YES];
        [self performSelector:@selector(closeModalView) withObject:nil afterDelay:2.5];
    }
    [theLock unlock];
    
}

- (void)closeModalView
{
    if (closeAll) {
        [self dismissModalViewControllerAnimated:NO];
    } else {
        [self.navigationController popViewControllerAnimated:NO];
    }
}

- (void)showPlayVideoView
{
    mPlayer = nil;
    mPlaybackView = [[AVPlayerDemoPlaybackView alloc]initWithFrame:CGRectMake(0, 24, self.view.frame.size.height, self.view.frame.size.width - 24)];
    mPlaybackView.backgroundColor = [UIColor redColor];
	[self.view addSubview:mPlaybackView];
}

- (void)showPlayCacheView
{
    playCacheView = [[UIView alloc]initWithFrame:CGRectMake(0, 24, self.view.frame.size.height, self.view.frame.size.width - 24)];
    playCacheView.backgroundColor = [UIColor blackColor];
    if (topToolbar) {
        [self.view insertSubview:playCacheView belowSubview:topToolbar];
    } else {
        [self.view addSubview:playCacheView];
    }
    
    UILabel *nameLabel = [[UILabel alloc]initWithFrame:CGRectMake(0, 0, 400, 40)];
    nameLabel.center = CGPointMake(playCacheView.center.x, playCacheView.center.y * 0.6);
    nameLabel.backgroundColor = [UIColor clearColor];
    nameLabel.font = [UIFont systemFontOfSize:25];
    if (type == 2) {
        nameLabel.text = [NSString stringWithFormat:@"即将播放：%@ 第%@集", self.name, [self.subnameArray objectAtIndex:self.currentNum]];
        vidoeTitle.text = [NSString stringWithFormat:@"%@：第%@集", self.name, [self.subnameArray objectAtIndex:self.currentNum]];
    } else if(type == 3){
        nameLabel.text = [NSString stringWithFormat:@"即将播放：%@ %@", self.name, [self.subnameArray objectAtIndex:self.currentNum]];
        vidoeTitle.text = [NSString stringWithFormat:@"%@：%@", self.name, [self.subnameArray objectAtIndex:self.currentNum]];
    } else {
        nameLabel.text = [NSString stringWithFormat:@"即将播放：%@",self.name];
        vidoeTitle.text = self.name;
    }
    nameLabel.textAlignment = NSTextAlignmentCenter;
    nameLabel.textColor = [UIColor whiteColor];
    [playCacheView addSubview:nameLabel];
    
    UILabel *tipLabel = [[UILabel alloc]initWithFrame:CGRectMake(0, 0, 200, 40)];
    tipLabel.center = CGPointMake(playCacheView.center.x, playCacheView.center.y * 1.5);
    tipLabel.backgroundColor = [UIColor clearColor];
    tipLabel.font = [UIFont systemFontOfSize:15];
    tipLabel.text = @"正在加载，请稍等";
    tipLabel.textAlignment = NSTextAlignmentCenter;
    tipLabel.textColor = [UIColor whiteColor];
    [playCacheView addSubview:tipLabel];
    
    myHUD = [[MBProgressHUD alloc] initWithView:playCacheView];
    myHUD.frame = CGRectMake(myHUD.frame.origin.x, myHUD.frame.origin.y + 150, myHUD.frame.size.width, myHUD.frame.size.height);
    [playCacheView addSubview:myHUD];
    myHUD.opacity = 0;
    [myHUD show:YES];
}


- (void)customizeTopToolbar
{
    topToolbar = [[UIToolbar alloc]initWithFrame:CGRectMake(0, 24, self.view.frame.size.height, TOP_TOOLBAR_HEIGHT)];
    [topToolbar setBackgroundImage:[UIUtility createImageWithColor:[UIColor colorWithRed:30/255.0 green:30/255.0 blue:30/255.0 alpha:0.5] ] forToolbarPosition:UIToolbarPositionAny barMetrics:UIBarMetricsDefault];
    [self.view addSubview:topToolbar];
    
    UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    closeButton.frame = CGRectMake(20, 0, 67, BUTTON_HEIGHT);
    [closeButton setBackgroundImage:[UIImage imageNamed:@"back_bt"] forState:UIControlStateNormal];
    [closeButton setBackgroundImage:[UIImage imageNamed:@"back_bt_pressed"] forState:UIControlStateHighlighted];
    [closeButton addTarget:self action:@selector(closeSelf) forControlEvents:UIControlEventTouchUpInside];
    [topToolbar addSubview:closeButton];
    
    vidoeTitle = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 400, TOP_TOOLBAR_HEIGHT)];
    vidoeTitle.center = CGPointMake(topToolbar.center.x, TOP_TOOLBAR_HEIGHT/2);
    if (type == 2) {
        vidoeTitle.text = [NSString stringWithFormat:@"%@：第%@集", self.name, [self.subnameArray objectAtIndex:self.currentNum]];
    } else if(type == 3){
        vidoeTitle.text = [NSString stringWithFormat:@"%@：%@", self.name, [self.subnameArray objectAtIndex:self.currentNum]];      
    } else {
        vidoeTitle.text = self.name;
    }
    vidoeTitle.font = [UIFont boldSystemFontOfSize:18];
    vidoeTitle.textColor = [UIColor lightGrayColor];
    vidoeTitle.backgroundColor = [UIColor clearColor];
    vidoeTitle.textAlignment = UITextAlignmentCenter;
    [topToolbar addSubview:vidoeTitle];

    
    if (type == 2 || type == 3) {
        selectButton = [UIButton buttonWithType:UIButtonTypeCustom];
        selectButton.frame = CGRectMake(topToolbar.frame.size.width - 20 - 100, 0, 100, BUTTON_HEIGHT);
        [selectButton setBackgroundImage:[UIImage imageNamed:@"select_bt"] forState:UIControlStateNormal];
        [selectButton setBackgroundImage:[UIImage imageNamed:@"select_bt_pressed"] forState:UIControlStateHighlighted];
        [selectButton addTarget:self action:@selector(showEpisodeListView) forControlEvents:UIControlEventTouchUpInside];
        [topToolbar addSubview:selectButton];
    }
}

- (void)customizeBottomToolbar
{
    bottomView = [[UIView alloc]initWithFrame:CGRectMake(0, self.view.frame.size.width - BOTTOM_TOOL_VIEW_HEIGHT, self.view.frame.size.height, BOTTOM_TOOL_VIEW_HEIGHT)];
    [bottomView setHidden:YES];
    bottomView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.5];
    [self.view addSubview:bottomView];
    
    currentPlaybackTimeLabel = [[UILabel alloc]initWithFrame:CGRectMake(20, 10, 80, 30)];
    [currentPlaybackTimeLabel setBackgroundColor:[UIColor clearColor]];
    [currentPlaybackTimeLabel setFont:[UIFont boldSystemFontOfSize:15]];
    currentPlaybackTimeLabel.textColor = [UIColor whiteColor];
    currentPlaybackTimeLabel.text = @"00:00:00";
    [bottomView addSubview:currentPlaybackTimeLabel];
    
    totalTimeLabel = [[UILabel alloc]initWithFrame:CGRectMake(bottomView.frame.size.width - 80 - 20, 10, 80, 30)];
    [totalTimeLabel setTextAlignment:NSTextAlignmentRight];
    [totalTimeLabel setBackgroundColor:[UIColor clearColor]];
    [totalTimeLabel setFont:[UIFont boldSystemFontOfSize:15]];
    totalTimeLabel.textColor = [UIColor whiteColor];
    totalTimeLabel.text = @"";
    [bottomView addSubview:totalTimeLabel];
    
    mScrubber = [[UISlider alloc]initWithFrame:CGRectMake(0, 0, bottomView.frame.size.width - currentPlaybackTimeLabel.frame.size.width * 2 - 60 , 10)];
    mScrubber.center = CGPointMake(bottomView.center.x, (BOTTOM_TOOL_VIEW_HEIGHT - BOTTOM_TOOLBAR_HEIGHT)/2);
    [mScrubber setThumbImage: [UIImage imageNamed:@"progress_thumb"] forState:UIControlStateNormal];
    [mScrubber addTarget:self action:@selector(endScrubbing:) forControlEvents:UIControlEventTouchCancel];
    [mScrubber addTarget:self action:@selector(endScrubbing:) forControlEvents:UIControlEventTouchUpInside];
    [mScrubber addTarget:self action:@selector(endScrubbing:) forControlEvents:UIControlEventTouchUpOutside];
    [mScrubber addTarget:self action:@selector(beginScrubbing:) forControlEvents:UIControlEventTouchDown];
    [mScrubber addTarget:self action:@selector(scrub:) forControlEvents:UIControlEventTouchDragInside];
    [mScrubber addTarget:self action:@selector(scrub:) forControlEvents:UIControlEventValueChanged];
    [bottomView addSubview:mScrubber];
    
    mToolbar = [[UIToolbar alloc]initWithFrame:CGRectMake(0.0f, BOTTOM_TOOL_VIEW_HEIGHT - BOTTOM_TOOLBAR_HEIGHT, bottomView.frame.size.width, BOTTOM_TOOLBAR_HEIGHT)];
    [mToolbar setBackgroundImage:[UIUtility createImageWithColor:[UIColor colorWithRed:10/255.0 green:10/255.0 blue:10/255.0 alpha:0.8] ] forToolbarPosition:UIToolbarPositionAny barMetrics:UIBarMetricsDefault];
    [bottomView addSubview:mToolbar];
    
    mSwitchButton = [UIButton buttonWithType:UIButtonTypeCustom];
    mSwitchButton.frame = CGRectMake(20, 25, 29, BUTTON_HEIGHT);
    [mSwitchButton setBackgroundImage:[UIImage imageNamed:@"full_bt"] forState:UIControlStateNormal];
    [mSwitchButton setBackgroundImage:[UIImage imageNamed:@"full_bt_pressed"] forState:UIControlStateHighlighted];
    [mSwitchButton addTarget:self action:@selector(nextBtnClicked) forControlEvents:UIControlEventTouchUpInside];
    [mToolbar addSubview:mSwitchButton];
    
    routeBtn = [[MPVolumeView alloc] initWithFrame:CGRectMake(mSwitchButton.frame.origin.x + mSwitchButton.frame.size.width + 20, 25, BUTTON_HEIGHT, BUTTON_HEIGHT)];
    [routeBtn setBackgroundColor:[UIColor clearColor]];
    [routeBtn setShowsVolumeSlider:NO];
    [routeBtn setShowsRouteButton:YES];
    [routeBtn setRouteButtonImage:[UIImage imageNamed:@"route_bt"] forState:UIControlStateNormal];
    [routeBtn setRouteButtonImage:[UIImage imageNamed:@"route_bt_pressed"] forState:UIControlStateHighlighted];
    [mToolbar addSubview:routeBtn];

    mPlayButton = [UIButton buttonWithType:UIButtonTypeCustom];
    mPlayButton.frame = CGRectMake(0, 0, 45, BUTTON_HEIGHT);
    [mPlayButton setHidden:YES];
    [mPlayButton setEnabled:NO];
    mPlayButton.center = CGPointMake(bottomView.frame.size.width/2, BOTTOM_TOOLBAR_HEIGHT/2);
    [mPlayButton setBackgroundImage:[UIImage imageNamed:@"play_bt"] forState:UIControlStateNormal];
    [mPlayButton setBackgroundImage:[UIImage imageNamed:@"play_bt_pressed"] forState:UIControlStateHighlighted];
    [mPlayButton addTarget:self action:@selector(playBtnClicked:) forControlEvents:UIControlEventTouchUpInside];
    [mToolbar addSubview:mPlayButton];
    
    mStopButton = [UIButton buttonWithType:UIButtonTypeCustom];
    mStopButton.frame = mPlayButton.frame;
    [mStopButton setEnabled:NO];
    [mStopButton setBackgroundImage:[UIImage imageNamed:@"pause_bt"] forState:UIControlStateNormal];
    [mStopButton setBackgroundImage:[UIImage imageNamed:@"pause_bt_pressed"] forState:UIControlStateHighlighted];
    [mStopButton addTarget:self action:@selector(stopBtnClicked:) forControlEvents:UIControlEventTouchUpInside];
    [mToolbar addSubview:mStopButton];
    
    mPrevButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [mPrevButton setEnabled:NO];
    mPrevButton.frame = CGRectMake(mPlayButton.frame.origin.x - mPlayButton.frame.size.width - 30, mPlayButton.frame.origin.y, mPlayButton.frame.size.width, mPlayButton.frame.size.width);
    [mPrevButton setBackgroundImage:[UIImage imageNamed:@"prev_bt"] forState:UIControlStateNormal];
    [mPrevButton setBackgroundImage:[UIImage imageNamed:@"prev_bt_pressed"] forState:UIControlStateHighlighted];
    [mPrevButton setBackgroundImage:[UIImage imageNamed:@"prev_bt_disabled"] forState:UIControlStateDisabled];
    [mPrevButton addTarget:self action:@selector(prevBtnClicked) forControlEvents:UIControlEventTouchUpInside];
    [mToolbar addSubview:mPrevButton];
    
    mNextButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [mNextButton setEnabled:NO];
    mNextButton.frame = CGRectMake(mPlayButton.frame.origin.x + mPlayButton.frame.size.width + 30, mPlayButton.frame.origin.y, mPlayButton.frame.size.width, mPlayButton.frame.size.width);
    [mNextButton setBackgroundImage:[UIImage imageNamed:@"next_bt"] forState:UIControlStateNormal];
    [mNextButton setBackgroundImage:[UIImage imageNamed:@"next_bt_pressed"] forState:UIControlStateHighlighted];
    [mNextButton setBackgroundImage:[UIImage imageNamed:@"next_bt_disabled"] forState:UIControlStateHighlighted];
    [mNextButton addTarget:self action:@selector(nextBtnClicked) forControlEvents:UIControlEventTouchUpInside];
    [mToolbar addSubview:mNextButton];
    
    volumeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    volumeBtn.frame = CGRectMake(mNextButton.frame.origin.x + mNextButton.frame.size.width + 40, mPlayButton.frame.origin.y, 27, BUTTON_HEIGHT);
    [volumeBtn setBackgroundImage:[UIImage imageNamed:@"volume_bt"] forState:UIControlStateNormal];
    [volumeBtn setBackgroundImage:[UIImage imageNamed:@"volume_bt_pressed"] forState:UIControlStateHighlighted];
    [volumeBtn addTarget:self action:@selector(volumeBtnClicked:) forControlEvents:UIControlEventTouchUpInside];
    [mToolbar addSubview:volumeBtn];
    
    volumeSlider = [[MPVolumeView alloc] initWithFrame:CGRectMake(mNextButton.frame.origin.x + mNextButton.frame.size.width + 75, 40, bottomView.frame.size.width - mNextButton.frame.origin.x - mNextButton.frame.size.width - 200, 20)];
    [volumeSlider setBackgroundColor:[UIColor clearColor]];
    [volumeSlider setShowsVolumeSlider:YES];
    [volumeSlider setShowsRouteButton:NO];
    [mToolbar addSubview:volumeSlider];
    
//    volumeSlider = [[UISlider alloc]initWithFrame:CGRectMake(mNextButton.frame.origin.x + mNextButton.frame.size.width + 75, 40, bottomView.frame.size.width - mNextButton.frame.origin.x - mNextButton.frame.size.width - 200, 20)];
//    [volumeSlider addTarget:self action:@selector(volumeSliderValueChanged) forControlEvents:UIControlEventValueChanged];
//    [bottomView addSubview:volumeSlider];
    
    [self initScrubberTimer];
	[self syncPlayPauseButtons];
	[self syncScrubber];
    
    qualityBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    qualityBtn.frame = CGRectMake(mToolbar.frame.size.width - 100 - 20, mPlayButton.frame.origin.y, 100, BUTTON_HEIGHT);
    [qualityBtn setBackgroundImage:[UIImage imageNamed:@"quality_bt"] forState:UIControlStateNormal];
    [qualityBtn setBackgroundImage:[UIImage imageNamed:@"quality_bt_pressed"] forState:UIControlStateHighlighted];
    [qualityBtn addTarget:self action:@selector(qualityBtnClicked:) forControlEvents:UIControlEventTouchUpInside];
    [mToolbar addSubview:qualityBtn];
}

- (void)nextBtnClicked
{
    currentNum++;
    [self preparePlayVideo];
}

- (void)prevBtnClicked
{
    currentNum--;
    [self preparePlayVideo];
}

- (void)preparePlayVideo
{
    if (currentNum >=0 && currentNum < videoUrls.count) {
        workingUrl = nil;
        [mPlayer pause];
        if (type == 2) {
            vidoeTitle.text = [NSString stringWithFormat:@"%@：第%@集", self.name, [self.subnameArray objectAtIndex:self.currentNum]];
        } else if(type == 3){
            vidoeTitle.text = [NSString stringWithFormat:@"%@：%@", self.name, [self.subnameArray objectAtIndex:self.currentNum]];
        } else {
            vidoeTitle.text = self.name;
        }
        [self playVideo];
    }
}

#pragma mark Asset URL

- (void)setURL:(NSURL*)URL
{
	if (mURL != URL)
	{
		mURL = URL;
		
        /*
         Create an asset for inspection of a resource referenced by a given URL.
         Load the values for the asset keys "tracks", "playable".
         */
        AVURLAsset *asset = [AVURLAsset URLAssetWithURL:mURL options:nil];
        
        NSArray *requestedKeys = [NSArray arrayWithObjects:kTracksKey, kPlayableKey, nil];
        
        /* Tells the asset to load the values of any of the specified keys that are not already loaded. */
        [asset loadValuesAsynchronouslyForKeys:requestedKeys completionHandler:
         ^{		 
             dispatch_async( dispatch_get_main_queue(), 
                            ^{
                                /* IMPORTANT: Must dispatch to main queue in order to operate on the AVPlayer and AVPlayerItem. */
                                [self prepareToPlayAsset:asset withKeys:requestedKeys];
                            });
         }];
	}
}

- (NSURL*)URL
{
	return mURL;
}

#pragma mark -
#pragma mark Movie controller methods

#pragma mark
#pragma mark Button Action Methods

- (void)playBtnClicked:(id)sender
{
	/* If we are at the end of the movie, we must seek to the beginning first 
		before starting playback. */
	if (YES == seekToZeroBeforePlay) {
		seekToZeroBeforePlay = NO;
		[mPlayer seekToTime:kCMTimeZero];
	}

	[mPlayer play];
    [self showStopButton];
    [self resetControlVisibilityTimer];
}

- (void)stopBtnClicked:(id)sender
{
	[mPlayer pause];
    [self showPlayButton];
    [self resetControlVisibilityTimer];
}

#pragma mark -
#pragma mark Play, Stop buttons

/* Show the stop button in the movie player controller. */
-(void)showStopButton
{
    [mPlayButton setHidden:YES];
    [mStopButton setHidden:NO];
}

/* Show the play button in the movie player controller. */
-(void)showPlayButton
{
    [mPlayButton setHidden:NO];
    [mStopButton setHidden:YES];
}

/* If the media is playing, show the stop button; otherwise, show the play button. */
- (void)syncPlayPauseButtons
{
	if ([self isPlaying])
	{
        [self showStopButton];
	}
	else
	{
        [self showPlayButton];        
	}
}

-(void)enablePlayerButtons
{
    self.mPlayButton.enabled = YES;
    self.mStopButton.enabled = YES;
    if (subnameArray.count > 0){
        if (currentNum == 0) {
            [mPrevButton setEnabled:NO];
            [mNextButton setEnabled:YES];
        } else if(currentNum == subnameArray.count - 1) {
            [mPrevButton setEnabled:YES];
            [mNextButton setEnabled:NO];
        } else if(currentNum > 0 && currentNum < subnameArray.count){
            [mPrevButton setEnabled:YES];
            [mNextButton setEnabled:YES];
        }
    } else {
        [mPrevButton setEnabled:NO];
        [mNextButton setEnabled:NO];
    }
}

-(void)disablePlayerButtons
{
    self.mPlayButton.enabled = NO;
    self.mStopButton.enabled = NO;
    [mPrevButton setEnabled:NO];
    [mNextButton setEnabled:NO];
}

#pragma mark -
#pragma mark Movie scrubber control

/* ---------------------------------------------------------
**  Methods to handle manipulation of the movie scrubber control
** ------------------------------------------------------- */

/* Requests invocation of a given block during media playback to update the movie scrubber control. */
-(void)initScrubberTimer
{
	double interval = .1f;	
	
	CMTime playerDuration = [self playerItemDuration];
	if (CMTIME_IS_INVALID(playerDuration)) 
	{
		return;
	} 
	double duration = CMTimeGetSeconds(playerDuration);
	if (isfinite(duration))
	{
		CGFloat width = CGRectGetWidth([mScrubber bounds]);
		interval = 0.5f * duration / width;
	}

	/* Update the scrubber during normal playback. */
	mTimeObserver = [mPlayer addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(interval, NSEC_PER_SEC)
								queue:NULL /* If you pass NULL, the main queue is used. */
								usingBlock:^(CMTime time) 
                                            {
                                                [self syncScrubber];
                                            }];

}

/* Set the scrubber based on the player current time. */
- (void)syncScrubber
{
	CMTime playerDuration = [self playerItemDuration];
	if (CMTIME_IS_INVALID(playerDuration))
	{
		mScrubber.minimumValue = 0.0;
		return;
	} 

	double duration = CMTimeGetSeconds(playerDuration);
	if (isfinite(duration))
	{
		float minValue = [mScrubber minimumValue];
		float maxValue = [mScrubber maximumValue];
		double time = CMTimeGetSeconds([mPlayer currentTime]);
		
		[mScrubber setValue:(maxValue - minValue) * time / duration + minValue];
	}
    currentPlaybackTimeLabel.text = [TimeUtility formatTimeInSecond:CMTimeGetSeconds(mPlayerItem.currentTime)];
}

/* The user is dragging the movie controller thumb to scrub through the movie. */
- (void)beginScrubbing:(id)sender
{
	mRestoreAfterScrubbingRate = [mPlayer rate];
	[mPlayer setRate:0.f];
	
	/* Remove previous timer. */
	[self removePlayerTimeObserver];
}

/* Set the player current time to match the scrubber position. */
- (void)scrub:(id)sender
{
	if ([sender isKindOfClass:[UISlider class]])
	{
		UISlider* slider = sender;
		
		CMTime playerDuration = [self playerItemDuration];
		if (CMTIME_IS_INVALID(playerDuration)) {
			return;
		} 
		
		double duration = CMTimeGetSeconds(playerDuration);
		if (isfinite(duration))
		{
			float minValue = [slider minimumValue];
			float maxValue = [slider maximumValue];
			float value = [slider value];
			
			double time = duration * (value - minValue) / (maxValue - minValue);
			
			[mPlayer seekToTime:CMTimeMakeWithSeconds(time, NSEC_PER_SEC)];
		}
	}
}

/* The user has released the movie thumb control to stop scrubbing through the movie. */
- (void)endScrubbing:(id)sender
{
	if (!mTimeObserver)
	{
		CMTime playerDuration = [self playerItemDuration];
		if (CMTIME_IS_INVALID(playerDuration)) 
		{
			return;
		} 
		
		double duration = CMTimeGetSeconds(playerDuration);
		if (isfinite(duration))
		{
			CGFloat width = CGRectGetWidth([mScrubber bounds]);
			double tolerance = 0.5f * duration / width;

			mTimeObserver = [mPlayer addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(tolerance, NSEC_PER_SEC) queue:NULL usingBlock:
			^(CMTime time)
			{
				[self syncScrubber];
			}];
		}
	}

	if (mRestoreAfterScrubbingRate)
	{
		[mPlayer setRate:mRestoreAfterScrubbingRate];
		mRestoreAfterScrubbingRate = 0.f;
	}
}

- (BOOL)isScrubbing
{
	return mRestoreAfterScrubbingRate != 0.f;
}

-(void)enableScrubber
{
    self.mScrubber.enabled = YES;
}

-(void)disableScrubber
{
    self.mScrubber.enabled = NO;    
}

- (void)playOneEpisode:(int)num
{
    currentNum = num;
    [self preparePlayVideo];
}
@end

@implementation AVPlayerDemoPlaybackViewController (Player)

#pragma mark Player Item

- (BOOL)isPlaying
{
	return mRestoreAfterScrubbingRate != 0.f || [mPlayer rate] != 0.f;
}

/* Called when the player item has played to its end time. */
- (void)playerItemDidReachEnd:(NSNotification *)notification 
{
	/* After the movie has played to its end time, seek back to time zero 
		to play it again. */
	seekToZeroBeforePlay = YES;
}

/* ---------------------------------------------------------
 **  Get the duration for a AVPlayerItem. 
 ** ------------------------------------------------------- */

- (CMTime)playerItemDuration
{
	AVPlayerItem *playerItem = [mPlayer currentItem];
	if (playerItem.status == AVPlayerItemStatusReadyToPlay)
	{
        /* 
         NOTE:
         Because of the dynamic nature of HTTP Live Streaming Media, the best practice 
         for obtaining the duration of an AVPlayerItem object has changed in iOS 4.3. 
         Prior to iOS 4.3, you would obtain the duration of a player item by fetching 
         the value of the duration property of its associated AVAsset object. However, 
         note that for HTTP Live Streaming Media the duration of a player item during 
         any particular playback session may differ from the duration of its asset. For 
         this reason a new key-value observable duration property has been defined on 
         AVPlayerItem.
         
         See the AV Foundation Release Notes for iOS 4.3 for more information.
         */		

		return([playerItem duration]);
	}
	
	return(kCMTimeInvalid);
}


/* Cancels the previously registered time observer. */
-(void)removePlayerTimeObserver
{
	if (mTimeObserver)
	{
		[mPlayer removeTimeObserver:mTimeObserver];
		mTimeObserver = nil;
	}
}

#pragma mark -
#pragma mark Loading the Asset Keys Asynchronously

#pragma mark -
#pragma mark Error Handling - Preparing Assets for Playback Failed

/* --------------------------------------------------------------
 **  Called when an asset fails to prepare for playback for any of
 **  the following reasons:
 ** 
 **  1) values of asset keys did not load successfully, 
 **  2) the asset keys did load successfully, but the asset is not 
 **     playable
 **  3) the item did not become ready to play. 
 ** ----------------------------------------------------------- */

-(void)assetFailedToPrepareForPlayback:(NSError *)error
{
    [self removePlayerTimeObserver];
    [self syncScrubber];
    [self disableScrubber];
    [self disablePlayerButtons];
    
    /* Display the error. */
	UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:[error localizedDescription]
														message:[error localizedFailureReason]
													   delegate:nil
											  cancelButtonTitle:@"OK"
											  otherButtonTitles:nil];
	[alertView show];
}


#pragma mark Prepare to play asset, URL

/*
 Invoked at the completion of the loading of the values for all keys on the asset that we require.
 Checks whether loading was successfull and whether the asset is playable.
 If so, sets up an AVPlayerItem and an AVPlayer to play the asset.
 */
- (void)prepareToPlayAsset:(AVURLAsset *)asset withKeys:(NSArray *)requestedKeys
{
    /* Make sure that the value of each key has loaded successfully. */
	for (NSString *thisKey in requestedKeys)
	{
		NSError *error = nil;
		AVKeyValueStatus keyStatus = [asset statusOfValueForKey:thisKey error:&error];
		if (keyStatus == AVKeyValueStatusFailed)
		{
			[self assetFailedToPrepareForPlayback:error];
			return;
		}
		/* If you are also implementing -[AVAsset cancelLoading], add your code here to bail out properly in the case of cancellation. */
	}
    
    /* Use the AVAsset playable property to detect whether the asset can be played. */
    if (!asset.playable) 
    {
        /* Generate an error describing the failure. */
		NSString *localizedDescription = NSLocalizedString(@"Item cannot be played", @"Item cannot be played description");
		NSString *localizedFailureReason = NSLocalizedString(@"The assets tracks were loaded, but could not be made playable.", @"Item cannot be played failure reason");
		NSDictionary *errorDict = [NSDictionary dictionaryWithObjectsAndKeys:
								   localizedDescription, NSLocalizedDescriptionKey, 
								   localizedFailureReason, NSLocalizedFailureReasonErrorKey, 
								   nil];
		NSError *assetCannotBePlayedError = [NSError errorWithDomain:@"StitchedStreamPlayer" code:0 userInfo:errorDict];
        
        /* Display the error to the user. */
        [self assetFailedToPrepareForPlayback:assetCannotBePlayedError];
        
        return;
    }
	
	/* At this point we're ready to set up for playback of the asset. */
    	
    /* Stop observing our prior AVPlayerItem, if we have one. */
    if (self.mPlayerItem)
    {
        /* Remove existing player item key value observers and notifications. */
        
        [self.mPlayerItem removeObserver:self forKeyPath:kStatusKey];            
		
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:AVPlayerItemDidPlayToEndTimeNotification
                                                      object:self.mPlayerItem];
    }
	
    /* Create a new instance of AVPlayerItem from the now successfully loaded AVAsset. */
    self.mPlayerItem = [AVPlayerItem playerItemWithAsset:asset];
    
    /* Observe the player item "status" key to determine when it is ready to play. */
    [self.mPlayerItem addObserver:self 
                      forKeyPath:kStatusKey 
                         options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                         context:AVPlayerDemoPlaybackViewControllerStatusObservationContext];
	
    /* When the player item has played to its end time we'll toggle
     the movie controller Pause button to be the Play button */
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playerItemDidReachEnd:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:self.mPlayerItem];
	
    seekToZeroBeforePlay = NO;
	
    /* Create new player, if we don't already have one. */
    if (![self player])
    {
        [self setPlayer:[AVPlayer playerWithPlayerItem:self.mPlayerItem]];
		
        /* Observe the AVPlayer "currentItem" property to find out when any 
         AVPlayer replaceCurrentItemWithPlayerItem: replacement will/did 
         occur.*/
        [self.player addObserver:self 
                      forKeyPath:kCurrentItemKey 
                         options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                         context:AVPlayerDemoPlaybackViewControllerCurrentItemObservationContext];
        
        /* Observe the AVPlayer "rate" property to update the scrubber control. */
        [self.player addObserver:self 
                      forKeyPath:kRateKey 
                         options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                         context:AVPlayerDemoPlaybackViewControllerRateObservationContext];
    }
    
    /* Make our new AVPlayerItem the AVPlayer's current item. */
    if (self.player.currentItem != self.mPlayerItem)
    {
        /* Replace the player item with a new player item. The item replacement occurs 
         asynchronously; observe the currentItem property to find out when the 
         replacement will/did occur*/
        [[self player] replaceCurrentItemWithPlayerItem:self.mPlayerItem];
        
        [self syncPlayPauseButtons];
    }
	
    [mScrubber setValue:0.0];
}

#pragma mark -
#pragma mark Asset Key Value Observing
#pragma mark

#pragma mark Key Value Observer for player rate, currentItem, player item status

/* ---------------------------------------------------------
**  Called when the value at the specified key path relative
**  to the given object has changed. 
**  Adjust the movie play and pause button controls when the 
**  player item "status" value changes. Update the movie 
**  scrubber control when the player item is ready to play.
**  Adjust the movie scrubber control when the player item 
**  "rate" value changes. For updates of the player
**  "currentItem" property, set the AVPlayer for which the 
**  player layer displays visual output.
**  NOTE: this method is invoked on the main queue.
** ------------------------------------------------------- */

- (void)observeValueForKeyPath:(NSString*) path 
			ofObject:(id)object 
			change:(NSDictionary*)change 
			context:(void*)context
{
	/* AVPlayerItem "status" property value observer. */
	if (context == AVPlayerDemoPlaybackViewControllerStatusObservationContext)
	{
		[self syncPlayPauseButtons];

        AVPlayerStatus status = [[change objectForKey:NSKeyValueChangeNewKey] integerValue];
        switch (status)
        {
            /* Indicates that the status of the player is not yet known because 
             it has not tried to load new media resources for playback */
            case AVPlayerStatusUnknown:
            {
                [self removePlayerTimeObserver];
                [self syncScrubber];
                
                [self disableScrubber];
                [self disablePlayerButtons];
            }
            break;
                
            case AVPlayerStatusReadyToPlay:
            {
                /* Once the AVPlayerItem becomes ready to play, i.e. 
                 [playerItem status] == AVPlayerItemStatusReadyToPlay,
                 its duration can be fetched from the item. */
                CMTime playerDuration = [self playerItemDuration];
                double duration = 0;
                if (CMTIME_IS_VALID(playerDuration)) {
                    duration = CMTimeGetSeconds(playerDuration);
                }
                totalTimeLabel.text = [TimeUtility formatTimeInSecond:duration];
                currentPlaybackTimeLabel.text = [TimeUtility formatTimeInSecond:CMTimeGetSeconds(mPlayerItem.currentTime)];
                
                [self initScrubberTimer];
                
                [self enableScrubber];
                [self enablePlayerButtons];
                [bottomView setHidden:NO];
                [UIView animateWithDuration:0.5 delay:0.0 options:UIViewAnimationCurveEaseOut animations:^{
                    for (UIView *subview in playCacheView.subviews) {
                        [subview setAlpha:0];
                    }
                    [playCacheView setAlpha:0];
                } completion:^(BOOL finished) {
                    [playCacheView removeFromSuperview];
                    [self showToolview];
                    [self resetControlVisibilityTimer];
                    [videoWebViewControllerDelegate playNextEpisode:currentNum];
                    [mPlayButton sendActionsForControlEvents:UIControlEventTouchUpInside];
                }];
            }
            break;
                
            case AVPlayerStatusFailed:
            {
                AVPlayerItem *playerItem = (AVPlayerItem *)object;
                [self assetFailedToPrepareForPlayback:playerItem.error];
            }
            break;
        }
	}
	/* AVPlayer "rate" property value observer. */
	else if (context == AVPlayerDemoPlaybackViewControllerRateObservationContext)
	{
        [self syncPlayPauseButtons];
	}
	/* AVPlayer "currentItem" property observer. 
        Called when the AVPlayer replaceCurrentItemWithPlayerItem: 
        replacement will/did occur. */
	else if (context == AVPlayerDemoPlaybackViewControllerCurrentItemObservationContext)
	{
        AVPlayerItem *newPlayerItem = [change objectForKey:NSKeyValueChangeNewKey];
        
        /* Is the new player item null? */
        if (newPlayerItem == (id)[NSNull null])
        {
            [self disablePlayerButtons];
            [self disableScrubber];
        }
        else /* Replacement of player currentItem has occurred */
        {
            /* Set the AVPlayer for which the player layer displays visual output. */
            [mPlaybackView setPlayer:mPlayer];
            
            /* Specifies that the player should preserve the video’s aspect ratio and
             fit the video within the layer’s bounds. */
            [mPlaybackView setVideoFillMode:AVLayerVideoGravityResize];
            
            [self syncPlayPauseButtons];
        }
	}
	else
	{
		[super observeValueForKeyPath:path ofObject:object change:change context:context];
	}
}

- (void)closeSelf
{
    [self dismissModalViewControllerAnimated:YES];
}

- (void)showEpisodeListView
{
    [self resetControlVisibilityTimer];
    UIView *epsideArrayView = (UIView *)[self.view viewWithTag:EPISODE_ARRAY_VIEW_TAG];
    if (epsideArrayView) {
        [selectButton setBackgroundImage:[UIImage imageNamed:@"select_bt"] forState:UIControlStateNormal];
        [UIView animateWithDuration:0.3 delay:0.0 options:UIViewAnimationCurveEaseOut animations:^{
            episodeListviewController.table.frame = CGRectMake(0, 0, EPISODE_TABLE_WIDTH, 0);
            episodeListviewController.view.frame = CGRectMake(topToolbar.frame.size.width - 20 - EPISODE_TABLE_WIDTH, TOP_TOOLBAR_HEIGHT + 24, EPISODE_TABLE_WIDTH, 0);
        } completion:^(BOOL finished) {
            [epsideArrayView removeFromSuperview];
        }];
    } else {
        [selectButton setBackgroundImage:[UIImage imageNamed:@"select_bt_pressed"] forState:UIControlStateNormal];
        episodeListviewController.currentNum = currentNum;
        episodeListviewController.episodeArray = subnameArray;
        [self.view addSubview:episodeListviewController.view];
        [episodeListviewController.table reloadData];
        [UIView animateWithDuration:0.3 delay:0.0 options:UIViewAnimationCurveEaseInOut animations:^{
            episodeListviewController.table.frame = CGRectMake(0, 0, EPISODE_TABLE_WIDTH, fmin(10, subnameArray.count) * EPISODE_TABLE_CELL_HEIGHT);
            episodeListviewController.view.frame = CGRectMake(topToolbar.frame.size.width - 20 - EPISODE_TABLE_WIDTH, TOP_TOOLBAR_HEIGHT + 24, EPISODE_TABLE_WIDTH, fmin(10, subnameArray.count) * EPISODE_TABLE_CELL_HEIGHT);
        } completion:^(BOOL finished) {
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:currentNum inSection:0];
            [episodeListviewController.table scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
        }];
    }
}

- (void)qualityBtnClicked:(UIButton *)btn
{
    [self resetControlVisibilityTimer];
    if (resolutionPopTipView) {
        [qualityBtn setBackgroundImage:[UIImage imageNamed:@"quality_bt"] forState:UIControlStateNormal];
        [resolutionPopTipView dismissAnimated:YES];
        resolutionPopTipView = nil;
    } else {
        [qualityBtn setBackgroundImage:[UIImage imageNamed:@"quality_bt_pressed"] forState:UIControlStateNormal];
        UIView *contentView = [[UIView alloc]initWithFrame:CGRectMake(0, 0, 360, 130)];
        contentView.backgroundColor = [UIColor clearColor];
        
        UILabel *tLabel = [[UILabel alloc]initWithFrame:CGRectMake(10, 10, 320, 30)];
        tLabel.backgroundColor = [UIColor clearColor];
        tLabel.font = [UIFont systemFontOfSize:20];
        tLabel.text = @"请选择影片清晰度：";
        tLabel.textAlignment = NSTextAlignmentLeft;
        tLabel.textColor = [UIColor whiteColor];
        [contentView addSubview:tLabel];
        
        biaoqingBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        biaoqingBtn.tag = 111001;
        biaoqingBtn.frame = CGRectMake(40, 50, 40, BUTTON_HEIGHT);
        [biaoqingBtn setBackgroundImage:[UIImage imageNamed:@"biaoqing_bt"] forState:UIControlStateNormal];
        [biaoqingBtn setBackgroundImage:[UIImage imageNamed:@"biaoqing_bt_pressed"] forState:UIControlStateHighlighted];
        [biaoqingBtn addTarget:self action:@selector(resolutionBtnClicked:) forControlEvents:UIControlEventTouchUpInside];
        [contentView addSubview:biaoqingBtn];
        
        UIView *separatorView = [[UIView alloc]initWithFrame:CGRectMake(120, 65, 1, 40)];
        separatorView.backgroundColor = [UIColor colorWithRed:80/255.0 green:80/255.0 blue:80/255.0 alpha:0.5];
        [contentView addSubview:separatorView];
        
        gaoqingBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        gaoqingBtn.frame = CGRectMake(160, 50, 40, BUTTON_HEIGHT);
        gaoqingBtn.tag = 111002;
        [gaoqingBtn setBackgroundImage:[UIImage imageNamed:@"gaoqing_bt_pressed"] forState:UIControlStateNormal];
        [gaoqingBtn setBackgroundImage:[UIImage imageNamed:@"gaoqing_bt_pressed"] forState:UIControlStateHighlighted];
        [gaoqingBtn addTarget:self action:@selector(resolutionBtnClicked:) forControlEvents:UIControlEventTouchUpInside];
        [contentView addSubview:gaoqingBtn];
        
        UIView *separatorView1 = [[UIView alloc]initWithFrame:CGRectMake(240, 65, 1, 40)];
        separatorView1.backgroundColor = [UIColor colorWithRed:80/255.0 green:80/255.0 blue:80/255.0 alpha:0.5];
        [contentView addSubview:separatorView1];
        
        chaoqingBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        chaoqingBtn.frame = CGRectMake(280, 50, 40, BUTTON_HEIGHT);
        chaoqingBtn.tag = 111003;
        [chaoqingBtn setBackgroundImage:[UIImage imageNamed:@"chaoqing_bt"] forState:UIControlStateNormal];
        [chaoqingBtn setBackgroundImage:[UIImage imageNamed:@"chaoqing_bt_pressed"] forState:UIControlStateHighlighted];
        [chaoqingBtn addTarget:self action:@selector(resolutionBtnClicked:) forControlEvents:UIControlEventTouchUpInside];
        [contentView addSubview:chaoqingBtn];
        
        resolutionPopTipView = [[CMPopTipView alloc] initWithCustomView:contentView];
        resolutionPopTipView.backgroundColor = [UIColor colorWithRed:10/255.0 green:10/255.0 blue:10/255.0 alpha:1];
        //    resolutionPopTipView.delegate = self;
        resolutionPopTipView.disableTapToDismiss = YES;
        resolutionPopTipView.animation = CMPopTipAnimationPop;
        [resolutionPopTipView presentPointingAtView:btn inView:self.view animated:YES];
        resolutionPopTipView.frame = CGRectMake(bottomView.frame.size.width - resolutionPopTipView.frame.size.width + 10, resolutionPopTipView.frame.origin.y, resolutionPopTipView.frame.size.width, resolutionPopTipView.frame.size.height);
    }
}

- (void)resolutionBtnClicked:(UIButton *)btn
{
    [self resetControlVisibilityTimer];
    [biaoqingBtn setBackgroundImage:[UIImage imageNamed:@"biaoqing_bt"] forState:UIControlStateNormal];
    [gaoqingBtn setBackgroundImage:[UIImage imageNamed:@"gaoqing_bt"] forState:UIControlStateNormal];
    [chaoqingBtn setBackgroundImage:[UIImage imageNamed:@"chaoqing_bt"] forState:UIControlStateNormal];
    if (btn.tag == 111001) {
        resolution = BIAO_QING;
        [btn setBackgroundImage:[UIImage imageNamed:@"biaoqing_bt_pressed"] forState:UIControlStateNormal];
    } else if (btn.tag == 111002) {
        resolution = GAO_QING;
        [btn setBackgroundImage:[UIImage imageNamed:@"gaoqing_bt_pressed"] forState:UIControlStateNormal];
    } else if (btn.tag == 111003) {
        resolution = CHAO_QING;
        [btn setBackgroundImage:[UIImage imageNamed:@"chaoqing_bt_pressed"] forState:UIControlStateNormal];
    }
}

- (void)volumeBtnClicked:(UIButton *)btn
{
//    AVURLAsset *asset = [[mPlayer currentItem] asset];
//    NSArray *audioTracks = [asset tracksWithMediaType:AVMediaTypeAudio];
//    
//    // Mute all the audio tracks
//    NSMutableArray *allAudioParams = [NSMutableArray array];
//    for (AVAssetTrack *track in audioTracks) {
//        AVMutableAudioMixInputParameters *audioInputParams =    [AVMutableAudioMixInputParameters audioMixInputParameters];
//        [audioInputParams setVolume:0.0 atTime:kCMTimeZero];
//        [audioInputParams setTrackID:[track trackID]];
//        [allAudioParams addObject:audioInputParams];
//    }
//    AVMutableAudioMix *audioZeroMix = [AVMutableAudioMix audioMix];
//    [audioZeroMix setInputParameters:allAudioParams];
//    
//    [[mPlayer currentItem] setAudioMix:audioZeroMix];
    
    float volume = 0.0f;
    
    AVPlayerItem *currentItem = mPlayer.currentItem;
    NSArray *audioTracks = mPlayer.currentItem.tracks;
    
    NSMutableArray *allAudioParams = [NSMutableArray array];
    
    for (AVPlayerItemTrack *track in audioTracks)
    {
        if ([track.assetTrack.mediaType isEqual:AVMediaTypeAudio])
        {
            AVMutableAudioMixInputParameters *audioInputParams = [AVMutableAudioMixInputParameters audioMixInputParameters];
            [audioInputParams setVolume:volume atTime:kCMTimeZero];
            [audioInputParams setTrackID:[track.assetTrack trackID]];
            [allAudioParams addObject:audioInputParams];
        }
    }
    
    if ([allAudioParams count] > 0) {
        AVMutableAudioMix *audioMix = [AVMutableAudioMix audioMix];
        [audioMix setInputParameters:allAudioParams];
        [currentItem setAudioMix:audioMix];
    }
    [mPlayer play];

}
@end

