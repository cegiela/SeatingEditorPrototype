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
//@property (nonatomic, strong) UIImageView *liftedItemImage;
@property (nonatomic, assign) CGPoint longPressLocation;
@property (nonatomic, assign) CGPoint liftedItemCenter;
@property (nonatomic, assign) CGPoint touchTranslation;

@property (nonatomic, assign) CGSize totalLayoutSize;
@property (nonatomic, strong) CADisplayLink *scrollTimer;
@property (nonatomic, assign) CGPoint dragScrollSpeed;
@property (nonatomic, assign) BOOL dragAndDropEnabled;

@end

static const CGPoint maxScrollSpeed = {10.f, 10.f};
static const CGPoint maxOverscroll = {30.f, 30.f};
static const UIEdgeInsets maxPanSpeed = {10000.f, 10000.f, 500.f, 10000.f};
static const CGFloat verticalOffset = 0.20f;
static const UIEdgeInsets dragScrollBorder = {60.f, 60.f, 60.f, 60.f};
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
    return MIN(result, 1);
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
            _longPressLocation = [sender locationInView:self.collectionView];
            
            //Check if gesture is native to this collection view
            if (sender == self.longPressGestureRecognizer)
            {
                _liftedItemIndexPath = [self indexPathForItemClosestToPoint:_longPressLocation];
            }
            else
            {
                _liftedItemIndexPath = [NSIndexPath indexPathForItem:NSIntegerMax inSection:NSIntegerMax];
                
//                UIView *mockView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
//                mockView.backgroundColor = [UIColor redColor];
//                [self.collectionView addSubview:mockView];
//                mockView.center = _liftedItemCenter;
            }
            
            [self beginDragAndDrop];
        } break;
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
            [self endDragAndDrop];
            break;
        default: break;
    }
}

- (void)beginDragAndDrop
{
    if (_liftedItemIndexPath.section == NSIntegerMax)
    {
        //Ask delegate for a lifted item image
        _liftedItemImage = [self.delegate collectionView:self.collectionView liftedItemImageForLayout:self];
        _liftedItemCenter = [self.delegate collectionView:self.collectionView liftedItemPositionForLayout:self];
    }
    else
    {
        // Create a lifted image to drag
        UICollectionViewCell *cell = [self.collectionView cellForItemAtIndexPath:_liftedItemIndexPath];
        cell.highlighted = NO;
        //    [_liftedItemImage removeFromSuperview];
        _liftedItemImage = [[UIImageView alloc] initWithFrame:cell.frame];
        _liftedItemImage.image = [self imageFromCell:cell];
        _liftedItemCenter = _liftedItemImage.center;
//        _liftedItemIndexPath = indexPath;
        
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
    }
}

- (void)endDragAndDrop
{
    if (_liftedItemIndexPath == nil)
    {
        return;
    }
    
    //Check if the lifted item originated in this collectionView
    if (_liftedItemIndexPath.section == NSIntegerMax)
    {
        //Switch adopted liftedItemImage to this collectionView for landing animation
        [_liftedItemImage removeFromSuperview];
        [self.collectionView addSubview:_liftedItemImage];
//        _liftedItemCenter = [self.delegate collectionView:self.collectionView liftedItemPositionForLayout:self];
//        _liftedItemImage.center = _liftedItemCenter;
        _liftedItemImage.center = pointAplusB(_liftedItemCenter, _touchTranslation);
        
    }
    
    //Prevent the following running twice
    _liftedItemIndexPath = nil;
    
    [self endDragScrollTimer];
    _touchTranslation = CGPointZero;
    _dragScrollSpeed.x = 0;
    _dragScrollSpeed.y = 0;
    
    //Land lifted image
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
         [self resetOverscroll];
     }];

    //                 [self.collectionView.collectionViewLayout invalidateLayout];
}

