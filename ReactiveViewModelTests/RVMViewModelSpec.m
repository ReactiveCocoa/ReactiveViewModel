//
//  RVMViewModelSpec.m
//  ReactiveViewModel
//
//  Created by Josh Abernathy on 9/11/12.
//  Copyright (c) 2012 GitHub. All rights reserved.
//

#import "RVMTestViewModel.h"

SpecBegin(RVMViewModel)

__block RVMTestViewModel *rootViewModel;
__block RVMTestViewModel *parentViewModel;
__block RVMTestViewModel *childViewModel;

beforeEach(^{
	rootViewModel = [[RVMTestViewModel alloc] initWithModel:@"root" parentViewModel:nil];
	parentViewModel = [[RVMTestViewModel alloc] initWithModel:@"parent" parentViewModel:rootViewModel];
	childViewModel = [[RVMTestViewModel alloc] initWithModel:@"child" parentViewModel:parentViewModel];
});

describe(@"-init", ^{
	it(@"should call -initWithModel:parentViewModel:", ^{
		RVMTestViewModel *viewModel = [[RVMTestViewModel alloc] init];
		expect(viewModel.calledInitWithModelParentViewModel).to.beTruthy();
	});
});

describe(@"the view model chain", ^{
	it(@"should know its parent view model", ^{
		expect(childViewModel.parentViewModel).to.equal(parentViewModel);
		expect(parentViewModel.parentViewModel).to.equal(rootViewModel);
		expect(rootViewModel.parentViewModel).to.beNil();
	});

	it(@"should know its root view model", ^{
		expect(childViewModel.rootViewModel).to.equal(rootViewModel);
		expect(parentViewModel.rootViewModel).to.equal(rootViewModel);
		expect(rootViewModel.rootViewModel).to.equal(rootViewModel);
	});
});

describe(@"-viewModelPassingTest:", ^{
	it(@"should start with the receiver", ^{
		id result = [childViewModel viewModelPassingTest:^(RVMViewModel *viewModel) {
			return YES;
		}];

		expect(result).to.equal(childViewModel);
	});

	it(@"should return the first view model for which the block returns YES", ^{
		id result = [childViewModel viewModelPassingTest:^(RVMViewModel *viewModel) {
			return [viewModel.model isEqual:@"parent"];
		}];

		expect(result).to.equal(parentViewModel);
	});

	it(@"should return nil when there are no passing view models", ^{
		id result = [childViewModel viewModelPassingTest:^(RVMViewModel *viewModel) {
			return [viewModel.model isEqual:@"nooooooooooope"];
		}];

		expect(result).to.beNil();
	});
});

describe(@"active property", ^{
	it(@"should default to NO", ^{
		expect(rootViewModel.active).to.beFalsy();
	});

	it(@"should send on didBecomeActiveSignal when set to YES", ^{
		__block NSUInteger nextEvents = 0;
		[rootViewModel.didBecomeActiveSignal subscribeNext:^(RVMViewModel *viewModel) {
			expect(viewModel).to.beIdenticalTo(rootViewModel);
			expect(viewModel.active).to.beTruthy();

			nextEvents++;
		}];

		expect(nextEvents).to.equal(0);

		rootViewModel.active = YES;
		expect(nextEvents).to.equal(1);

		// Indistinct changes should not trigger the signal again.
		rootViewModel.active = YES;
		expect(nextEvents).to.equal(1);

		rootViewModel.active = NO;
		rootViewModel.active = YES;
		expect(nextEvents).to.equal(2);
	});

	it(@"should send on didBecomeInactiveSignal when set to NO", ^{
		__block NSUInteger nextEvents = 0;
		[rootViewModel.didBecomeInactiveSignal subscribeNext:^(RVMViewModel *viewModel) {
			expect(viewModel).to.beIdenticalTo(rootViewModel);
			expect(viewModel.active).to.beFalsy();

			nextEvents++;
		}];

		expect(nextEvents).to.equal(1);

		rootViewModel.active = YES;
		rootViewModel.active = NO;
		expect(nextEvents).to.equal(2);

		// Indistinct changes should not trigger the signal again.
		rootViewModel.active = NO;
		expect(nextEvents).to.equal(2);
	});

	describe(@"signal manipulation", ^{
		__block NSMutableArray *values;
		__block NSArray *expectedValues;
		__block BOOL completed;
		__block BOOL deallocated;

		__block RVMTestViewModel * (^createViewModel)();

		beforeEach(^{
			values = [NSMutableArray array];
			expectedValues = @[];
			completed = NO;
			deallocated = NO;

			createViewModel = ^{
				RVMTestViewModel *viewModel = [[RVMTestViewModel alloc] initWithModel:nil parentViewModel:nil];
				[viewModel.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
					deallocated = YES;
				}]];

				viewModel.active = YES;
				return viewModel;
			};
		});

		afterEach(^{
			expect(deallocated).will.beTruthy();
			expect(completed).to.beTruthy();
		});

		it(@"should forward a signal", ^{
			@autoreleasepool {
				RVMTestViewModel *viewModel __attribute__((objc_precise_lifetime)) = createViewModel();

				RACSignal *input = [RACSignal createSignal:^ id (id<RACSubscriber> subscriber) {
					[subscriber sendNext:@1];
					[subscriber sendNext:@2];
					return nil;
				}];

				[[viewModel
					forwardSignalWhileActive:input]
					subscribeNext:^(NSNumber *x) {
						[values addObject:x];
					} completed:^{
						completed = YES;
					}];

				expectedValues = @[ @1, @2 ];
				expect(values).to.equal(expectedValues);
				expect(completed).to.beFalsy();

				viewModel.active = NO;

				expect(values).to.equal(expectedValues);
				expect(completed).to.beFalsy();

				viewModel.active = YES;

				expectedValues = @[ @1, @2, @1, @2 ];
				expect(values).to.equal(expectedValues);
				expect(completed).to.beFalsy();
			}
		});

		it(@"should throttle a signal", ^{
			@autoreleasepool {
				RVMTestViewModel *viewModel __attribute__((objc_precise_lifetime)) = createViewModel();
				RACSubject *subject = [RACSubject subject];

				[[viewModel
					throttleSignalWhileInactive:[subject startWith:@0]]
					subscribeNext:^(NSNumber *x) {
						[values addObject:x];
					} completed:^{
						completed = YES;
					}];

				expectedValues = @[ @0 ];
				expect(values).to.equal(expectedValues);
				expect(completed).to.beFalsy();

				[subject sendNext:@1];

				expectedValues = @[ @0, @1 ];
				expect(values).to.equal(expectedValues);
				expect(completed).to.beFalsy();

				viewModel.active = NO;

				// Since the VM is inactive, these events should be throttled.
				[subject sendNext:@2];
				[subject sendNext:@3];

				expect(values).to.equal(expectedValues);
				expect(completed).to.beFalsy();

				expectedValues = @[ @0, @1, @3 ];
				expect(values).will.equal(expectedValues);
				expect(completed).to.beFalsy();

				// After reactivating, we should still get this event.
				[subject sendNext:@4];
				viewModel.active = YES;

				expectedValues = @[ @0, @1, @3, @4 ];
				expect(values).will.equal(expectedValues);
				expect(completed).to.beFalsy();

				// And now new events should be instant.
				[subject sendNext:@5];

				expectedValues = @[ @0, @1, @3, @4, @5 ];
				expect(values).to.equal(expectedValues);
				expect(completed).to.beFalsy();

				[subject sendCompleted];

				expect(values).to.equal(expectedValues);
				expect(completed).to.beTruthy();
			}
		});
	});
});

SpecEnd
