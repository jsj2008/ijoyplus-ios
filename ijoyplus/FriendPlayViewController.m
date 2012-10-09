//
//  PlayViewController.m
//  ijoyplus
//
//  Created by joyplus1 on 12-9-11.
//  Copyright (c) 2012年 joyplus. All rights reserved.
//

#import "FriendPlayViewController.h"
#import "PlayCell.h"
#import "CommentCell.h"
#import "UIImageView+WebCache.h"
#import "CMConstants.h"
#import "DateUtility.h"
#import "TTTTimeIntervalFormatter.h"
#import "CommentListViewController.h"
#import "ContainerUtility.h"
#import "PostViewController.h"
#import "HomeViewController.h"
#import "LoadMoreCell.h"

#define ANIMATION_DURATION 0.4
#define ANIMATION_DELAY 0

#define ROW_HEIGHT 40
#define PUBLISH_HEIGHT 15

#define MAX_FRIEND_COMMENT_COUNT 5
#define MAX_COMMENT_COUNT 5

@interface FriendPlayViewController (){
    NSMutableArray *commentArray;
    NSMutableArray *friendCommentArray;
    NSInteger totalFriendCommentCount;
    NSInteger totalCommentCount;
    UIViewController *subviewController;//视图
    PlayCell *playCell;
}
- (void)avatarClicked;
- (void)showIntroduction;
- (void)playVideo;
@end

@implementation FriendPlayViewController
@synthesize imageHeight;

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self.view setBackgroundColor:[UIColor colorWithPatternImage:[UIImage imageNamed:@"background"]]];
    self.imageHeight = 160;
    [self initPlayCell];
    
    totalFriendCommentCount = 10;
    totalCommentCount = 10;
}

