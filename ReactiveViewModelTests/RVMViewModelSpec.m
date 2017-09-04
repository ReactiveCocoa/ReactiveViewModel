//
//  RVMViewModelSpec.m
//  ReactiveViewModel
//
//  Created by Josh Abernathy on 9/11/12.
//  Copyright (c) 2012 GitHub. All rights reserved.
//

@import Nimble;
@import Quick;
#import <ReactiveObjC/ReactiveObjC.h>
#import <ReactiveViewModel/ReactiveViewModel.h>

#import "RVMTestViewModel.h"

QuickSpecBegin(RVMViewModelSpec)

__block RVMTestViewModel *viewModel;

beforeEach(^{
	viewModel = [[RVMTestViewModel alloc] init];
});

describe(@"active property", ^{
	it(@"should default to NO", ^{
		expect(@(viewModel.active)).to(beFalsy());
	});

	it(@"should send on didBecomeActiveSignal when set to YES", ^{
		__block NSUInteger nextEvents = 0;
		[viewModel.didBecomeActiveSignal subscribeNext:^(RVMViewModel *viewModel) {
			expect(viewModel).to(beIdenticalTo(viewModel));
			expect(@(viewModel.active)).to(beTruthy());

			nextEvents++;
		}];

		expect(@(nextEvents)).to(equal(@0));

		viewModel.active = YES;
		expect(@(nextEvents)).to(equal(@1));

		// Indistinct changes should not trigger the signal again.
		viewModel.active = YES;
		expect(@(nextEvents)).to(equal(@1));

		viewModel.active = NO;
		viewModel.active = YES;
		expect(@(nextEvents)).to(equal(@2));
	});

	it(@"should send on didBecomeInactiveSignal when set to NO", ^{
		__block NSUInteger nextEvents = 0;
		[viewModel.didBecomeInactiveSignal subscribeNext:^(RVMViewModel *viewModel) {
			expect(viewModel).to(beIdenticalTo(viewModel));
			expect(@(viewModel.active)).to(beFalsy());

			nextEvents++;
		}];

		expect(@(nextEvents)).to(equal(@1));

		viewModel.active = YES;
		viewModel.active = NO;
		expect(@(nextEvents)).to(equal(@2));

		// Indistinct changes should not trigger the signal again.
		viewModel.active = NO;
		expect(@(nextEvents)).to(equal(@2));
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
				RVMTestViewModel *viewModel = [[RVMTestViewModel alloc] init];
				[viewModel.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
					deallocated = YES;
				}]];

				viewModel.active = YES;
				return viewModel;
			};
		});

		afterEach(^{
			expect(@(deallocated)).toEventually(beTruthy());
			expect(@(completed)).to(beTruthy());
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
				expect(values).to(equal(expectedValues));
				expect(@(completed)).to(beFalsy());

				viewModel.active = NO;

				expect(values).to(equal(expectedValues));
				expect(@(completed)).to(beFalsy());

				viewModel.active = YES;

				expectedValues = @[ @1, @2, @1, @2 ];
				expect(values).to(equal(expectedValues));
				expect(@(completed)).to(beFalsy());
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
				expect(values).to(equal(expectedValues));
				expect(@(completed)).to(beFalsy());

				[subject sendNext:@1];

				expectedValues = @[ @0, @1 ];
				expect(values).to(equal(expectedValues));
				expect(@(completed)).to(beFalsy());

				viewModel.active = NO;

				// Since the VM is inactive, these events should be throttled.
				[subject sendNext:@2];
				[subject sendNext:@3];

				expect(values).to(equal(expectedValues));
				expect(@(completed)).to(beFalsy());

				expectedValues = @[ @0, @1, @3 ];
				
				// FIXME: Nimble doesn't support custom timeouts right now, and
				// our operation may take longer than 1 second (the default
				// timeout), sooo... trololo
				[NSThread sleepForTimeInterval:1];
				
				expect(values).toEventually(equal(expectedValues));
				expect(@(completed)).to(beFalsy());

				// After reactivating, we should still get this event.
				[subject sendNext:@4];
				viewModel.active = YES;

				expectedValues = @[ @0, @1, @3, @4 ];
				expect(values).toEventually(equal(expectedValues));
				expect(@(completed)).to(beFalsy());

				// And now new events should be instant.
				[subject sendNext:@5];

				expectedValues = @[ @0, @1, @3, @4, @5 ];
				expect(values).to(equal(expectedValues));
				expect(@(completed)).to(beFalsy());

				[subject sendCompleted];

				expect(values).to(equal(expectedValues));
				expect(@(completed)).to(beTruthy());
			}
		});
	});
});

QuickSpecEnd