- (void)resetOverscroll
{
    CGRect bounds = self.collectionView.bounds;
    CGPoint offset = self.collectionView.contentOffset;
    UIEdgeInsets insets = self.collectionView.contentInset;
    CGSize contentSize = self.collectionView.contentSize;
    CGFloat rightEdge = offset.x + bounds.size.width;
    CGFloat bottomEdge = offset.y + bounds.size.height + insets.bottom;

    contentSize.height += insets.top + insets.bottom;
    contentSize.width += insets.left + insets.right;

    BOOL overscrolled = NO;
    
    if (offset.x < 0)
    {
        overscrolled = YES;
        offset.x = 0 - insets.left;
    }
    else if (rightEdge > contentSize.width)
    {
        overscrolled = YES;
        offset.x = contentSize.width - bounds.size.width;
    }

    if (offset.y < 0)
    {
        overscrolled = YES;
        offset.y = 0 - insets.top;
    }
    else if (bottomEdge > contentSize.height)
    {
        overscrolled = YES;
        offset.y = contentSize.height - bounds.size.height;
    }
    
    if (overscrolled)
    {
        [self.collectionView setContentOffset:offset animated:YES];
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

- (void)handlePanGesture:(UIPanGestureRecognizer *)sender
{
    static BOOL scrollZoneOrigin_X;
    static BOOL scrollZoneOrigin_Y;
    
    CGPoint touchPosition = [sender locationInView:self.collectionView];
    CGPoint contentOffset = self.collectionView.contentOffset;
    UIEdgeInsets insets = self.collectionView.contentInset;
    
    //Get absolute screen position
    touchPosition = pointAminusB(touchPosition, contentOffset);

    switch (sender.state)
    {
        case UIGestureRecognizerStateBegan:
        {
//            if (_liftedItemIndexPath == nil)
//            {
//                
//            }
            
            [self beginDragScrollTimer];
            
            //Prevent scrolling if touch began outside of the scroll borders
            if (touchPosition.x < dragScrollBorder.left ||
                touchPosition.x > self.collectionView.frame.size.width - dragScrollBorder.right)
            {
                scrollZoneOrigin_X = YES;
            }
            if (touchPosition.y < dragScrollBorder.top ||
                touchPosition.y > self.collectionView.frame.size.height - dragScrollBorder.bottom)
            {
                scrollZoneOrigin_Y = YES;
            }
        }
            break;
            
        case UIGestureRecognizerStateChanged:
        {
            _touchTranslation = [sender translationInView:self.collectionView];

            if (sender == self.panGestureRecognizer)
            {
                _liftedItemImage.center = pointAplusB(_liftedItemCenter, _touchTranslation);
            }
            
            _dragScrollSpeed = CGPointZero;
            
            CGFloat leftThreshold = dragScrollBorder.left + insets.left;
            CGFloat rightThreshold = self.collectionView.frame.size.width - dragScrollBorder.right - insets.right;
            CGFloat topThreshold = dragScrollBorder.top + insets.top;
            CGFloat bottomThreshold = self.collectionView.frame.size.height - dragScrollBorder.bottom - insets.bottom;

            //Determine scrolling Speed
            
            //Left
            if (touchPosition.x < leftThreshold)
            {
                if (scrollZoneOrigin_X == NO && touchPosition.x > leftThreshold - dragScrollBorder.left)
                {
                    CGFloat distance_X = leftThreshold - touchPosition.x ;
                    _dragScrollSpeed.x = -speedProportionalToDistance(maxScrollSpeed.x, distance_X, dragScrollBorder.left);
                }
            }
            //Right
            else if (touchPosition.x > rightThreshold)
            {
                if (scrollZoneOrigin_X == NO && touchPosition.x < bottomThreshold + dragScrollBorder.right)
                {
                    CGFloat borderPoint = rightThreshold;
                    CGFloat distance_X = touchPosition.x - borderPoint;
                    _dragScrollSpeed.x = speedProportionalToDistance(maxScrollSpeed.x, distance_X, dragScrollBorder.right);
                }
            }
            else
            {
                scrollZoneOrigin_X = NO;
            }
            
            //Top
            if (touchPosition.y < topThreshold)
            {
                if (scrollZoneOrigin_Y == NO && touchPosition.y > topThreshold - dragScrollBorder.top)
                {
                    CGFloat distance_Y = topThreshold - touchPosition.y;
                    _dragScrollSpeed.y = -speedProportionalToDistance(maxScrollSpeed.y, distance_Y, dragScrollBorder.top);
                }
            }
            //Bottom
            else if (touchPosition.y > bottomThreshold)
            {
                if (scrollZoneOrigin_Y == NO && touchPosition.y < bottomThreshold + dragScrollBorder.bottom)
                {
                    CGFloat borderPoint = bottomThreshold;
                    CGFloat distance_Y = touchPosition.y - borderPoint;
                    _dragScrollSpeed.y = speedProportionalToDistance(maxScrollSpeed.y, distance_Y, dragScrollBorder.bottom);
                }
            }
            else
            {
                scrollZoneOrigin_Y = NO;
            }
            
            //Restrict scrolling due to touch originating inside a scroll border
            if (scrollZoneOrigin_X)
            {
                _dragScrollSpeed.x = 0;
            }
            if (scrollZoneOrigin_Y)
            {
                _dragScrollSpeed.y = 0;
            }
            
            //NOTE: When the touch velocity is higher,
            //we can assume the user is dragging out of this collection view.
            //We can forgo border scrolling to make a smother experience.
            //Cancel scrolling if touch is travelling at high speed.
            if ([sender velocityInView:self.collectionView].x > maxPanSpeed.right ||
                [sender velocityInView:self.collectionView].x < -maxPanSpeed.left)
            {
                _dragScrollSpeed.x = 0;
            }
            if ([sender velocityInView:self.collectionView].y > maxPanSpeed.bottom ||
                [sender velocityInView:self.collectionView].y < -maxPanSpeed.top)
            {
                _dragScrollSpeed.y = 0;
            }
        }
            break;
        case UIGestureRecognizerStateCancelled:
//            break;
        case UIGestureRecognizerStateEnded:
//            [self endDragScrollTimer];
//            _touchTranslation = CGPointZero;
//            break;
        case UIGestureRecognizerStateFailed:
            [self endDragAndDrop];
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
    //Check if scrolling is allowed (defaults to YES)
    if ([self.delegate respondsToSelector:@selector(collectionView:scrollDuringDraggingInLayout:)]
        && [self.delegate collectionView:self.collectionView scrollDuringDraggingInLayout:self] == NO)
    {
        return;
    }
    
    //NOTE: Currently overscroll is acomplished by dampening the scroll speed when beyond bounds
    //It may be better to have it proportional to touch proximity to edge of screen

    CGPoint initialContentOffset = self.collectionView.contentOffset;
    CGSize contentSize = self.collectionView.contentSize;
    CGRect bounds = self.collectionView.bounds;
    UIEdgeInsets insets = self.collectionView.contentInset;
    
    contentSize.height += insets.top + insets.bottom;
    contentSize.width += insets.left + insets.right;
    
    CGFloat overscroll_X = 0.f;
    CGFloat overscroll_Y = 0.f;
    
    //Check if we're out of bounds
    
    if (initialContentOffset.x < 0 && _dragScrollSpeed.x < 0)
    {
        overscroll_X = -initialContentOffset.x;
    }
    
    if (initialContentOffset.x + bounds.size.width > contentSize.width && _dragScrollSpeed.x > 0)
    {
        overscroll_X = (initialContentOffset.x + bounds.size.width) - contentSize.width;
    }
    
    if (initialContentOffset.y < 0 && _dragScrollSpeed.y < 0)
    {
        overscroll_Y = -initialContentOffset.y;
    }
    else if (initialContentOffset.y + bounds.size.height >
             contentSize.height && _dragScrollSpeed.y > 0)
    {
        overscroll_Y = (initialContentOffset.y + bounds.size.height) - contentSize.height;
    }
    
    //Factor speed by distance out of bounds, slowing to a stop as it gets to maxOverscroll
    CGFloat factoredSpeed_X = _dragScrollSpeed.x * factorByOverscroll(overscroll_X, maxOverscroll.x);
    CGFloat factoredSpeed_Y = _dragScrollSpeed.y * factorByOverscroll(overscroll_Y, maxOverscroll.y);
    
    //Calculate distance
    CGPoint distanceToScroll = CGPointMake(factoredSpeed_X, factoredSpeed_Y);
    CGPoint newOffset = pointAplusB(initialContentOffset, distanceToScroll);
    
    //Scroll calculated distance
    self.collectionView.contentOffset = newOffset;
    
    //Check actual amount scrolled (fractional amounts will be ingnored by the scrollView)
    CGPoint actualScrolledDistance = CGPointMake(self.collectionView.contentOffset.x - initialContentOffset.x, self.collectionView.contentOffset.y - initialContentOffset.y);
    
    _liftedItemCenter = pointAplusB(_liftedItemCenter, actualScrolledDistance);

    //Check if lifted item originated from this collectionView
    if (_liftedItemIndexPath.section != NSIntegerMax)
    {
        //Adjust lifted item position to stay in sync
        _liftedItemImage.center = pointAplusB(_liftedItemCenter, _touchTranslation);
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

#pragma Handle Interruptions

- (void)dealloc
{
    [self endDragScrollTimer];
}

@end
