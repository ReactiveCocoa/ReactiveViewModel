# ReactiveViewModel

ReactiveViewModel is a combination code/documentation project for building Cocoa
applications using [Model-View-ViewModel](#model-view-viewmodel) and
[ReactiveCocoa](#reactivecocoa).

By explaining rationale, documenting best practices, and providing reusable
library components, we want to make MVVM in Objective-C appealing and easy.

## Model-View-ViewModel

Most Cocoa developers are familiar with the
[Model-View-Controller](http://en.wikipedia.org/wiki/Model-View-Controller)
(MVC) pattern:

![Model-View-Controller](https://f.cloud.github.com/assets/432536/867983/280867ea-f760-11e2-9425-8d1345ffdfb9.png)

**[Model-View-ViewModel](http://en.wikipedia.org/wiki/Model-View-ViewModel)
(MVVM)** is another architectural paradigm for GUI applications:

![Model-View-ViewModel](https://f.cloud.github.com/assets/432536/867984/291ed380-f760-11e2-9106-d3158320af39.png)

Although it seems similar to MVC (except with a "view model" object in place of
the controller), there's one major difference — **the view owns the view
model**. Unlike a controller, a view model has no knowledge of the specific view
that's using it.

This seemingly minor change offers huge benefits:

 1. **View models are testable.** Since they don't need a view to do their work,
    presentation behavior can be tested without any UI automation or stubbing.
 1. **View models can be used like models.** If desired, view models can be
    copied or serialized just like a domain model. This can be used to quickly
    implement UI restoration and similar behaviors.
 1. **View models are (mostly) platform-agnostic.** Since the actual UI code
    lives in the view, well-designed view models can be used on the iPhone,
    iPad, and Mac, with only minor tweaking for each platform.
 1. **Views and view controllers are simpler.** Once the important logic is
    moved elsewhere, views and VCs become dumb UI objects. This makes them
    easier to understand and redesign.

In short, replacing MVC with MVVM can lead to more versatile and rigorous UI
code.

### What's in a view model?

A view model is like an [adapter](http://en.wikipedia.org/wiki/Adapter_pattern)
for the model that makes it suitable for presentation. The view model is also
where presentation _behavior_ goes.

For example, a view model might handle:

 * Kicking off network or database requests
 * Determining when information should be hidden or shown
 * Date and number formatting
 * Localization

However, the view model is not responsible for actually presenting
information or handling input — that's the sole domain of the view layer. When
the view model needs to communicate something to the view, it does so through
a system of [data binding](#reactivecocoa).

### What about view controllers?

OS X and iOS both have view (or window) controllers, which may be confusing at
first glance, since MVVM only refers to a view.

But upon closer inspection, it becomes apparent that view controllers are
_actually just part of the view layer_, since they handle things like:

 * Layout
 * Animations
 * Device rotation
 * View and window transitions
 * Presenting loaded UI

So, "the view" actually means the view _layer_, which includes view controllers.
There's no need to have a view and a view controller for the same section of the
screen, though — just pick whichever class is easier for the use case.

No matter whether you decide to use a view or a view controller, you'll still
have a view model.

## ReactiveCocoa

MVVM is most successful with a powerful system of [data
binding](http://en.wikipedia.org/wiki/UI_data_binding).
[ReactiveCocoa](https://github.com/ReactiveCocoa/ReactiveCocoa) is one such
system.

By modeling changes as
[signals](https://github.com/ReactiveCocoa/ReactiveCocoa#introduction), the view
model can communicate to the view without actually needing to know that it
exists (similarly for model → view model communication). This decoupling is
why view models can be tested without a view in place — the test simply needs to
connect to the VM's signals and verify that the behavior is correct.

ReactiveCocoa also includes other conveniences that are hugely beneficial for
MVVM, like
[commands](https://github.com/ReactiveCocoa/ReactiveCocoa/blob/master/Documentation/FrameworkOverview.md#commands),
and built-in bindings for AppKit and UIKit.

## Getting Started

To build ReactiveViewModel in isolation, open `ReactiveViewModel.xcworkspace`. To integrate it into your project, include `ReactiveViewModel.xcodeproj` and `ReactiveCocoa.xcodeproj` and link your target against the ReactiveViewModel and ReactiveCocoa targets for your platform.

## More Resources

Model-View-ViewModel was originally developed by
[Microsoft](http://bit.ly/gQY00r), so many of the examples are specific to WPF
or Silverlight, but there are still a few resources that may be useful:

**Blog posts:**

 * [Basic MVVM with ReactiveCocoa](http://cocoasamurai.blogspot.com/2013/03/basic-mvvm-with-reactivecocoa.html)
 * [Model-View-ViewModel for iOS](http://www.teehanlax.com/blog/model-view-viewmodel-for-ios/)
 * [Presentation Model](http://martinfowler.com/eaaDev/PresentationModel.html)

**Presentations:**

 * [Code Reuse with MVVM](https://speakerdeck.com/jspahrsummers/code-reuse-with-mvvm)
