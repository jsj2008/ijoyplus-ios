#import "FriendNewsViewController.h"

@interface FriendNewsViewController(){
    NSMutableArray *itemsArray;
}

/**
 * Loads the table
 *
 * @private
 */
- (void)loadTable;

@end

@implementation FriendNewsViewController

@synthesize table;

#pragma mark -
#pragma mark Memory management

/**
 * Deallocates used memory
 */
- (void)dealloc {
    self.table = nil;
    pullToRefreshManager_ = nil;
}

#pragma mark -
#pragma mark View cycle

/**
 * Called after the controller’s view is loaded into memory.
 */
- (void)viewDidLoad {
    [super viewDidLoad];
}

/**
 * Called when the controller’s view is released from memory
 */
- (void)viewDidUnload {
    [super viewDidUnload];
    
    self.table = nil;
    pullToRefreshManager_ = nil;
}

#pragma mark -
#pragma mark Aux view methods

/*
 * Loads the table
 */
- (void)loadTable {
    
    [self.table reloadData];
    
    [pullToRefreshManager_ tableViewReloadFinished];
}

#pragma mark -
#pragma mark UITableView methods


- (void)viewWillAppear:(BOOL)animated
{
    NSMutableArray *items1 = [[NSMutableArray alloc]initWithCapacity:20];
    [items1 addObject:@"First"];
    [items1 addObject:@"Second"];
    [items1 addObject:@"Third"];
    
    NSMutableArray *items2 = [[NSMutableArray alloc]initWithCapacity:20];
    [items2 addObject:@"1"];
    [items2 addObject:@"2"];
    [items2 addObject:@"3"];
    
    NSMutableArray *items3 = [[NSMutableArray alloc]initWithCapacity:20];
    [items3 addObject:@"壹"];
    
    NSMutableDictionary *itemDic1 = [[NSMutableDictionary alloc]initWithCapacity:10];
    [itemDic1 setValue:items1 forKey:@"2012-09-03"];
    
    NSMutableDictionary *itemDic2 = [[NSMutableDictionary alloc]initWithCapacity:10];
    [itemDic2 setValue:items2 forKey:@"2012-09-04"];
    
    NSMutableDictionary *itemDic3 = [[NSMutableDictionary alloc]initWithCapacity:10];
    [itemDic3 setValue:items3 forKey:@"2012-09-05"];
    
//    NSMutableDictionary *itemDic4 = [[NSMutableDictionary alloc]initWithCapacity:10];
//    [itemDic4 setValue:items1 forKey:@"2012-09-06"];
//    
//    NSMutableDictionary *itemDic5 = [[NSMutableDictionary alloc]initWithCapacity:10];
//    [itemDic5 setValue:items1 forKey:@"2012-09-07"];
    
    itemsArray = [[NSMutableArray alloc]initWithCapacity:10];
    [itemsArray addObject:itemDic1];
    [itemsArray addObject:itemDic2];
    [itemsArray addObject:itemDic3];
//    [itemsArray addObject:itemDic4];
//    [itemsArray addObject:itemDic5];
    
    pullToRefreshManager_ = [[MNMBottomPullToRefreshManager alloc] initWithPullToRefreshViewHeight:60.0f tableView:table withClient:self];
    
    [self loadTable];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return itemsArray.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSMutableDictionary *item = [itemsArray objectAtIndex:section];
    NSEnumerator *keys = item.keyEnumerator;
    NSString *key = [keys nextObject];
    NSMutableArray *array = [item objectForKey:key];
    return array.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    if(cell == nil){
        cell = [[UITableViewCell alloc]initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    NSMutableDictionary *item = [itemsArray objectAtIndex:indexPath.section];
    NSEnumerator *keys = item.keyEnumerator;
    NSMutableArray *items = [item objectForKey:[keys nextObject]];
    cell.textLabel.text = [items objectAtIndex:indexPath.row];
    
    return cell;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section{
    NSMutableDictionary *item = [itemsArray objectAtIndex:section];
    NSEnumerator *keys = item.keyEnumerator;
    NSString *key = [keys nextObject];
    UIView* customView = [[UIView alloc] initWithFrame:CGRectMake(0,0,self.view.bounds.size.width,24)];
    customView.backgroundColor = [UIColor blackColor];
    
    //    // create the label objects
    UILabel *headerLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    headerLabel.backgroundColor = [UIColor clearColor];
    headerLabel.font = [UIFont boldSystemFontOfSize:12];
    headerLabel.text =  key;
    headerLabel.textColor = [UIColor whiteColor];
    [headerLabel sizeToFit];
    headerLabel.center = CGPointMake(headerLabel.frame.size.width/2, customView.frame.size.height/2);
    
    // create the imageView with the image in it
    // create image object
    //    UIImage *myImage = [UIImage imageNamed:@"someimage.png"];
    //    UIImageView *imageView = [[UIImageView alloc] initWithImage:myImage];
    //    imageView.frame = CGRectMake(10,10,50,50);
    //
    //    [customView addSubview:imageView];
    [customView addSubview:headerLabel];
    
    return customView;
}


/**
 * Asks the delegate for the height to use for a row in a specified location.
 * 
 * @param The table-view object requesting this information.
 * @param indexPath: An index path that locates a row in tableView.
 * @return A floating-point value that specifies the height (in points) that row should be.
 */
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return tableView.rowHeight;
}

#pragma mark -
#pragma mark MNMBottomPullToRefreshManagerClient

/**
 * This is the same delegate method as UIScrollView but requiered on MNMBottomPullToRefreshManagerClient protocol
 * to warn about its implementation. Here you have to call [MNMBottomPullToRefreshManager tableViewScrolled]
 *
 * Tells the delegate when the user scrolls the content view within the receiver.
 *
 * @param scrollView: The scroll-view object in which the scrolling occurred.
 */
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    [pullToRefreshManager_ tableViewScrolled];
}

/**
 * This is the same delegate method as UIScrollView but requiered on MNMBottomPullToRefreshClient protocol
 * to warn about its implementation. Here you have to call [MNMBottomPullToRefreshManager tableViewReleased]
 *
 * Tells the delegate when dragging ended in the scroll view.
 *
 * @param scrollView: The scroll-view object that finished scrolling the content view.
 * @param decelerate: YES if the scrolling movement will continue, but decelerate, after a touch-up gesture during a dragging operation.
 */
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    [pullToRefreshManager_ tableViewReleased];
}