- (void)initPlayCell
{
    NSArray *nib = [[NSBundle mainBundle] loadNibNamed:@"PopularCellFactory" owner:self options:nil];
    playCell = (PlayCell *)[nib objectAtIndex:3];
    playCell.filmImageView.frame = CGRectMake(0, 0, playCell.filmImageView.frame.size.width, self.imageHeight);
//    [playCell.introuctionBtn setTitle: NSLocalizedString(@"introduction", nil) forState:UIControlStateNormal];
    [playCell.introuctionBtn addTarget:self action:@selector(showIntroduction) forControlEvents:UIControlEventTouchUpInside];
    playCell.scoreLabel.text = @"8.3";
    playCell.watchedLabel.text = @"1024";
    playCell.collectionLabel.text = @"2048";
    playCell.likeLabel.text = @"3072";    
    playCell.playBtn.center = CGPointMake(playCell.playBtn.center.x, self.imageHeight / 2);
    playCell.playImageView.center = CGPointMake(playCell.playImageView.center.x, self.imageHeight / 2);
    [playCell.playBtn setTitle:@"" forState:UIControlStateNormal];
    [playCell.playBtn addTarget:self action:@selector(playVideo) forControlEvents:UIControlEventTouchUpInside];
    
//    NSString *name = @"电影名称电影名称电影名称电影名称电影名称电影名称电影名称电影名称电影名称电影名称电影名称1234567890";
    NSString *name = @"电影";
    CGSize constraint = CGSizeMake(290, 20000.0f);
    CGSize size = [name sizeWithFont:[UIFont systemFontOfSize:15.0f] constrainedToSize:constraint lineBreakMode:UILineBreakModeWordWrap];
    playCell.publicLabel.text = @"发布者名称";
    playCell.filmTitleLabel.text = name;
    [playCell.filmTitleLabel setNumberOfLines:0];
    [playCell.publicLabel sizeToFit];
    if(size.height < 30){
        playCell.publicLabel.textAlignment = UITextAlignmentRight;
        
    } else {
        playCell.publicLabel.textAlignment = UITextAlignmentLeft;
        playCell.frame = CGRectMake(0, 0, self.view.frame.size.width, self.imageHeight + size.height + 3 * ROW_HEIGHT + 20);
        [playCell.filmTitleLabel setFrame:CGRectMake(playCell.filmTitleLabel.frame.origin.x, playCell.filmImageView.frame.origin.y + self.imageHeight + 10, size.width, size.height)];
        playCell.publicLabel.frame = CGRectMake(10, self.imageHeight + size.height + 20, 260, playCell.publicLabel.frame.size.height);
        playCell.introuctionBtn.center = CGPointMake(playCell.introuctionBtn.center.x, playCell.publicLabel.center.y);
        playCell.scoreImageView.frame = CGRectMake(playCell.publicLabel.frame.origin.x, playCell.publicLabel.frame.origin.y + ROW_HEIGHT - 10, playCell.scoreImageView.frame.size.width, playCell.scoreImageView.frame.size.height);
        playCell.scoreLabel.frame = CGRectMake(playCell.publicLabel.frame.origin.x, playCell.publicLabel.frame.origin.y + ROW_HEIGHT - 10, playCell.scoreLabel.frame.size.width, playCell.scoreLabel.frame.size.height);
        
        playCell.watchedImageView.frame = CGRectMake(playCell.watchedImageView.frame.origin.x, playCell.scoreImageView.frame.origin.y + ROW_HEIGHT, playCell.watchedImageView.frame.size.width, playCell.watchedImageView.frame.size.height);
        playCell.watchedLabel.frame = CGRectMake(playCell.watchedLabel.frame.origin.x, playCell.scoreImageView.frame.origin.y + ROW_HEIGHT, playCell.watchedLabel.frame.size.width, playCell.watchedLabel.frame.size.height);
        playCell.likeImageView.frame = CGRectMake(playCell.likeImageView.frame.origin.x, playCell.scoreImageView.frame.origin.y + ROW_HEIGHT, playCell.likeImageView.frame.size.width, playCell.likeImageView.frame.size.height);
        playCell.likeLabel.frame = CGRectMake(playCell.likeLabel.frame.origin.x, playCell.scoreImageView.frame.origin.y + ROW_HEIGHT, playCell.likeLabel.frame.size.width, playCell.likeLabel.frame.size.height);
        playCell.collectionImageView.frame = CGRectMake(playCell.collectionImageView.frame.origin.x, playCell.scoreImageView.frame.origin.y + ROW_HEIGHT, playCell.collectionImageView.frame.size.width, playCell.collectionImageView.frame.size.height);
        playCell.collectionLabel.frame = CGRectMake(playCell.collectionLabel.frame.origin.x, playCell.scoreImageView.frame.origin.y + ROW_HEIGHT, playCell.collectionLabel.frame.size.width, playCell.collectionLabel.frame.size.height);
        
    }
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    subviewController = nil;
    playCell = nil;
    commentArray = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)viewWillAppear:(BOOL)animated
{
    friendCommentArray = [[NSMutableArray alloc]initWithCapacity:10];
    commentArray = [[NSMutableArray alloc]initWithCapacity:10];
    NSArray *keys = [[NSArray alloc]initWithObjects:@"avatarUrl", @"username", @"content", @"date", nil];
    NSArray *values = [[NSArray alloc]initWithObjects:@"http://img5.douban.com/view/photo/thumb/public/p1686249659.jpg", @"Joy+", @"是夏日，葱绿的森林，四散的流光都会染上的透亮绿意。你戴着奇怪的面具，明明看不到眉目，却一眼就觉得是个可爱的人。", [NSDate date], nil];
    NSMutableDictionary *commentDic = [[NSMutableDictionary alloc]initWithObjects:values forKeys:keys];
    
    NSArray *keys1 = [[NSArray alloc]initWithObjects:@"avatarUrl", @"username", @"content", @"date", nil];
    NSArray *values1 = [[NSArray alloc]initWithObjects:@"http://img5.douban.com/view/photo/thumb/public/p1686249659.jpg", @"Joy+", @"是夏日，葱绿的森林，四散的流光都会染上的透亮绿意。你戴着奇怪的面具，明明看不到眉目，却一眼就觉得是个可爱的人。是夏日，葱绿的森林，四散的流光都会染上的透亮绿意。你戴着奇怪的面具，明明看不到眉目，却一眼就觉得是个可爱的人。", [DateUtility addMinutes:[NSDate date] minutes:10], nil];
    NSMutableDictionary *commentDic1 = [[NSMutableDictionary alloc]initWithObjects:values1 forKeys:keys1];
    
    NSArray *keys2 = [[NSArray alloc]initWithObjects:@"avatarUrl", @"username", @"content", @"date", nil];
    NSArray *values2 = [[NSArray alloc]initWithObjects:@"http://img5.douban.com/view/photo/thumb/public/p1686249659.jpg", @"Joy+", @"顶。", [DateUtility dateWithDaysFromGivenDate:10 givenDate:[NSDate date]], nil];
    NSMutableDictionary *commentDic2 = [[NSMutableDictionary alloc]initWithObjects:values2 forKeys:keys2];
    
    [commentArray addObject:commentDic];
    [commentArray addObject:commentDic1];
    [commentArray addObject:commentDic2];
    [commentArray addObject:commentDic];
    [commentArray addObject:commentDic];
    
    [friendCommentArray addObject:commentDic];
    [friendCommentArray addObject:commentDic1];
    [friendCommentArray addObject:commentDic2];
    [friendCommentArray addObject:commentDic];
    [friendCommentArray addObject:commentDic];
}
#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if(section == 0){
        return 1;
    } else if(section == 1) {
        if(totalFriendCommentCount > MAX_FRIEND_COMMENT_COUNT){
            return MAX_FRIEND_COMMENT_COUNT + 1;
        } else {
            return friendCommentArray.count;
        }
    }else {
        if(totalCommentCount > MAX_COMMENT_COUNT){
            return MAX_COMMENT_COUNT + 1;
        } else {
            return commentArray.count;
        }       
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0) {
        return playCell;
    } else if (indexPath.section == 1){
        if(indexPath.row == MAX_FRIEND_COMMENT_COUNT){
            LoadMoreCell *cell = [self displayLoadMoreCell:tableView];
            return cell;
        } else {
            CommentCell *cell = [self displayCommentCell:tableView cellForRowAtIndexPath:indexPath commentArray:friendCommentArray cellIdentifier:@"friendCommentCell"];
            return cell;
        }
    } else {
        if(indexPath.row == MAX_COMMENT_COUNT){
            LoadMoreCell *cell = [self displayLoadMoreCell:tableView];
            return cell;
        } else {
            CommentCell *cell = [self displayCommentCell:tableView cellForRowAtIndexPath:indexPath commentArray:commentArray cellIdentifier:@"commentCell"];
            return cell;
        }
    }
}

