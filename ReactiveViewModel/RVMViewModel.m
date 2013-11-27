//
//  RVMViewModel.m
//  ReactiveViewModel
//
//  Created by Josh Abernathy on 9/11/12.
//  Copyright (c) 2012 GitHub. All rights reserved.
//

#import "RVMViewModel.h"
#import <libkern/OSAtomic.h>
#import <ReactiveCocoa/EXTScope.h>
#import <ReactiveCocoa/ReactiveCocoa.h>

// The number of seconds by which signal events are throttled when using
// -throttleSignalWhileInactive:.
static const NSTimeInterval RVMViewModelInactiveThrottleInterval = 1;

@interface RVMViewModel ()

// Improves the performance of KVO on the receiver.
//
// See the documentation for <NSKeyValueObserving> for more information.
@property (atomic) void *observationInfo;

@end

@implementation RVMViewModel

#pragma mark Properties

// We create many, many view models, so these properties need to be as lazy and
// memory-conscious as possible.
@synthesize didBecomeActiveSignal = _didBecomeActiveSignal;
@synthesize didBecomeInactiveSignal = _didBecomeInactiveSignal;

- (void)setActive:(BOOL)active {
	// Skip KVO notifications when the property hasn't actually changed. This is
	// especially important because self.active can have very expensive
	// observers attached.
	if (active == _active) return;

	[self willChangeValueForKey:@keypath(self.active)];
	_active = active;
	[self didChangeValueForKey:@keypath(self.active)];
}

- (RACSignal *)didBecomeActiveSignal {
	if (_didBecomeActiveSignal == nil) {
		@weakify(self);

		_didBecomeActiveSignal = [[[RACObserve(self, active)
			filter:^(NSNumber *active) {
				return active.boolValue;
			}]
			map:^(id _) {
				@strongify(self);
				return self;
			}]
			setNameWithFormat:@"%@ -didBecomeActiveSignal", self];
	}

	return _didBecomeActiveSignal;
}

- (RACSignal *)didBecomeInactiveSignal {
	if (_didBecomeInactiveSignal == nil) {
		@weakify(self);

		_didBecomeInactiveSignal = [[[RACObserve(self, active)
			filter:^ BOOL (NSNumber *active) {
				return !active.boolValue;
			}]
			map:^(id _) {
				@strongify(self);
				return self;
			}]
			setNameWithFormat:@"%@ -didBecomeInactiveSignal", self];
	}

	return _didBecomeInactiveSignal;
}

#pragma mark Activation

- (RACSignal *)forwardSignalWhileActive:(RACSignal *)signal {
	NSParameterAssert(signal != nil);

	RACSignal *activeSignal = RACObserve(self, active);

	return [[RACSignal
		createSignal:^(id<RACSubscriber> subscriber) {
			RACCompoundDisposable *disposable = [RACCompoundDisposable compoundDisposable];

			__block RACDisposable *signalDisposable = nil;

			RACDisposable *activeDisposable = [activeSignal subscribeNext:^(NSNumber *active) {
				if (active.boolValue) {
					signalDisposable = [signal subscribeNext:^(id value) {
						[subscriber sendNext:value];
					} error:^(NSError *error) {
						[subscriber sendError:error];
					}];

					if (signalDisposable != nil) [disposable addDisposable:signalDisposable];
				} else {
					[signalDisposable dispose];
					[disposable removeDisposable:signalDisposable];
					signalDisposable = nil;
				}
			} error:^(NSError *error) {
				[subscriber sendError:error];
			} completed:^{
				[subscriber sendCompleted];
			}];

			if (activeDisposable != nil) [disposable addDisposable:activeDisposable];
			return disposable;
		}]
		setNameWithFormat:@"%@ -forwardSignalWhileActive: %@", self, signal];
}

- (RACSignal *)throttleSignalWhileInactive:(RACSignal *)signal {
	NSParameterAssert(signal != nil);

	signal = [signal replayLast];

	return [[[[[RACObserve(self, active)
		takeUntil:[signal ignoreValues]]
		combineLatestWith:signal]
		throttle:RVMViewModelInactiveThrottleInterval valuesPassingTest:^ BOOL (RACTuple *xs) {
			BOOL active = [xs.first boolValue];
			return !active;
		}]
		reduceEach:^(NSNumber *active, id value) {
			return value;
		}]
		setNameWithFormat:@"%@ -throttleSignalWhileInactive: %@", self, signal];
}

#pragma mark NSKeyValueObserving

+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key {
	// We'll generate notifications for this property manually.
	if ([key isEqual:@keypath(RVMViewModel.new, active)]) {
		return NO;
	}

	return [super automaticallyNotifiesObserversForKey:key];
}

@end
