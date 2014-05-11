//
//  FbAlbumCollectionCell.h
//  FbAlbumExplorer
//
//  Created by Ikeda Kazushi on 2014/04/29.
//  Copyright (c) 2014年 Drowsy Dogs, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface FbAlbumCollectionCell : UICollectionViewCell <UICollectionViewDataSource, UICollectionViewDelegate>

@property (weak, nonatomic) IBOutlet UILabel *collectionCellLabel;
@property (weak, nonatomic) IBOutlet UIImageView *imageView;

@end
