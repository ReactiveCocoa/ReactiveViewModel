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

#pragma mark Lifecycle

- (id)init {
	return [self initWithModel:nil];
}

- (id)initWithModel:(id)model {
	self = [super init];
	if (self == nil) return nil;

	_model = model;

	return self;
}

#pragma mark Activation

- (RACSignal *)forwardSignalWhileActive:(RACSignal *)signal {
	NSParameterAssert(signal != nil);

	RACSignal *activeSignal = RACObserve(self, active);

	return [[RACSignal
		create:^(id<RACSubscriber> subscriber) {
			RACSerialDisposable *signalDisposable = [[RACSerialDisposable alloc] init];
			[subscriber.disposable addDisposable:signalDisposable];

			RACDisposable *activeDisposable = [activeSignal subscribeNext:^(NSNumber *active) {
				if (active.boolValue) {
					signalDisposable.disposable = [signal subscribeNext:^(id value) {
						[subscriber sendNext:value];
					} error:^(NSError *error) {
						[subscriber sendError:error];
					}];
				} else {
					[[signalDisposable swapInDisposable:nil] dispose];
				}
			} error:^(NSError *error) {
				[subscriber sendError:error];
			} completed:^{
				[subscriber sendCompleted];
			}];

			[subscriber.disposable addDisposable:activeDisposable];
		}]
		setNameWithFormat:@"%@ -forwardSignalWhileActive: %@", self, signal];
}

- (RACSignal *)throttleSignalWhileInactive:(RACSignal *)signal {
	NSParameterAssert(signal != nil);

	return [[[[RACSignal
		combineLatest:@[
			// Materialize the input signals so that we can finish when either
			// of them finish. (Normally, `completed` events aren't observable
			// through +combineLatest: like this.)
			[RACObserve(self, active) materialize],
			[signal materialize]
		] reduce:^(RACEvent *activeEvent, RACEvent *signalEvent) {
			// Pass through termination events immediately.
			if (activeEvent.finished) return [RACSignal return:activeEvent];
			if (signalEvent.finished) return [RACSignal return:signalEvent];

			// If both are `next` events, forward the value from `signal`,
			// throttling it if we're inactive.
			NSNumber *active = activeEvent.value;
			RACSignal *result = [RACSignal return:signalEvent];
			if (!active.boolValue) {
				result = [result delay:RVMViewModelInactiveThrottleInterval];
			}

			return result;
		}]
		flatten:1 withPolicy:RACSignalFlattenPolicyDisposeEarliest]
		// Unpack the actual signal events.
		dematerialize]
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
