//
//  MCCollectionViewPositionalLayout.h
//  SeatingEditorPrototype
//
//  Created by Mat Cegiela on 6/6/15.
//  Copyright (c) 2015 Mat Cegiela. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef NS_OPTIONS(NSUInteger, MCCollectionViewLayoutStickyOptions)
{
    MCCollectionViewLayoutStickyOptionsNone        = 0,
    MCCollectionViewLayoutStickyFirstRow           = 1 << 0,
    MCCollectionViewLayoutStickyFirstColumn        = 1 << 1,
    
    //To be added later
//    MCCollectionViewLayoutStickyLastRow            = 1 << 2,
//    MCCollectionViewLayoutStickyLastColumn         = 1 << 3
};

@protocol MCCollectionViewDelegatePositionalLayout <UICollectionViewDelegate>
@optional

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath;

- (BOOL)collectionView:(UICollectionView *)collectionView enableDragAndDropInlayout:(UICollectionViewLayout*)collectionViewLayout;

- (MCCollectionViewLayoutStickyOptions)stickyOptionsForCollectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout;

//May need invalidateLayout on rotation to ensure sticky cells are repositioned.
- (void)invalidateLayout;

- (BOOL)collectionView:(UICollectionView *)collectionView scrollDuringDraggingInLayout:(UICollectionViewLayout*)collectionViewLayout;

- (void)collectionView:(UICollectionView *)collectionView isDraggingItemInLayout:(UICollectionViewLayout*)collectionViewLayout;

@end

@interface MCCollectionViewPositionalLayout : UICollectionViewLayout

// Fallback size for all cells if no specific sizes provided
@property (nonatomic) CGSize itemSize;

@property (nonatomic, assign) id <MCCollectionViewDelegatePositionalLayout> delegate;
@property (nonatomic, readonly) UILongPressGestureRecognizer *longPressGestureRecognizer;
@property (nonatomic, readonly) UIPanGestureRecognizer *panGestureRecognizer;
@property (nonatomic, readonly) UIImageView *liftedItemImage;

@end

@protocol MCCollectionViewPositionalLayoutCellDelegate <NSObject>
@optional

- (UIImage*)dragAndDropSnapshot;

@end

