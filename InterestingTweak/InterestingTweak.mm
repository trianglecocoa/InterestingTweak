#import "INTAppDelegate.h"
#import "SVWebViewController.h"
#import "INTListViewController.h"
#import "ECNavigationController.h"
#import "ECTabBarController.h"
#import "INTAnimationManager.h"

#include <logos/logos.h>
#include <substrate.h>

@class SVWebViewController;
@class INTAnimationManager;
@class UITabBarSwappableImageView;
@class INTAppDelegate;
@class INTListViewController;
@class UITableView;
@class UITabBar;

static CGFloat tableViewMinHeight = 460.0f;              // The new minimum height for table views app-wide
static const CGFloat tabBarHeight = 44.0f;               // The new height of the tab bar (rather than 49 pts)
static UITabBarController * tabBarController = nil;      // The UITabBarController instance that will be the root vc
static const unsigned separatorTags[3] = {25, 50, 75};   // The tags used to identify the tab bar separator images

#pragma mark Function Prototypes

// UIKit
static CGSize tabBarSizeThatFits_hooked(UITabBar *, SEL, CGSize);
static void tableViewSetFrame_hooked(UITableView *, SEL, CGRect);
static void (* tableViewSetFrame_original)(UITableView *, SEL, CGRect);

// INTAppDelegate
static void configureAppearance(INTAppDelegate *, SEL);
static BOOL applicationDidFinishLaunchingWithOptions_hooked(INTAppDelegate *, SEL, id, id);
static BOOL (* applicationDidFinishLaunchingWithOptions_original)(INTAppDelegate *, SEL, id, id);
static NSUInteger supportedInterfaceOrientationsForWindow(INTAppDelegate *, SEL, UIApplication *, UIWindow *);
static void tabBarDidSelectViewController(INTAppDelegate *, SEL, UITabBarController *, UINavigationController *);

// INTListViewController
static void viewDidLoad_hooked(INTListViewController *, SEL);
static void setupTabBar_hooked(INTListViewController *, SEL);
static void (* viewDidLoad_original)(INTListViewController *, SEL);
static NSUInteger supportedInterfaceOrientations_hooked(INTListViewController *, SEL);
static BOOL shouldAutorotateToInterfaceOrientation_hooked(INTListViewController *, SEL, UIInterfaceOrientation);
static void tableViewDidSelectRowAtIndexPaths_hooked(INTListViewController *, SEL, UITableView *, NSIndexPath *);

// SVWebViewController
static NSUInteger svWebViewSupportedInterfaceOrientations_hooked(SVWebViewController *, SEL);
static BOOL svWebViewShouldAutoRotateToInterfaceOrientation_hooked(SVWebViewController *, SEL, UIInterfaceOrientation);

#pragma mark -
#pragma mark UIKit Hooks

/*
 *
 * Apparently UITabBar is 49 pts tall instead of 44 pts. That will forever
 * be an enigma to me, but the original faux-tabBar was 44 pixels and
 * we must match that. It's glaringly obvious that a discrepancy exists
 * if we leave it otherwise. This small hook enforces a height of 44.0 pts.
 *
 */
static CGSize tabBarSizeThatFits_hooked(UITabBar * self, SEL _cmd, CGSize size)
{
    return CGSizeMake(size.width, tabBarHeight);
}

/*
 *
 * Something in the app keeps snapping the UITableView instance
 * back to a state that keeps it at a "reduced" height. i.e. AutoLayout nor
 * UIViewAutoResizing are working as expected. When this happens, we're
 * stuck between a rock and a hard place. We're forced to make sure that
 * the tableview maintains a minimum height. Don't try this at home unless
 * you have no other options.
 *
 */
static void tableViewSetFrame_hooked(UITableView * self, SEL _cmd, CGRect rect)
{
    rect.size.height = MAX(tableViewMinHeight, rect.size.height);
    tableViewSetFrame_original(self, _cmd, rect);
}


#pragma mark -
#pragma mark INTAppDelegate Hook

//
// The app delegate manages the root of the app, so naturally it's the place
// that will need the most work for this particular modification.
// See internal comments for what is being done where.
//

/*
 * Separating this because that's one of the things they've taught
 * me in college. Otherwise the applicationDidFinishLaunching would
 * be *pretty* crowded.
 */