/**
 * Tells client that can reload table.
 * After reloading is completed must call [pullToRefreshMediator_ tableViewReloadFinished]
 */
- (void)MNMBottomPullToRefreshManagerClientReloadTable {
    
    // Test loading
    
    reloads_++;
    NSMutableArray *items1 = [[NSMutableArray alloc]initWithCapacity:20];
    [items1 addObject:@"First"];
    [items1 addObject:@"Second"];
    [items1 addObject:@"Third"];
    
    NSMutableArray *items2 = [[NSMutableArray alloc]initWithCapacity:20];
    [items2 addObject:@"1"];
    [items2 addObject:@"2"];
    [items2 addObject:@"3"];
    
    NSMutableArray *items3 = [[NSMutableArray alloc]initWithCapacity:20];
    [items3 addObject:@"壹"];
    
    NSMutableDictionary *itemDic1 = [[NSMutableDictionary alloc]initWithCapacity:10];
    [itemDic1 setValue:items1 forKey:@"2012-09-06"];
    
    NSMutableDictionary *itemDic2 = [[NSMutableDictionary alloc]initWithCapacity:10];
    [itemDic2 setValue:items2 forKey:@"2012-09-07"];
    
    NSMutableDictionary *itemDic3 = [[NSMutableDictionary alloc]initWithCapacity:10];
    [itemDic3 setValue:items3 forKey:@"2012-09-08"];
    
    [itemsArray addObject:itemDic1];
    [itemsArray addObject:itemDic2];
    [itemsArray addObject:itemDic3];
    [self performSelector:@selector(loadTable) withObject:nil afterDelay:2.0f];
}

@end