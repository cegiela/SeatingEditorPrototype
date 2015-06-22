//
//  MCCollectionViewEditableFlowLayout.h
//  SeatingEditorPrototype
//
//  Created by Mat Cegiela on 6/22/15.
//  Copyright (c) 2015 Mat Cegiela. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol MCCollectionViewDelegateEditableFlowLayout <NSObject>

- (void)collectionView:(UICollectionView *)collectionView beganPanGesture:(UIPanGestureRecognizer*)panGesture;

- (void)collectionView:(UICollectionView *)collectionView isTrackingPanGesture:(UIPanGestureRecognizer*)panGesture;

@end

@interface MCCollectionViewEditableFlowLayout : UICollectionViewFlowLayout

@property (nonatomic, strong) UIImageView *liftedItemImage;
@property (nonatomic, strong) id <MCCollectionViewDelegateEditableFlowLayout> delegate;

@end

