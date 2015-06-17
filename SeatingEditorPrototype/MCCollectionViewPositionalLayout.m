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

@property (nonatomic, strong) UILongPressGestureRecognizer *longPressGestureRecognizer;
@property (nonatomic, strong) UIPanGestureRecognizer *panGestureRecognizer;

@property (nonatomic, strong) NSIndexPath *liftedItemIndexPath;
@property (nonatomic, strong) UIImageView *liftedItemImage;
@property (nonatomic, assign) CGPoint liftedItemCenter;
@property (nonatomic, assign) CGPoint touchTranslation;

@property (nonatomic, assign) CGSize totalLayoutSize;
@property (nonatomic, strong) CADisplayLink *scrollTimer;
@property (nonatomic, assign) CGPoint dragScrollSpeed;
@property (nonatomic, assign) BOOL dragAndDropEnabled;

@end


static const CGPoint maxScrollSpeed = {800.f, 800.f};
static const CGPoint maxOverscroll = {30.f, 30.f};
static const CGFloat verticalOffset = 0.20f;
static const UIEdgeInsets dragScrollBorder = {80.f, 80.f, 80.f, 80.f};
static const CGSize defaultItemSize = {50.f, 50.f};
static const BOOL stickyOverscroll = NO;
static const BOOL speedOverSmotheness = NO;


#pragma mark - Coordinate math

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

static inline
CGPoint verticalOffsetRelativeToSize(CGPoint point, CGSize size)
{
    return CGPointMake(point.x, point.y - size.height * verticalOffset);
}

static inline
CGFloat speedProportionalToDistance(CGFloat maxSpeed, CGFloat distance, CGFloat maxDistance)
{
    CGFloat resultSpeed = MIN(maxSpeed, maxSpeed * (distance/maxDistance));
    return resultSpeed;
}

static inline
CGFloat factorByOverscroll(CGFloat overscroll, CGFloat maxOverscroll)
{
    CGFloat result = 1-(overscroll/maxOverscroll);
    result = round (result * 10) / 10.0;
    return result;
}

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

    if (_totalLayoutSize.height > 0)
    {
        //Layout is already calculated, only adjust sticky cells
        
        NSArray *stickyIndexPaths = self.collectionView.indexPathsForVisibleItems;

        for (UICollectionViewLayoutAttributes *item in _stickyAttributes)
        {
            if ([stickyIndexPaths containsObject:item.indexPath])
            {
                [self adjustPositionForStickyCellAttributes:item];
            }
        }
        
        return;
    }
    
    [super prepareLayout];
    [self calculateEntireLayout]; //Costly operation
}

- (void)calculateEntireLayout
{
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
    
    
    [self checkStickyCellOptions];
    [self checkDragAndDropEnabled];
    
    if (self.itemSize.width == 0 || self.itemSize.height == 0)
    {
        //Set default cell size if needed
        self.itemSize = defaultItemSize;
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
    for (NSArray *section in _itemAttributes)
    {
        [attributes addObjectsFromArray:[section filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(UICollectionViewLayoutAttributes *evaluatedObject, NSDictionary *bindings) {
            return CGRectIntersectsRect(rect, [evaluatedObject frame]);
        }]]];
    }
    
    return attributes;
}

- (BOOL)shouldInvalidateLayoutForBoundsChange:(CGRect)newBounds
{
    return YES;
}

