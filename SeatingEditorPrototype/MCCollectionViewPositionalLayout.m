//
//  MCCollectionViewPositionalLayout.m
//  SeatingEditorPrototype
//
//  Created by Mat Cegiela on 6/6/15.
//  Copyright (c) 2015 Mat Cegiela. All rights reserved.
//

#import "MCCollectionViewPositionalLayout.h"

@interface MCCollectionViewPositionalLayout() <UIGestureRecognizerDelegate>

@property (nonatomic, assign) MCCollectionViewLayoutStickyOptions stickySetting;
@property (nonatomic, strong) NSMutableArray *itemAttributes;
@property (nonatomic, strong) NSMutableArray *stickyAttributes;
@property (nonatomic, assign) CGSize totalLayoutSize;

@property (nonatomic, strong) UILongPressGestureRecognizer *longPressGestureRecognizer;
@property (nonatomic, strong) UIPanGestureRecognizer *panGestureRecognizer;
@property (nonatomic, strong) NSIndexPath *liftedItemIndexPath;
@property (nonatomic, strong) UIImageView *liftedItemImage;
@property (nonatomic, assign) CGPoint liftedItemCenter;
@property (nonatomic, assign) CGPoint touchTranslation;
@property (nonatomic, strong) CADisplayLink *refreshSyncTimer;

@property (nonatomic, assign) UIEdgeInsets dragScrollBorder;
@property (nonatomic, assign) CGFloat dragScrollSpeed;
@property (nonatomic, assign) BOOL dragAndDropEnabled;

@end

@implementation MCCollectionViewPositionalLayout

#pragma mark - CollectionView Layout Methods

- (void)invalidateLayout
{
    self.totalLayoutSize = CGSizeZero;
    [super invalidateLayout];
}

- (void)prepareLayout
{
    //NOTE: Tight UI Loop if shouldInvalidateLayoutForBoundsChange returns YES

    [super prepareLayout];
    
    //Using UICollectionView Sections as 'colums', and Items as 'rows'
    NSInteger columnCount = self.collectionView.numberOfSections;
    if (columnCount == 0)
    {
        return;
    }
    if (_itemAttributes.count == 0)
    {
        //Initial setup of attributes
        [self buildLayoutAttributes];
    }
    
    //NOTE: Testing short cycle to improve performance
    if (_totalLayoutSize.height > 0)
    {
        //Layout is already calculated, only adjust sticky cells
        for (UICollectionViewLayoutAttributes *item in _stickyAttributes)
        {
            [self adjustPositionForStickyCellAttributes:item];
        }
        
        return;
    }
    
    [self checkStickyCellOptions];
    [self checkDragAndDropEnabled];
    
    if (self.itemSize.width == 0 || self.itemSize.height == 0)
    {
        //Set default cell size if needed
        self.itemSize = CGSizeMake(50.0, 50.0);
    }
    
    CGFloat xPosition = 0.0;
    CGFloat yPosition = 0.0;
    CGFloat totalWidth = 0.0;
    CGFloat totalHeight = 0.0;
        
    for (int column = 0; column < columnCount; column ++)
    {
        CGFloat columnHeight = 0.0;
        CGFloat columnWidth = 0.0;
        NSInteger rowCount = [self.collectionView numberOfItemsInSection:column];
        
        yPosition = 0.0; //Reset for each cloumn
        
        for (int row = 0; row < rowCount; row ++)
        {
            NSIndexPath *indexPath = [NSIndexPath indexPathForItem:row inSection:column];
            UICollectionViewLayoutAttributes *attributes = [self layoutAttributesForItemAtIndexPath:indexPath];
            
            CGSize cellSize = self.itemSize; // Default size, if not specified by delegate
            
            if ([self.delegate respondsToSelector:@selector(collectionView:layout:sizeForItemAtIndexPath:)])
            {
                cellSize = [self.delegate collectionView:self.collectionView layout:self sizeForItemAtIndexPath:indexPath];
            }
            
            attributes.size = cellSize;
            attributes.frame = CGRectIntegral(CGRectMake(xPosition,
                                                         yPosition,
                                                         cellSize.width,
                                                         cellSize.height));
            
            if (_stickySetting)
            {
                [self adjustPositionForStickyCellAttributes:attributes];
            }
            
            yPosition += cellSize.height;
            columnHeight += cellSize.height;
            
            //Column width must equal the widest of it's items
            if (columnWidth < cellSize.width)
            {
                columnWidth = cellSize.width;
            }
        }
        
        totalWidth += columnWidth;
        xPosition += columnWidth;
        
        //Content height must equal the tallest column height
        if (totalHeight < columnHeight)
        {
            totalHeight = columnHeight;
        }
    }
    
    _totalLayoutSize = CGSizeMake(totalWidth, totalHeight);
}

