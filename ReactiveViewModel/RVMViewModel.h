//
//  RVMViewModel.h
//  ReactiveViewModel
//
//  Created by Josh Abernathy on 9/11/12.
//  Copyright (c) 2012 GitHub. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RVMViewModelReacting.h"

// Implements behaviors that drive the UI, and/or adapts a domain model to be
// user-presentable.
@interface RVMViewModel : NSObject <RVMViewModelReacting>

@end