//
//  FAELoginViewController.h
//  FbAlbumExplorer
//
//  Created by Ikeda Kazushi on 2014/04/29.
//  Copyright (c) 2014年 Drowsy Dogs, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "FAEAlbumViewController.h"
#import "FacebookSDK.h"

@interface FAELoginViewController : UIViewController <FAEAlbumViewControllerDelegate, FBLoginViewDelegate>

@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet FBLoginView *loginView;
@property (weak, nonatomic) IBOutlet UIButton *startButton;

@end
