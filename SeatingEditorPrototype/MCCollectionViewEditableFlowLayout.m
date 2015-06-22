//
//  MCCollectionViewEditableFlowLayout.m
//  SeatingEditorPrototype
//
//  Created by Mat Cegiela on 6/22/15.
//  Copyright (c) 2015 Mat Cegiela. All rights reserved.
//

#import "MCCollectionViewEditableFlowLayout.h"

@interface MCCollectionViewEditableFlowLayout() <UIGestureRecognizerDelegate>

@property (nonatomic, strong) UILongPressGestureRecognizer *longPressGestureRecognizer;
@property (nonatomic, strong) UIPanGestureRecognizer *panGestureRecognizer;

@property (nonatomic, strong) NSIndexPath *liftedItemIndexPath;
//@property (nonatomic, strong) UIImageView *liftedItemImage;
@property (nonatomic, assign) CGPoint liftedItemCenter;
@property (nonatomic, assign) CGPoint touchTranslation;

@end

static const CGFloat verticalOffset = 0.20f;

static inline
CGPoint verticalOffsetRelativeToSize(CGPoint point, CGSize size)
{
    return CGPointMake(point.x, point.y - size.height * verticalOffset);
}

static inline
CGPoint pointAplusB(CGPoint pointA, CGPoint pointB)
{
    return CGPointMake(pointA.x + pointB.x, pointA.y + pointB.y);
}

static inline
CGPoint pointAminusB(CGPoint pointA, CGPoint pointB)
{
    return CGPointMake(pointA.x - pointB.x, pointA.y - pointB.y);
}


@implementation MCCollectionViewEditableFlowLayout

- (void)prepareLayout
{
    [super prepareLayout];
    
    if (self.longPressGestureRecognizer == nil)
    {
        self.longPressGestureRecognizer = [[UILongPressGestureRecognizer alloc]
                                           initWithTarget:self
                                           action:@selector(handleLongPressGesture:)];
        self.longPressGestureRecognizer.minimumPressDuration = 0.3;
        [self.collectionView addGestureRecognizer:self.longPressGestureRecognizer];
        self.longPressGestureRecognizer.delegate = self;
    }
    if (self.panGestureRecognizer == nil)
    {
        self.panGestureRecognizer = [[UIPanGestureRecognizer alloc]
                                     initWithTarget:self
                                     action:@selector(handlePanGesture:)];
        [self.collectionView addGestureRecognizer:self.panGestureRecognizer];
        self.panGestureRecognizer.delegate = self;
    }
}

- (void)handleLongPressGesture:(UILongPressGestureRecognizer*)sender
{
    if (sender.state == UIGestureRecognizerStateChanged)
    {
        return;
    }
    
    switch (sender.state)
    {
        case UIGestureRecognizerStateBegan:
        {
            //Make sure gesture is native to this collection view
            if (sender != self.longPressGestureRecognizer)
            {
                return;
            }
            
            CGPoint touchPoint = [sender locationInView:self.collectionView];
            NSIndexPath *indexPath = [self indexPathForItemClosestToPoint:touchPoint];
            
            if (indexPath == nil)
            {
                return;
            }
            
            // Create lifted image to drag
            UICollectionViewCell *cell = [self.collectionView cellForItemAtIndexPath:indexPath];
            cell.highlighted = NO;
            [_liftedItemImage removeFromSuperview];
            _liftedItemImage = [[UIImageView alloc] initWithFrame:cell.frame];
            _liftedItemImage.image = [self imageFromCell:cell];
            _liftedItemCenter = _liftedItemImage.center;
            _liftedItemIndexPath = indexPath;
            
            [self.collectionView addSubview:_liftedItemImage];
            
            [UIView
             animateWithDuration:0.1
             animations:^{
                 _liftedItemImage.transform = CGAffineTransformMakeScale(1.1f, 1.1f);
                 
                 //Move the floating cell image up a bit for visibility
                 _liftedItemImage.center = verticalOffsetRelativeToSize(_liftedItemImage.center, _liftedItemImage.frame.size);
             }
             completion:^(BOOL finished){
                 _liftedItemCenter = _liftedItemImage.center;
             }];
        } break;
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        {
            if(_liftedItemIndexPath == nil)
            {
                return;
            }
            
            // Land lifted image
            NSIndexPath *indexPath = [self indexPathForItemClosestToPoint:_liftedItemImage.center];
            UICollectionViewLayoutAttributes *itemAttributes = [self.collectionView layoutAttributesForItemAtIndexPath:indexPath];
            
            [UIView
             animateWithDuration:0.2
             animations:^{
                 _liftedItemImage.center = itemAttributes.center;
                 _liftedItemImage.transform = CGAffineTransformMakeScale(1.f, 1.f);
             }
             completion:^(BOOL finished){
                 [_liftedItemImage removeFromSuperview];
                 _liftedItemImage = nil;
                 _liftedItemIndexPath = nil;
                 //                 [self.collectionView.collectionViewLayout invalidateLayout];
//                 [self resetOverscroll];
             }];
            
        } break;
        default: break;
    }
}