static void configureAppearance(INTAppDelegate * self, SEL _cmd)
{
    // Ensure that we're working with the correct table height.
    // This makes sure short devices aren't excluded.
    if ([[UIScreen mainScreen] bounds].size.height < 500) {
        tableViewMinHeight -= 88.0f;
    }
    
    // Store the background image for all the "bottom bars"
    UIImage * barBgImage = [UIImage imageNamed:@"tab_bar"];
    
    // Set it on tab bar instances
    [[UITabBar appearance] setBackgroundImage:barBgImage];
    
    // Set it on toolbar instances
    [[UIToolbar appearance] setBackgroundImage:barBgImage
                            forToolbarPosition:UIBarPositionBottom
                                    barMetrics:UIBarMetricsDefault];
    
    // This is a rough guess as to what the back button insets should be. They work, but may not be *exactly* right.
    UIEdgeInsets backInsets = UIEdgeInsetsMake(0, 14, 0, 9.0f);
    
    // Set the appearance for standard back buttons
    [[UIBarButtonItem appearance] setBackButtonBackgroundImage:[[UIImage imageNamed:@"back"] resizableImageWithCapInsets:backInsets]
                                                      forState:UIControlStateNormal
                                                    barMetrics:UIBarMetricsDefault];
    
    // Set the appearance for selected back buttons
    [[UIBarButtonItem appearance] setBackButtonBackgroundImage:[[UIImage imageNamed:@"back_pressed"] resizableImageWithCapInsets:backInsets]
                                                      forState:UIControlStateSelected
                                                    barMetrics:UIBarMetricsDefault];
    
    // This seems to be about the right font choice
    UIFont * appFont = [UIFont fontWithName:@"PTSans-Bold" size:20.0];
    
    // Set the font appearance for navigation bars
    [[UINavigationBar appearance] setTitleTextAttributes:@{ UITextAttributeFont : appFont }];
    
    // Set the font appearance for things including the back button
    [[UIBarItem appearance] setTitleTextAttributes:@{ UITextAttributeFont : appFont }
                                          forState:(UIControlStateNormal | UIControlStateSelected | UIControlStateHighlighted)];
    
}

/*
 * Add the interface orientation delegate method so that the values
 * specified in the Info.plist are invalidated. Otherwise, they would thwart
 * any attempt at making rotations happen. Nice try, Mike.
 */
static NSUInteger supportedInterfaceOrientationsForWindow(INTAppDelegate * self, SEL _cmd, UIApplication * application, UIWindow * window)
{
    // Support all the things! Except for portrait upside-down because that's silly
    return UIInterfaceOrientationMaskAll & !UIInterfaceOrientationMaskPortraitUpsideDown;
}

/*
 * Tab bar selection callback
 */
static void tabBarDidSelectViewController(INTAppDelegate * self, SEL _cmd, UITabBarController * tabBarController, UINavigationController * viewController)
{
    // Snag the tab bar item that we're dealing with
    UITabBarItem * item = viewController.tabBarItem;
    
    // Iterate through its view hierarchy and locate the correct subview for pulsation
    for (UIView * subview in [[item performSelector:@selector(view)] subviews]) {
        
        // UITabBarSwappableImageView is the class we are after...
        if ([subview isMemberOfClass:[objc_getClass("UITabBarSwappableImageView") class]]) {
            
            // Found it!
            [objc_getClass("INTAnimationManager") pulseView:subview completion:nil];
            break;
        }
        
    }
    
    // Now make the separators disappear as per the original implementation
    switch ([(INTListViewController *)[viewController topViewController] index])
    {
        case 0: {
            [[tabBarController.tabBar viewWithTag:separatorTags[0]] setHidden:YES];
            [[tabBarController.tabBar viewWithTag:separatorTags[1]] setHidden:NO];
            [[tabBarController.tabBar viewWithTag:separatorTags[2]] setHidden:NO];
        } break;
        case 1: {
            [[tabBarController.tabBar viewWithTag:separatorTags[0]] setHidden:YES];
            [[tabBarController.tabBar viewWithTag:separatorTags[1]] setHidden:YES];
            [[tabBarController.tabBar viewWithTag:separatorTags[2]] setHidden:NO];
        } break;
        case 2: {
            [[tabBarController.tabBar viewWithTag:separatorTags[0]] setHidden:NO];
            [[tabBarController.tabBar viewWithTag:separatorTags[1]] setHidden:YES];
            [[tabBarController.tabBar viewWithTag:separatorTags[2]] setHidden:YES];
        } break;
        case 3: {
            [[tabBarController.tabBar viewWithTag:separatorTags[0]] setHidden:NO];
            [[tabBarController.tabBar viewWithTag:separatorTags[1]] setHidden:NO];
            [[tabBarController.tabBar viewWithTag:separatorTags[2]] setHidden:YES];
        } break;
    }
}

