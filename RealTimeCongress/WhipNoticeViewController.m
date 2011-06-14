#import "WhipNoticeViewController.h"
#import "SunlightLabsRequest.h"
#import "JSONKit.h"

@implementation WhipNoticeViewController

@synthesize parsedHearingData;
@synthesize jsonData;
@synthesize jsonKitDecoder;
@synthesize loadingIndicator;
@synthesize opQueue;

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)dealloc
{
    [super dealloc];
    [loadingIndicator release];
    [opQueue release];
    [parsedHearingData release];
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    //Set Title
    self.title = @"Whip Notices";
    
    //Set up refresh button
    UIBarButtonItem *refreshButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self  action:@selector(refresh)];
    self.navigationItem.rightBarButtonItem = refreshButton;
    
    //Make cells unselectable
    self.tableView.allowsSelection = NO;
    
    //Initialize the operation queue
    opQueue = [[NSOperationQueue alloc] init];
    
    //An activity indicator to indicate loading
    loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    [loadingIndicator setCenter:self.view.center];
    [self.view addSubview:loadingIndicator];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    //Refresh data
    [self refresh];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    if ([parsedWhipNoticeData count] > 0) {
        return [parsedWhipNoticeData count];
    }
    else {
        return 1;
    }
    
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier] autorelease];
    }
    if ([parsedWhipNoticeData count] > 0) {
        // Configure the cell...
        NSString *partyType;
        NSString *noticeType;
        if ([[[parsedWhipNoticeData objectAtIndex:indexPath.row] objectForKey:@"party"] isEqual:@"D"]) {
            partyType = @"Democratic";
        }
        else {
            partyType = @"Republican";
        }
        
        noticeType = [[[parsedWhipNoticeData objectAtIndex:indexPath.row] objectForKey:@"notice_type"] capitalizedString];
        
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"yyyy-MM-dd"];
        NSDate *noticeDate = [dateFormatter dateFromString: [[parsedWhipNoticeData objectAtIndex:indexPath.row] objectForKey:@"for_date"]];
        [dateFormatter setDateFormat:@"EEEE, MMMM d"];
        NSString *formattedDate = [dateFormatter stringFromDate:noticeDate];
        
        cell.textLabel.text = [NSString stringWithFormat:@"%@ %@ Whip", partyType, noticeType];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@", formattedDate];
    }

    return cell;
}


#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Navigation logic may go here. Create and push another view controller.
    /*
     <#DetailViewController#> *detailViewController = [[<#DetailViewController#> alloc] initWithNibName:@"<#Nib name#>" bundle:nil];
     // ...
     // Pass the selected object to the new view controller.
     [self.navigationController pushViewController:detailViewController animated:YES];
     [detailViewController release];
     */
}

#pragma mark - UI Actions

- (void) refresh
{
    //Disable scrolling while data is loading
    self.tableView.scrollEnabled = NO;
    
    //Animate the activity indicator when loading data
    [self.loadingIndicator startAnimating];
    
    //Asynchronously retrieve data
    NSInvocationOperation* dataRetrievalOp = [[[NSInvocationOperation alloc] initWithTarget:self
                                                                                   selector:@selector(retrieveData) object:nil] autorelease];
    [dataRetrievalOp addObserver:self forKeyPath:@"isFinished" options:0 context:NULL];
    [opQueue addOperation:dataRetrievalOp];
}

- (void) parseData
{
    jsonKitDecoder = [JSONDecoder decoder];
    NSDictionary *items = [jsonKitDecoder objectWithData:jsonData];
    NSArray *data = [items objectForKey:@"documents"];
    
    //Sort data by legislative day then split in to sections
    NSSortDescriptor *sortByDate = [NSSortDescriptor sortDescriptorWithKey:@"for_date" ascending:NO];
    NSSortDescriptor *sortByTime = [NSSortDescriptor sortDescriptorWithKey:@"posted_at" ascending:YES selector:@selector(localizedCaseInsensitiveCompare:)];
    NSArray *descriptors = [[NSArray alloc] initWithObjects: sortByDate, sortByTime,nil];
    parsedWhipNoticeData = [NSArray arrayWithArray:[data sortedArrayUsingDescriptors:descriptors]];
    
    // Get the current date and format it
    NSDateFormatter *dateFomatter = [[NSDateFormatter alloc] init];
    [dateFomatter setDateFormat:@"yyyy-MM-dd"];
    NSString *todaysDate = [dateFomatter stringFromDate:[NSDate date]];
    
    NSPredicate *datePredicate = [NSPredicate predicateWithFormat:@"for_date >= %@", todaysDate];
    NSArray *testArray = [parsedWhipNoticeData filteredArrayUsingPredicate:datePredicate];
    if ([testArray count] == 0) {
        NSDictionary *mostRecentNotice = [parsedWhipNoticeData objectAtIndex:0];
        parsedWhipNoticeData = [[NSArray alloc] initWithObjects:mostRecentNotice, nil];
    }
    else {
        parsedWhipNoticeData = [[NSArray alloc] initWithArray:testArray];
    }
    
}

- (void) retrieveData
{
    // Generate request URL using Sunlight Labs Request class
    NSDictionary *requestParameters = [[NSDictionary alloc] initWithObjectsAndKeys:
                                       [NSString stringWithFormat:@"%@", REQUEST_PAGE_SIZE], @"per_page",
                                       @"for_date", @"sort",
                                       @"desc", @"order",
                                       nil];
    SunlightLabsRequest *dataRequest = [[SunlightLabsRequest alloc] initRequestWithParameterDictionary:requestParameters APICollection:Documents APIMethod:nil];
    
    //JSONKit requests
    //Request data based on segemented control selection
    jsonData = [NSData dataWithContentsOfURL:[dataRequest.request URL]];
    
    if (jsonData != NULL) {
        [self parseData];
    }
}

#pragma mark Key-Value Observing methods
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if ([keyPath isEqual:@"isFinished"]) {
        //Reload the table once data retrieval is complete
        [self.tableView reloadData];
        
        //Hide the activity indicator once loading is complete
        [loadingIndicator stopAnimating];
        
        //Re-enable scrolling once loading is complete and the loading indicator disappears
        self.tableView.scrollEnabled = YES;
    }
}

@end
