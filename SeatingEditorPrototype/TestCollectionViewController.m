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

@interface TestCollectionViewController () <MCCollectionViewDelegatePositionalLayout>

@property (nonatomic, strong) MCCollectionViewPositionalLayout *layout;
@property (nonatomic, strong) NSMutableDictionary *colors;

@end

@implementation TestCollectionViewController

static NSString * const reuseIdentifier = @"Cell";

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.colors = [NSMutableDictionary new];
    
    self.collectionView.contentInset = UIEdgeInsetsMake(0.f, 0.f, 88.f, 0.f);
    
    [self.collectionView registerNib:[UINib nibWithNibName:@"TestCollectionViewCell" bundle:nil] forCellWithReuseIdentifier:reuseIdentifier];
    
    self.layout = (MCCollectionViewPositionalLayout*) self.collectionView.collectionViewLayout;
    self.layout.delegate = self;
}

#pragma mark <UICollectionViewDataSource>

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    return 12;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return 12;
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
    return 0;//MCCollectionViewLayoutStickyFirstColumn | MCCollectionViewLayoutStickyFirstRow;
}

- (BOOL)collectionView:(UICollectionView *)collectionView enableDragAndDropInlayout:(UICollectionViewLayout *)collectionViewLayout
{
    return YES;
}

#pragma mark <UICollectionViewDelegate>

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