- (CGSize)collectionViewContentSize
{
    return _totalLayoutSize;
}

- (void)buildLayoutAttributes
{
    NSInteger columnCount = self.collectionView.numberOfSections;

    _itemAttributes = [NSMutableArray arrayWithCapacity:columnCount];
    _stickyAttributes = [NSMutableArray new];
    
    for (int column = 0; column < columnCount; column ++)
    {
        NSInteger rowCount = [self.collectionView numberOfItemsInSection:column];
        NSMutableArray *rowsAttributes = [NSMutableArray arrayWithCapacity:rowCount];
        for (int row = 0; row < rowCount; row ++)
        {
            NSIndexPath *indexPath = [NSIndexPath indexPathForItem:row inSection:column];
            UICollectionViewLayoutAttributes *attributes = [UICollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:indexPath];
            [rowsAttributes addObject:attributes];
        }
        [_itemAttributes addObject:rowsAttributes];
    }
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath
{
    UICollectionViewLayoutAttributes *attributes = _itemAttributes[indexPath.section][indexPath.row];
    return attributes;
}

- (NSArray *)layoutAttributesForElementsInRect:(CGRect)rect
{
    NSMutableArray *attributes = [NSMutableArray new];
    for (NSArray *section in _itemAttributes) {
        [attributes addObjectsFromArray:[section filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(UICollectionViewLayoutAttributes *evaluatedObject, NSDictionary *bindings) {
            return CGRectIntersectsRect(rect, [evaluatedObject frame]);
        }]]];
    }
    
    return attributes;
}

- (BOOL)shouldInvalidateLayoutForBoundsChange:(CGRect)newBounds
{
    return YES; //NOTE: if YES, prepareLayout is called constantly during scrolling
}

#pragma mark - Sticky Cells

- (void)checkStickyCellOptions
{
    if ([self.delegate respondsToSelector:@selector(stickyOptionsForCollectionView:layout:)])
    {
        NSInteger setting = [self.delegate stickyOptionsForCollectionView:self.collectionView layout:self];
        if (setting != _stickySetting)
        {
            _stickySetting = setting;
            [_stickyAttributes removeAllObjects];
        }
    }
}

- (void)adjustPositionForStickyCellAttributes:(UICollectionViewLayoutAttributes*)attributes
{
    BOOL firstRowSticky = ((_stickySetting & MCCollectionViewLayoutStickyFirstRow) == MCCollectionViewLayoutStickyFirstRow);
    BOOL firstColumnSticky = ((_stickySetting & MCCollectionViewLayoutStickyFirstColumn) == MCCollectionViewLayoutStickyFirstColumn);
    
    if (firstRowSticky && attributes.indexPath.row == 0)
    {
        if (![_stickyAttributes containsObject:attributes])
        {
            [_stickyAttributes addObject:attributes];
        }
        
        attributes.zIndex = NSIntegerMax - 1;
        
        if (self.collectionView.contentOffset.y > 0)
        {
            CGRect frame = attributes.frame;
            frame.origin.y = self.collectionView.contentOffset.y;
            attributes.frame = frame;
        }
        else
        {
            CGRect frame = attributes.frame;
            frame.origin.y = 0;
            attributes.frame = frame;
        }
    }
    if (firstColumnSticky && attributes.indexPath.section == 0)
    {
        if (![_stickyAttributes containsObject:attributes])
        {
            [_stickyAttributes addObject:attributes];
        }
        
        attributes.zIndex = NSIntegerMax - 1;

        if (self.collectionView.contentOffset.x > 0)
        {
            CGRect frame = attributes.frame;
            frame.origin.x = self.collectionView.contentOffset.x;
            attributes.frame = frame;
        }
        else
        {
            CGRect frame = attributes.frame;
            frame.origin.x = 0;
            attributes.frame = frame;
        }
    }
    // Ensure the corner tile always floats above the rest by setting max zIndex
    if (attributes.indexPath.section == 0 && attributes.indexPath.row == 0)
    {
        attributes.zIndex = NSIntegerMax;
    }
}