- (LoadMoreCell *)displayLoadMoreCell:(UITableView *)tableView
{
    LoadMoreCell *cell = (LoadMoreCell*) [tableView dequeueReusableCellWithIdentifier:@"loadMoreCell"];
    if (cell == nil) {
        NSArray *nib = [[NSBundle mainBundle] loadNibNamed:@"FriendCellFactory" owner:self options:nil];
        cell = (LoadMoreCell *)[nib objectAtIndex:0];
    }
    return cell;
}

- (CommentCell *)displayCommentCell:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath commentArray:(NSArray *)dataArray cellIdentifier:(NSString *)cellIdentifier
{
    CommentCell *cell = (CommentCell*) [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil) {
        NSArray *nib = [[NSBundle mainBundle] loadNibNamed:@"PopularCellFactory" owner:self options:nil];
        cell = (CommentCell *)[nib objectAtIndex:2];
    }
    NSMutableDictionary *commentDic = [dataArray objectAtIndex:indexPath.row];
    [cell.avatarImageView setImageWithURL:[NSURL URLWithString:[commentDic valueForKey:@"avatarUrl"]] placeholderImage:[UIImage imageNamed:@"placeholder.png"]];
    cell.avatarImageView.layer.cornerRadius = 25;
    cell.avatarImageView.layer.masksToBounds = YES;
    cell.titleLabel.text = [commentDic objectForKey:@"username"];
    
    cell.subtitleLabel.text = [commentDic objectForKey:@"content"];
    [cell.subtitleLabel setNumberOfLines:0];
    CGSize constraint = CGSizeMake(cell.titleLabel.frame.size.width, 20000.0f);
    CGSize size = [[commentDic objectForKey:@"content"] sizeWithFont:[UIFont systemFontOfSize:15.0f] constrainedToSize:constraint lineBreakMode:UILineBreakModeWordWrap];
    [cell.subtitleLabel setFrame:CGRectMake(cell.subtitleLabel.frame.origin.x, cell.subtitleLabel.frame.origin.y, size.width, size.height)];
    
    NSInteger yPosition = cell.subtitleLabel.frame.origin.y + size.height + 10;
    cell.thirdTitleLabel.frame = CGRectMake(cell.thirdTitleLabel.frame.origin.x, yPosition, cell.thirdTitleLabel.frame.size.width, cell.thirdTitleLabel.frame.size.height);
    
    TTTTimeIntervalFormatter *timeFormatter = [[TTTTimeIntervalFormatter alloc]init];
    NSString *timeDiff = [timeFormatter stringForTimeIntervalFromDate:[NSDate date] toDate:(NSDate *)[commentDic valueForKey:@"date"]];
    cell.thirdTitleLabel.text = timeDiff;
    
    NSNumber *num = (NSNumber *)[[ContainerUtility sharedInstance]attributeForKey:kUserLoggedIn];
    if([num boolValue]){
        [cell.replyBtn setHidden:NO];
        cell.replyBtn.frame = CGRectMake(cell.thirdTitleLabel.frame.origin.x + 210, yPosition, 40, 20);
        [cell.replyBtn setTitle:NSLocalizedString(@"reply", nil) forState:UIControlStateNormal];
        [cell.replyBtn setTitleColor:[UIColor lightGrayColor] forState:UIControlStateNormal];
        [cell.replyBtn.titleLabel setFont:[UIFont boldSystemFontOfSize:13]];
        cell.replyBtn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin|
        UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleBottomMargin;
        [cell.replyBtn setBackgroundImage:[UIImage imageNamed:@"background"] forState:UIControlStateNormal];
        [cell.replyBtn setBackgroundImage:[UIImage imageNamed:@"background"] forState:UIControlStateHighlighted];
        [cell.replyBtn addTarget:self action:@selector(replyBtnClicked)forControlEvents:UIControlEventTouchUpInside];
    } else{
        [cell.replyBtn setHidden:YES];
    }
    [cell.avatarBtn addTarget:self action:@selector(avatarClicked) forControlEvents:UIControlEventTouchUpInside];
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0) {
        return playCell.frame.size.height;
    } else if(indexPath.section == 1){
        if(indexPath.row == MAX_FRIEND_COMMENT_COUNT){
            return 44;
        } else {
            CGFloat height = [self caculateCommentCellHeight:indexPath.row dataArray:friendCommentArray];
            return height;
        }
    } else {
        if(indexPath.row == MAX_COMMENT_COUNT){
            return 108;
        } else {
            CGFloat height = [self caculateCommentCellHeight:indexPath.row dataArray:commentArray];
            return height;
        }

    }
}

