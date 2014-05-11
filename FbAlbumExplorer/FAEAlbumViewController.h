//
//  FAEAlbumViewController.h
//  FbAlbumExplorer
//
//  Created by Ikeda Kazushi on 2014/04/27.
//  Copyright (c) 2014年 Drowsy Dogs, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef enum {
    kFbAccessModeFriends,
    kFbAccessModeAlbums,
    kFbAccessModePhotos
} FbAccessMode;

@class FAEAlbumViewController;
@protocol FAEAlbumViewControllerDelegate <NSObject>
- (void)facebookAlbumPicker:(FAEAlbumViewController*)picker didFinishPickingFbPhoto:(UIImage*)image;
@end

@interface FAEAlbumViewController : UIViewController <UICollectionViewDelegate, UICollectionViewDataSource, FAEAlbumViewControllerDelegate>

@property (readwrite, nonatomic) FbAccessMode  mode;
@property (strong, nonatomic) id<FAEAlbumViewControllerDelegate> delegate;
@property (weak, nonatomic) IBOutlet UICollectionView *fbAlbumCollectionView;

- (IBAction)backButtonTapped:(id)sender;

@end