/*
 * Helper function to pad a UIImage. For padding UIImages being used in UITabBarItems.
 */
static UIImage * padImage(UIImage * image, CGPoint pt)
{
    CGSize tabSize = CGSizeMake(80, 43);
    UIGraphicsBeginImageContextWithOptions(tabSize, NO, image.scale);
    [image drawInRect:CGRectMake(pt.x, pt.y, image.size.width, image.size.height)];
    image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

/*
 * This is where most setup will occur. Essentially, we need to re-structure the majority of
 * the UI to support rotation, and re-structure we shall!
 */
static BOOL applicationDidFinishLaunchingWithOptions_hooked(INTAppDelegate * self, SEL _cmd, id arg1, id arg2)
{
    // Let the original implementation do its regular setup
    applicationDidFinishLaunchingWithOptions_original(self, _cmd, arg1, arg2);
    
    // Do UIAppearance customizations
    [self performSelector:@selector(configureAppearance)];
    
    // Instantiate the tab bar controller that will be the new root controller
    tabBarController = [[ECTabBarController alloc] init];
    
    // Design & Tech VC
    ECNavigationController * navigationController1 = [[ECNavigationController alloc] initWithRootViewController:self.designTechnologyViewController];
    [navigationController1.tabBarItem setFinishedSelectedImage:padImage([UIImage imageNamed:@"tab_0_selected"], CGPointMake(23.0, 16.0)) withFinishedUnselectedImage:padImage([UIImage imageNamed:@"tab_0"], CGPointMake(23.0, 16.0))];
    
    // Politics VC
	ECNavigationController * navigationController2 = [[ECNavigationController alloc] initWithRootViewController:self.newsPoliticsViewController];
    [navigationController2.tabBarItem setFinishedSelectedImage:padImage([UIImage imageNamed:@"tab_1_selected"], CGPointMake(26.0, 14.0)) withFinishedUnselectedImage:padImage([UIImage imageNamed:@"tab_1"], CGPointMake(26.0, 14.0))];
    
    // TV & Entertainment VC
    ECNavigationController * navigationController3 = [[ECNavigationController alloc] initWithRootViewController:self.tvEntertainmentViewController];
    [navigationController3.tabBarItem setFinishedSelectedImage:padImage([UIImage imageNamed:@"tab_2_selected"], CGPointMake(27.0, 12.0)) withFinishedUnselectedImage:padImage([UIImage imageNamed:@"tab_2"], CGPointMake(27.0, 12.0))];
    
    // Sports VC
	ECNavigationController * navigationController4 = [[ECNavigationController alloc] initWithRootViewController:self.sportsViewController];
    [navigationController4.tabBarItem setFinishedSelectedImage:padImage([UIImage imageNamed:@"tab_3_selected"], CGPointMake(27.0, 14.0)) withFinishedUnselectedImage:padImage([UIImage imageNamed:@"tab_3"], CGPointMake(27.0, 14.0))];
    
    // Hand those controllers to the tabBarController to manage
	tabBarController.viewControllers = @[navigationController1, navigationController2, navigationController3, navigationController4];
    
    // We need to know when the user taps on a tab to perform the
    // pulse animation. Unforunately, we have on way to express that
    // this class conforms to that protocol, so we use performSelector
    // to silence the inevitable compiler warning.
    [tabBarController performSelector:@selector(setDelegate:) withObject:self];
    
    // Load up the separator image. We'll need some information from it
    // before we stick it into the tab bar's view hierarchy.
    UIImage * separatorImage = [UIImage imageNamed:@"separator"];
    
    // Store some dimensions for the sake of readability
    CGFloat separatorWidth = separatorImage.size.width;
    CGFloat tabBarWidth = tabBarController.tabBar.frame.size.width;
    CGFloat singleTabWith = tabBarWidth / 4.0f;
    
    // Insert the separator images into the tabbar view hierarchy. It won't bite.
    for (unsigned i = 1, j=0; i < 4; i++, j++) {
        
        // Create a separator image view, set the tag (145 is arbitrary, I just don't want collisions later)
        // Then calculate/set the frame for the image view.
        // Note: The frame calculation is just an estimate. It's probably wrong by a little.
        UIImageView * separatorView = [[UIImageView alloc] initWithImage:separatorImage];
        separatorView.tag = separatorTags[j];
        separatorView.frame = CGRectMake(roundf(i * 80.0f), 0.0f, separatorWidth, separatorImage.size.height);
        
        // The first tab will be selected, so we don't want the initial
        // separator to be displayed at first launch.
        if (i == 1) {
            separatorView.hidden = YES;
        }
        
        // Insert that thing
        [tabBarController.tabBar addSubview:separatorView];
    }
    
    // The "selected state" image for the tab is not the correct
    // width, so here we simply redraw it to be the correct size.
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(singleTabWith, tabBarHeight), YES, [[UIScreen mainScreen] scale]);
    UIImage * selectedImage = [UIImage imageNamed:@"indented"];
    [selectedImage drawInRect:CGRectMake(0, 0, singleTabWith, tabBarHeight)];
    selectedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    // Set up that last bit of appearance and we're basically finished
    [[UITabBar appearance] setSelectionIndicatorImage:selectedImage];
    
    // Set the rootVC even though one was already created for us.
    [self.window setRootViewController:tabBarController];
    
    return YES;
}

