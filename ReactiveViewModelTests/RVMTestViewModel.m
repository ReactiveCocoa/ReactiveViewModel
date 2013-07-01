//
//  RVMTestViewModel.m
//  ReactiveViewModel
//
//  Created by Josh Abernathy on 9/12/12.
//  Copyright (c) 2012 GitHub. All rights reserved.
//

#import "RVMTestViewModel.h"

@implementation RVMTestViewModel

#pragma mark RVMViewModel

- (id)initWithModel:(id)model parentViewModel:(RVMViewModel *)parentViewModel {
	self = [super initWithModel:model parentViewModel:parentViewModel];
	if (self == nil) return nil;

	_calledInitWithModelParentViewModel = YES;

	return self;
}

@end
