//
//  ECTabBarController.m
//  ECRotationDemo
//
//  Created by Chris Stroud on 12/28/12.
//

#import "ECTabBarController.h"

@implementation ECTabBarController

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
	return [[self selectedViewController] shouldAutorotateToInterfaceOrientation:toInterfaceOrientation];
}

- (NSUInteger)supportedInterfaceOrientations
{
	return [[self selectedViewController] supportedInterfaceOrientations];
}

- (NSString *)title
{
	return [[self selectedViewController] title];
}



@end
