//
//  TestCollectionViewController.m
//  SeatingEditorPrototype
//
//  Created by Mat Cegiela on 6/4/15.
//  Copyright (c) 2015 Mat Cegiela. All rights reserved.
//

#import "TestCollectionViewController.h"
#import "TestCollectionViewCell.h"
#import "UIColor+RandomColor.h"
#import "MCCollectionViewPositionalLayout.h"
#import "MCCollectionViewEditableFlowLayout.h"

@interface TestCollectionViewController ()
<MCCollectionViewDelegatePositionalLayout, MCCollectionViewDelegateEditableFlowLayout>

@property (weak, nonatomic) IBOutlet UICollectionView *mainCollectionView;
@property (weak, nonatomic) IBOutlet UICollectionView *trayCollectionView;

@property (nonatomic, strong) MCCollectionViewPositionalLayout *positionalLayout;
@property (nonatomic, strong) MCCollectionViewEditableFlowLayout *editableFlowLayout;
@property (nonatomic, strong) NSMutableDictionary *colors;

@end

@implementation TestCollectionViewController

static NSString * const reuseIdentifier = @"Cell";

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.colors = [NSMutableDictionary new];
    
    self.mainCollectionView.contentInset = UIEdgeInsetsMake(0.f, 0.f, 88.f, 0.f);
    
    [self.mainCollectionView registerNib:[UINib nibWithNibName:@"TestCollectionViewCell" bundle:nil] forCellWithReuseIdentifier:reuseIdentifier];
    
    [self.trayCollectionView registerNib:[UINib nibWithNibName:@"TestCollectionViewCell" bundle:nil] forCellWithReuseIdentifier:reuseIdentifier];
    
    self.trayCollectionView.backgroundColor = [UIColor clearColor];
    
    self.editableFlowLayout = (MCCollectionViewEditableFlowLayout*) self.trayCollectionView.collectionViewLayout;
    self.editableFlowLayout.delegate = self;
    self.editableFlowLayout.scrollDirection = UICollectionViewScrollDirectionHorizontal;

    self.positionalLayout = (MCCollectionViewPositionalLayout*) self.mainCollectionView.collectionViewLayout;
    self.positionalLayout.delegate = self;
}

#pragma mark <UICollectionViewDataSource>

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    return collectionView == self.mainCollectionView ? 16 : 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return collectionView == self.mainCollectionView ? 16 : 10;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    TestCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:reuseIdentifier forIndexPath:indexPath];
    
    // Configure the cell
    cell.testLabel.text = [NSString stringWithFormat:(@"%li.%li"), (long)indexPath.row, (long)indexPath.section];
    if (!self.colors[indexPath])
    {
        UIColor *color = [UIColor randomColor];
        cell.pieceView.backgroundColor = color;
        self.colors[indexPath] = color;
    }
    else
    {
        cell.pieceView.backgroundColor = self.colors[indexPath];
    }
    return cell;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    return CGSizeMake(80.0, 80.0);
}

- (MCCollectionViewLayoutStickyOptions)stickyOptionsForCollectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout
{
    return 0;// MCCollectionViewLayoutStickyFirstColumn | MCCollectionViewLayoutStickyFirstRow;
}

- (BOOL)collectionView:(UICollectionView *)collectionView enableDragAndDropInlayout:(UICollectionViewLayout *)collectionViewLayout
{
    return YES;
}

#pragma mark <UICollectionViewDelegate>

- (UIImageView*)collectionView:(UICollectionView *)collectionView liftedItemImageForLayout:(UICollectionViewLayout*)collectionViewLayout
{
    return self.editableFlowLayout.liftedItemImage;
}

- (CGPoint)collectionView:(UICollectionView *)collectionView liftedItemPositionForLayout:(UICollectionViewLayout*)collectionViewLayout
{
    //Translate position from one collectionView to the other
    CGPoint convertedPoint = [self.trayCollectionView convertPoint:self.editableFlowLayout.liftedItemCenter toView:self.mainCollectionView];
    return convertedPoint;
}

//- (void)collectionView:(UICollectionView *)collectionView beganPanGesture:(UIPanGestureRecognizer *)panGesture
//{
//    [self.positionalLayout handlePanGesture:panGesture];
//}

- (void)collectionView:(UICollectionView *)collectionView isTrackingGesture:(UIGestureRecognizer *)gesture
{
    if ([gesture isKindOfClass:[UIPanGestureRecognizer class]])
    {
        [self.positionalLayout handlePanGesture:(UIPanGestureRecognizer*)gesture];
    }
    else if ([gesture isKindOfClass:[UILongPressGestureRecognizer class]])
    {
        [self.positionalLayout handleLongPressGesture:(UILongPressGestureRecognizer*)gesture];
    }
}

//- (void)collectionView:(UICollectionView *)collectionView endedPanGesture:(UIPanGestureRecognizer *)panGesture
//{
//    [self.positionalLayout handlePanGesture:panGesture];
//}

/*
// Uncomment this method to specify if the specified item should be highlighted during tracking
- (BOOL)collectionView:(UICollectionView *)collectionView shouldHighlightItemAtIndexPath:(NSIndexPath *)indexPath {
	return YES;
}
*/

/*
// Uncomment this method to specify if the specified item should be selected
- (BOOL)collectionView:(UICollectionView *)collectionView shouldSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}
*/

/*
// Uncomment these methods to specify if an action menu should be displayed for the specified item, and react to actions performed on the item
- (BOOL)collectionView:(UICollectionView *)collectionView shouldShowMenuForItemAtIndexPath:(NSIndexPath *)indexPath {
	return NO;
}

- (BOOL)collectionView:(UICollectionView *)collectionView canPerformAction:(SEL)action forItemAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender {
	return NO;
}

- (void)collectionView:(UICollectionView *)collectionView performAction:(SEL)action forItemAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender {
	
}
*/

@end