#pragma mark -
#pragma mark INTListViewController Hook
//
// INTListViewController handles the display of the loaded RSS content
// and, as such, is the main viewport of the app. Here we need to re-engineer
// what happens when a cell is tapped so that the imposed view stack is
// supported, as well as prevent the custom tab bar from being constructed.
//


/*
 * To match existing behavior, make the back button text "Back"
 */
static void viewDidLoad_hooked(INTListViewController * self, SEL _cmd)
{
    viewDidLoad_original(self, _cmd);
    
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Back"
                                                                             style:UIBarButtonItemStyleBordered
                                                                            target:nil
                                                                            action:nil];
}

/*
 * This view controller needs to only support portrait mode
 */
static BOOL shouldAutorotateToInterfaceOrientation_hooked(INTListViewController * self, SEL _cmd, UIInterfaceOrientation toInterfaceOrientation)
{
	return UIInterfaceOrientationIsPortrait(toInterfaceOrientation);
    
}

/*
 * This view controller needs to only support portrait mode
 */
static NSUInteger supportedInterfaceOrientations_hooked(INTListViewController * self, SEL _cmd)
{
	return UIInterfaceOrientationMaskPortrait;
}

/*
 * The custom tab bar in Interesting was designed to exist inside each
 * view controller separately, then notify its parent structure when
 * the root view controller should be swapped out. Now we have a tab controller
 * in the root, so this is redundant and should be removed. All we can do is
 * block any actual setup from occurring.
 */
static void setupTabBar_hooked(INTListViewController * self, SEL _cmd)
{
    // Do nothing
}

/*
 * The original implementation handled its own view controller transition. While that's
 * nice in certain situations, the new structure can't support that. We need the containing
 * navigation controller to handle it, not the per-instance one that existed originally.
 * Unfortunately, there really isn't a way to take bits and peices from the original
 * implementation, so we need to re-implement this functionality.
 */
static void tableViewDidSelectRowAtIndexPaths_hooked(INTListViewController * self, SEL _cmd, UITableView * tableView, NSIndexPath * indexPath)
{
    // Fetch the item from our model
    NSDictionary * item = self.items[indexPath.row];
    
    // Get the URL from it
    NSString * address = item[@"link"];
    
    // It appears that the JSON that Interesting receives is somewhat non-standardized...
    //
    //
    //       (╯°□°)╯︵ ┻━┻
    //
    //
    // So if "link" doesn't yield a URL, hopefully "url" is the only other variant.
    if (!address) {
        address = item[@"url"];
    }
    
    // Instantiate a new detail controller, but make sure that it's going to hide the tab bar
    // When pushed. Otherwise it's just ugly.
    SVWebViewController * controller = [[objc_getClass("SVWebViewController") alloc] initWithAddress:address];
    controller.hidesBottomBarWhenPushed = YES;
    controller.title = @"Loading...";
    
    // Finally, push that thing onto the stack so we can see that Reddit post in all its glory!
    [self.navigationController pushViewController:controller animated:YES];
}