- (UICollectionViewLayoutInvalidationContext *)invalidationContextForBoundsChange:(CGRect)newBounds
{
    UICollectionViewLayoutInvalidationContext *context = [super invalidationContextForBoundsChange:newBounds];
    
    //NOTE: selective invalidation makes scrolling more responsive, but sticky cells feel choppy
    //Smoothness is less performant, but looks better with a smaller number of cells
    if (speedOverSmotheness)
    {
        NSArray *stickyIndexPaths = [_stickyAttributes valueForKeyPath:@"indexPath"];
        [context invalidateItemsAtIndexPaths:stickyIndexPaths];
    }
    
    return context;
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
    
    if (firstColumnSticky && attributes.indexPath.section == 0)
    {
        if (![_stickyAttributes containsObject:attributes])
        {
            [_stickyAttributes addObject:attributes];
        }
        
        attributes.zIndex = NSIntegerMax - 1;

        if (self.collectionView.contentOffset.x > 0 || stickyOverscroll)
        {
            CGRect frame = attributes.frame;
            frame.origin.x = self.collectionView.contentOffset.x;
            attributes.frame = frame;
        }
    }
    
    if (firstRowSticky && attributes.indexPath.row == 0)
    {
        if (![_stickyAttributes containsObject:attributes])
        {
            [_stickyAttributes addObject:attributes];
        }
        
        attributes.zIndex = NSIntegerMax - 1;
        
        if (self.collectionView.contentOffset.y > 0 || stickyOverscroll)
        {
            CGRect frame = attributes.frame;
            frame.origin.y = self.collectionView.contentOffset.y;
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
    if (sender.state == UIGestureRecognizerStateChanged)
    {
        return;
    }
    
    switch (sender.state)
    {
        case UIGestureRecognizerStateBegan:
        {
            
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
            UICollectionViewLayoutAttributes *layoutAttributes = [self.collectionView layoutAttributesForItemAtIndexPath:indexPath];

            [UIView
             animateWithDuration:0.2
             animations:^{
                 _liftedItemImage.center = layoutAttributes.center;
                 _liftedItemImage.transform = CGAffineTransformMakeScale(1.f, 1.f);
             }
             completion:^(BOOL finished){
                 [_liftedItemImage removeFromSuperview];
                 _liftedItemImage = nil;
                 _liftedItemIndexPath = nil;
//                 [self.collectionView.collectionViewLayout invalidateLayout];
                 [self resetOverscroll];
             }];
            
        } break;
        default: break;
    }
}

- (void)resetOverscroll
{
    CGRect bounds = self.collectionView.bounds;
    CGSize contentSize = self.collectionView.contentSize;
    CGFloat rightEdge = bounds.origin.x + bounds.size.width;
    CGFloat bottomEdge = bounds.origin.y + bounds.size.height;

    BOOL overscrolled = NO;
    
    if (bounds.origin.x < 0)
    {
        overscrolled = YES;
        bounds.origin.x = 0;
    }
    
    if (bounds.origin.y < 0)
    {
        overscrolled = YES;
        bounds.origin.y = 0;
    }
    
    if (rightEdge > contentSize.width)
    {
        overscrolled = YES;
        bounds.origin.x -= rightEdge - contentSize.width;
    }
    
    if (bottomEdge > contentSize.height)
    {
        overscrolled = YES;
        bounds.origin.y -= bottomEdge - contentSize.height;
    }
    
    if (overscrolled)
    {
        [self.collectionView scrollRectToVisible:bounds animated:YES];
    }
}

- (NSIndexPath *)indexPathForItemClosestToPoint:(CGPoint)point
{
    NSArray *layoutAttributes;
    NSInteger closestDist = NSIntegerMax;
    NSIndexPath *indexPath;
    
    // We need original positions of cells
    layoutAttributes = [self.collectionView.collectionViewLayout layoutAttributesForElementsInRect:self.collectionView.bounds];
    
    // Find closest cell
    for (UICollectionViewLayoutAttributes *layoutAttr in layoutAttributes)
    {
        CGFloat xd = layoutAttr.center.x - point.x;
        CGFloat yd = layoutAttr.center.y - point.y;
        NSInteger dist = sqrtf(xd*xd + yd*yd);
        if (dist < closestDist)
        {
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

- (void)handlePanGesture:(UIPanGestureRecognizer *)sender
{
    switch (sender.state)
    {
        case UIGestureRecognizerStateBegan:
        {
            [self beginDragScrollTimer];
        }
            break;
            
        case UIGestureRecognizerStateChanged:
        {
            _touchTranslation = [sender translationInView:self.collectionView];
            _liftedItemImage.center = pointAplusB(_liftedItemCenter, _touchTranslation);
            
            CGPoint touchPosition = [sender locationInView:self.collectionView];
            CGPoint contentOffset = self.collectionView.contentOffset;
            
            //Get absolute screen position
            touchPosition = pointAminusB(touchPosition, contentOffset);
            _dragScrollSpeed = CGPointZero;
            
            // Determine Scrolling
            if (touchPosition.x < dragScrollBorder.left)
            {
                CGFloat distance_X = dragScrollBorder.left - touchPosition.x;
                _dragScrollSpeed.x = -speedProportionalToDistance(maxScrollSpeed.x, distance_X, dragScrollBorder.left);
            }
            else if (touchPosition.x > self.collectionView.frame.size.width - dragScrollBorder.right)
            {
                CGFloat borderPoint = self.collectionView.frame.size.width - dragScrollBorder.right;
                CGFloat distance_X = touchPosition.x - borderPoint;
                _dragScrollSpeed.x = speedProportionalToDistance(maxScrollSpeed.x, distance_X, dragScrollBorder.right);
            }
            
            if (touchPosition.y < dragScrollBorder.top)
            {
                CGFloat distance_Y = dragScrollBorder.top - touchPosition.y;
                _dragScrollSpeed.y = -speedProportionalToDistance(maxScrollSpeed.y, distance_Y, dragScrollBorder.top);
            }
            else if (touchPosition.y > self.collectionView.frame.size.height - dragScrollBorder.bottom)
            {
                CGFloat borderPoint = self.collectionView.frame.size.height - dragScrollBorder.bottom;
                CGFloat distance_Y = touchPosition.y - borderPoint;
                _dragScrollSpeed.y = speedProportionalToDistance(maxScrollSpeed.y, distance_Y, dragScrollBorder.bottom);
            }
        }
            break;
        case UIGestureRecognizerStateCancelled:
            break;
        case UIGestureRecognizerStateEnded:
            [self endDragScrollTimer];
            _touchTranslation = CGPointZero;
            break;
        case UIGestureRecognizerStateFailed:
            [self endDragScrollTimer];
            _touchTranslation = CGPointZero;
            break;
        default:
            break;
    }
}

- (void)beginDragScrollTimer
{
    if (_scrollTimer == nil) {
        _scrollTimer = [CADisplayLink displayLinkWithTarget:self selector:@selector(scrollByTimer)];
        [_scrollTimer addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
    }
}

- (void)endDragScrollTimer
{
    if (_scrollTimer != nil) {
        [_scrollTimer invalidate];
        _scrollTimer = nil;
    }
}

- (void)scrollByTimer
{
    CGPoint initialContentOffset = self.collectionView.contentOffset;
    CGSize contentSize = self.collectionView.contentSize;
    CGRect bounds = self.collectionView.bounds;
    
    CGFloat overscroll_X = 0.f;
    CGFloat overscroll_Y = 0.f;
    
    //Taper scroll speed when scrolling goes out of bounds
    if (initialContentOffset.x < 0 && _dragScrollSpeed.x < 0)
    {
        overscroll_X = -initialContentOffset.x;
    }
    else if (initialContentOffset.x + bounds.size.width > contentSize.width && _dragScrollSpeed.x > 0)
    {
        overscroll_X = (initialContentOffset.x + bounds.size.width) - contentSize.width;
    }
    
    if (initialContentOffset.y < 0 && _dragScrollSpeed.y < 0)
    {
        overscroll_Y = -initialContentOffset.y;
    }
    else if (initialContentOffset.y + bounds.size.height > contentSize.height && _dragScrollSpeed.y > 0)
    {
        overscroll_Y = (initialContentOffset.y + bounds.size.height) - contentSize.height;
    }

    CGFloat factoredSpeed_X = _dragScrollSpeed.x * factorByOverscroll(overscroll_X, maxOverscroll.x) /60;
    CGFloat factoredSpeed_Y = _dragScrollSpeed.y * factorByOverscroll(overscroll_Y, maxOverscroll.y) /60;
    CGPoint distanceToScroll = CGPointMake(factoredSpeed_X , factoredSpeed_Y );
    
    //Scroll calculated distance (fractional amounts will be ingnored by the scrollView)
    self.collectionView.contentOffset = pointAplusB(initialContentOffset, distanceToScroll);
    
    //Check actual amount scrolled
    CGPoint actualScrolledDistance = CGPointMake(self.collectionView.contentOffset.x - initialContentOffset.x,
                                                 self.collectionView.contentOffset.y - initialContentOffset.y);
    
    //Adjust lifted item position to stay in sync
    _liftedItemCenter = pointAplusB(_liftedItemCenter, actualScrolledDistance);
    _liftedItemImage.center = pointAplusB(_liftedItemCenter, _touchTranslation);
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

#pragma Handle Interruptions

- (void)dealloc
{
    [self endDragScrollTimer];
}

@end
