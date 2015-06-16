//
//  CNStudent.m
//  Skedula
//
//  Created by Justin C. Beck on 3/23/14.
//  Copyright (c) 2014 CaseNEX. All rights reserved.
//

#import "CNStudent.h"
//#import "CNAPI.h"
//#import "CNStudentGrade.h"

@implementation CNStudent

- (id)initWithJSON:(NSDictionary *)json
{
    if (self = [super init])
    {
        _studentId = [json objectForKey:@"studentId"];
        _firstName = [json objectForKey:@"firstName"];
        _lastName = [json objectForKey:@"lastName"];
        _gender = [json objectForKey:@"gender"];
        _officialClass = [json objectForKey:@"officialClass"];
        _gradeLevel = [json objectForKey:@"gradeLevel"];
        _contacts = [NSMutableArray array];
        _anecdotals = [NSMutableArray array];
        _grades = [NSMutableArray array];
        _courseAttendance = [NSMutableDictionary dictionary];
        _dailyAttendance = [NSMutableDictionary dictionary];
        _courseSchedules = [NSMutableArray array];
    }
    
    return self;
}

@end
