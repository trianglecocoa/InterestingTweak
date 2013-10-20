//
//  ECNavigationController.m
//  ECRotationDemo
//
//  Created by Chris Stroud on 12/28/12.

//

#import "ECNavigationController.h"

@implementation ECNavigationController

- (id)initWithRootViewController:(UIViewController *)rootViewController
{
    self = [super initWithRootViewController:rootViewController];
    if (self) {
        self.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"" image:nil tag:0];
    }
    return self;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
	return [[self topViewController] shouldAutorotateToInterfaceOrientation:toInterfaceOrientation];
}

- (NSUInteger)supportedInterfaceOrientations
{
	return [[self topViewController] supportedInterfaceOrientations];
}

@end