- (NSIndexPath *)indexPathForItemClosestToPoint:(CGPoint)point
{
    NSArray *layoutAttributes;
    NSInteger closestDistance = NSIntegerMax;
    NSIndexPath *indexPath;
    
    //Find closest visible cell
    layoutAttributes = [self.collectionView.collectionViewLayout layoutAttributesForElementsInRect:self.collectionView.bounds];
    
    for (UICollectionViewLayoutAttributes *layoutAttr in layoutAttributes)
    {
        CGFloat xd = layoutAttr.center.x - point.x;
        CGFloat yd = layoutAttr.center.y - point.y;
        NSInteger dist = sqrtf(xd*xd + yd*yd);
        if (dist < closestDistance)
        {
            closestDistance = dist;
            indexPath = layoutAttr.indexPath;
        }
    }
    
    return indexPath;
}

- (UIImage *)imageFromCell:(UICollectionViewCell *)cell
{
    UIGraphicsBeginImageContextWithOptions(cell.bounds.size, cell.isOpaque, 0.0f);
    [cell.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

- (void)handlePanGesture:(UIPanGestureRecognizer*)sender
{
    CGPoint touchPosition = [sender locationInView:self.collectionView];
    CGPoint contentOffset = self.collectionView.contentOffset;
    
    //Get absolute screen position
    touchPosition = pointAminusB(touchPosition, contentOffset);
    
    switch (sender.state)
    {
        case UIGestureRecognizerStateBegan:
        {
            [self.delegate collectionView:self.collectionView beganPanGesture:sender];
        }
            break;
            
        case UIGestureRecognizerStateChanged:
            [self.delegate collectionView:self.collectionView isTrackingPanGesture:sender];
            _touchTranslation = [sender translationInView:self.collectionView];
            _liftedItemImage.center = pointAplusB(_liftedItemCenter, _touchTranslation);
            break;
        case UIGestureRecognizerStateCancelled:
            break;
        case UIGestureRecognizerStateEnded:
            _touchTranslation = CGPointZero;
            break;
        case UIGestureRecognizerStateFailed:
            _touchTranslation = CGPointZero;
            break;
        default:
            break;
    }
}

#pragma mark - Gesture Recogniser Delegate

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    //Begin panning if we have a lifted item
    if([gestureRecognizer isEqual:_panGestureRecognizer])
    {
        return (_liftedItemIndexPath != nil);
    }
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    //Pan should work with long press, but not other gestures
    if ([gestureRecognizer isEqual:_longPressGestureRecognizer])
    {
        return [otherGestureRecognizer isEqual:_panGestureRecognizer];
    }
    
    if ([gestureRecognizer isEqual:_panGestureRecognizer])
    {
        return ([otherGestureRecognizer isEqual:_longPressGestureRecognizer]);
    }
    
    return NO;
}

@end
