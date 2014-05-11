//
//  FAELoginViewController.m
//  FbAlbumExplorer
//
//  Created by Ikeda Kazushi on 2014/04/29.
//  Copyright (c) 2014年 Drowsy Dogs, Inc. All rights reserved.
//

#import "FAELoginViewController.h"
#import "FAEAlbumViewController.h"

@interface FAELoginViewController ()

@end

@implementation FAELoginViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.loginView.delegate = self;
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - FBLoginView Delegate

- (void)loginViewShowingLoggedInUser:(FBLoginView *)loginView
{
    NSLog(@"loginViewShowingLoggedInUser");
    self.startButton.enabled = YES;
}

- (void)loginViewShowingLoggedOutUser:(FBLoginView *)loginView
{
    NSLog(@"loginViewShowingLoggedOutUser");
    self.startButton.enabled = NO;
}


#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void) prepareForSegue:(UIStoryboardSegue*)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:@"SegueIDToAlbumVC"]) {
        FAEAlbumViewController* albumVC = segue.destinationViewController;
        albumVC.delegate = self;
        albumVC.mode = kFbAccessModeFriends;
    }
}

#pragma mark - FAEAlbumViewcontroller Delegate
- (void)facebookAlbumPicker:(FAEAlbumViewController*)picker didFinishPickingFbPhoto:(UIImage*)image
{
    if (image) {
        _imageView.image = image;
    }
}


@end