#pragma mark -
#pragma mark SVWebViewController Hook
//
// SVWebViewController is a 3rd party component used to view web pages
// without a bunch of extra work: https://github.com/samvermette/SVWebViewController
//
// We just need it to make it rotate so we can watch our YouTube videos.
//

/*
 * This view controller needs to support both portrait AND landscape modes
 */
static BOOL svWebViewShouldAutoRotateToInterfaceOrientation_hooked(SVWebViewController * self, SEL _cmd, UIInterfaceOrientation toInterfaceOrientation)
{
	return YES;
}

/*
 * This view controller needs to support both portrait AND landscape modes
 * But not upside down because that's silly.
 */
static NSUInteger svWebViewSupportedInterfaceOrientations_hooked(SVWebViewController * self, SEL _cmd)
{
	return UIInterfaceOrientationMaskAllButUpsideDown;
}

/*
 * This is the initializer/constructor for the dylib.
 * Here we do all the setup and runtime operations to create
 * all of the hooks necessary to make this work.
 */
static __attribute__((constructor)) void interestingTweakConstructor()
{
	@autoreleasepool
    {
        // UITabBar
        Class UITabBar_class = objc_getClass("UITabBar");
        MSHookMessageEx(UITabBar_class, @selector(sizeThatFits:), (IMP)&tabBarSizeThatFits_hooked, NULL);  // Not calling the original implementation
        
        // UITableView
        Class UITableView_class = objc_getClass("UITableView");
        MSHookMessageEx(UITableView_class, @selector(setFrame:), (IMP)&tableViewSetFrame_hooked, (IMP *)&tableViewSetFrame_original);
        
        // INTAppDelegate
        Class INTAppDelegate_class = objc_getClass("INTAppDelegate");
        class_addMethod(INTAppDelegate_class, @selector(configureAppearance), (IMP)&configureAppearance, "v@:");
        class_addMethod(INTAppDelegate_class, @selector(application:supportedInterfaceOrientationsForWindow:), (IMP)&supportedInterfaceOrientationsForWindow, "L@:@@");
        class_addMethod(INTAppDelegate_class, @selector(tabBarController:didSelectViewController:), (IMP)&tabBarDidSelectViewController, "v@:@@");
        
        MSHookMessageEx(INTAppDelegate_class, @selector(application:didFinishLaunchingWithOptions:), (IMP)&applicationDidFinishLaunchingWithOptions_hooked, (IMP *)&applicationDidFinishLaunchingWithOptions_original);
        
        // INTListViewController
        Class INTListViewController_class = objc_getClass("INTListViewController");
        MSHookMessageEx(INTListViewController_class, @selector(viewDidLoad), (IMP)&viewDidLoad_hooked, (IMP *)&viewDidLoad_original);
        MSHookMessageEx(INTListViewController_class, @selector(shouldAutorotateToInterfaceOrientation:), (IMP)&shouldAutorotateToInterfaceOrientation_hooked, NULL);         // Not calling the original implementation
        MSHookMessageEx(INTListViewController_class, @selector(supportedInterfaceOrientations), (IMP)&supportedInterfaceOrientations_hooked, NULL);                          // Not calling the original implementation
        MSHookMessageEx(INTListViewController_class, @selector(setupTabBar), (IMP)&setupTabBar_hooked, NULL);                                                                // Not calling the original implementation
        MSHookMessageEx(INTListViewController_class, @selector(tableView:didSelectRowAtIndexPath:), (IMP)&tableViewDidSelectRowAtIndexPaths_hooked, NULL);                   // Not calling the original implementation
        
        // SVWebViewController
        Class SVWebViewController_class = objc_getClass("SVWebViewController");
        MSHookMessageEx(SVWebViewController_class, @selector(shouldAutorotateToInterfaceOrientation:), (IMP)&svWebViewShouldAutoRotateToInterfaceOrientation_hooked, NULL);  // Not calling the original implementation
        MSHookMessageEx(SVWebViewController_class, @selector(supportedInterfaceOrientations), (IMP)&svWebViewSupportedInterfaceOrientations_hooked, NULL);                   // Not calling the original implementation
        
    }
}
