//
//  CNStudent.h
//  Skedula
//
//  Created by Justin C. Beck on 3/23/14.
//  Copyright (c) 2014 CaseNEX. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface CNStudent : NSObject

@property (nonatomic, strong) NSString *courseId;
@property (nonatomic, strong) NSString *studentId;
@property (nonatomic, strong) NSString *firstName;
@property (nonatomic, strong) NSString *lastName;
@property (nonatomic, strong) NSString *gender;
@property (nonatomic, strong) NSString *officialClass;
@property (nonatomic, strong) NSString *gradeLevel;

@property (nonatomic, strong) UIImage *image;
@property (nonatomic, strong) UIImage *largeImage;
@property (nonatomic, strong) NSString *tempImageURL;

@property (nonatomic, strong) NSMutableArray *contacts;
@property (nonatomic, strong) NSMutableArray *anecdotals;

@property (nonatomic, strong) NSMutableDictionary *courseAttendance;
@property (nonatomic, strong) NSMutableDictionary *dailyAttendance;
@property (nonatomic, strong) NSMutableArray *courseSchedules;

@property (nonatomic, strong) NSMutableArray *grades;

@end