- (CGFloat)caculateCommentCellHeight:(NSInteger)row dataArray:(NSArray *)dataArray
{
    NSMutableDictionary *commentDic = [dataArray objectAtIndex:row];
    NSString *content = [commentDic objectForKey:@"content"];
    CGSize constraint = CGSizeMake(232, 20000.0f);
    CGSize size = [content sizeWithFont:[UIFont systemFontOfSize:15.0f] constrainedToSize:constraint lineBreakMode:UILineBreakModeWordWrap];
    return 80 + size.height;
}

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if(indexPath.section > 0){
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        CommentListViewController *viewController = [[CommentListViewController alloc]initWithNibName:@"CommentListViewController" bundle:nil];
        if(indexPath.section == 1){
            if (indexPath.row == MAX_FRIEND_COMMENT_COUNT){
                viewController.title = @"全部好友评论";
            } else {
                viewController.title = @"好友评论回复";
            }
        } else {
            if (indexPath.row == MAX_COMMENT_COUNT){
                viewController.title = @"全部评论";
            } else {
                viewController.title = @"评论回复";
            }
        }
        [self.navigationController pushViewController:viewController animated:YES];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    if (section == 0) {
        return 0;
    } else {
        return 24;
    }
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section{
    if(section == 0){
        return nil;
    }
    UIView* customView = [[UIView alloc] initWithFrame:CGRectMake(0,0,self.view.bounds.size.width, 24)];
    customView.backgroundColor = [UIColor blackColor];
    
    // create the label objects
    UILabel *headerLabel = [[UILabel alloc] initWithFrame:CGRectMake(10,0,self.view.bounds.size.width-10, 24)];
    headerLabel.backgroundColor = [UIColor clearColor];
    headerLabel.font = [UIFont boldSystemFontOfSize:12];
    if(section == 1){
        headerLabel.text =  NSLocalizedString(@"friend_comment", nil);
    } else {
        headerLabel.text =  NSLocalizedString(@"user_comment", nil);
    }
    headerLabel.textColor = [UIColor whiteColor];
    [customView addSubview:headerLabel];
    
    return customView;
}

- (void)showIntroduction{
    IntroductionView *lplv = [[IntroductionView alloc] initWithTitle:@"电影名称" content:@"Test"];
    lplv.frame = CGRectMake(0, 0, lplv.frame.size.width, lplv.frame.size.height * 0.9);
    lplv.center = CGPointMake(160, 210 + self.tableView.contentOffset.y);
    lplv.delegate = self;
    [lplv showInView:self.view animated:YES];
    self.tableView.scrollEnabled = NO;
}

- (void)leveyPopListViewDidCancel
{
    self.tableView.scrollEnabled = YES;
}

- (void)avatarClicked
{
    HomeViewController *viewController = [[HomeViewController alloc]initWithNibName:@"HomeViewController" bundle:nil];
    [self.navigationController pushViewController:viewController animated:YES];
}

- (void)playVideo
{
    NSLog(@"play");
}

- (void)replyBtnClicked
{
    PostViewController *viewController = [[PostViewController alloc]initWithNibName:@"PostViewController" bundle:nil];
    [self.navigationController pushViewController:viewController animated:YES];
}

@end