#pragma mark - Drag And Drop

- (void)checkDragAndDropEnabled
{
    if ([self.delegate respondsToSelector:@selector(collectionView:enableDragAndDropInlayout:)])
    {
        self.dragAndDropEnabled = [self.delegate collectionView:self.collectionView enableDragAndDropInlayout:self];
    }
    if (self.dragAndDropEnabled)
    {
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
        
        _dragScrollBorder = UIEdgeInsetsMake(50.0f, 50.0f, 50.0f, 50.0f);
        _dragScrollSpeed = 300.f;
    }
    else
    {
        [self.collectionView removeGestureRecognizer:self.longPressGestureRecognizer];
        self.longPressGestureRecognizer = nil;
        [self.collectionView removeGestureRecognizer:self.panGestureRecognizer];
        self.panGestureRecognizer = nil;
    }
}

- (void)handleLongPressGesture:(UILongPressGestureRecognizer *)sender
{
    if (sender.state == UIGestureRecognizerStateChanged) {
        return;
    }
    
    switch (sender.state) {
        case UIGestureRecognizerStateBegan: {
            
            CGPoint touchPoint = [sender locationInView:self.collectionView];
            NSIndexPath *indexPath = [self indexPathForItemClosestToPoint:touchPoint];

            if (indexPath == nil) {
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
                 
                 _liftedItemImage.center = [self offsetPoint:_liftedItemImage.center proportionallyToSize:_liftedItemImage.frame.size];
             }
             completion:^(BOOL finished){
                 _liftedItemCenter = _liftedItemImage.center;
             }];
            
        } break;
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled: {
            if(_liftedItemIndexPath == nil) {
                return;
            }
            
            // Land lifted image
            NSIndexPath *indexPath = [self indexPathForItemClosestToPoint:_liftedItemImage.center];
            UICollectionViewLayoutAttributes *layoutAttributes = [self.collectionView layoutAttributesForItemAtIndexPath:indexPath];

            [UIView
             animateWithDuration:0.2
             animations:^{
                 _liftedItemImage.center = layoutAttributes.center;
                 _liftedItemImage.transform = CGAffineTransformMakeScale(1.f, 1.f);
             }
             completion:^(BOOL finished) {
                 [_liftedItemImage removeFromSuperview];
                 _liftedItemImage = nil;
                 _liftedItemIndexPath = nil;
                 [self.collectionView.collectionViewLayout invalidateLayout];
             }];
            
        } break;
        default: break;
    }
}

- (CGPoint)addPoint:(CGPoint)a toPoint:(CGPoint)b
{
    return CGPointMake(a.x + b.x, a.y + b.y);
}

- (CGPoint)offsetPoint:(CGPoint)point proportionallyToSize:(CGSize)size
{
    return CGPointMake(point.x, point.y - size.height * 0.20);
}

- (void)handlePanGesture:(UIPanGestureRecognizer *)sender
{
    if(sender.state == UIGestureRecognizerStateChanged) {
        _touchTranslation = [sender translationInView:self.collectionView];
        _liftedItemImage.center = [self addPoint:_liftedItemCenter toPoint:_touchTranslation];

        // Scroll...
        }
}
    
- (NSIndexPath *)indexPathForItemClosestToPoint:(CGPoint)point
{
    NSArray *layoutAttrsInRect;
    NSInteger closestDist = NSIntegerMax;
    NSIndexPath *indexPath;
    
    // We need original positions of cells
    layoutAttrsInRect = [self.collectionView.collectionViewLayout layoutAttributesForElementsInRect:self.collectionView.bounds];
    
    // What cell are we closest to?
    for (UICollectionViewLayoutAttributes *layoutAttr in layoutAttrsInRect) {
        CGFloat xd = layoutAttr.center.x - point.x;
        CGFloat yd = layoutAttr.center.y - point.y;
        NSInteger dist = sqrtf(xd*xd + yd*yd);
        if (dist < closestDist) {
            closestDist = dist;
            indexPath = layoutAttr.indexPath;
        }
    }
    
    return indexPath;
}

- (UIImage *)imageFromCell:(UICollectionViewCell *)cell {
    UIGraphicsBeginImageContextWithOptions(cell.bounds.size, cell.isOpaque, 0.0f);
    [cell.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
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
