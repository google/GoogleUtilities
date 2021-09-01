// Copyright 2018 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import <objc/runtime.h>

#import "GoogleUtilities/ISASwizzler/GULObjectSwizzler+Internal.h"
#import "GoogleUtilities/ISASwizzler/Public/GoogleUtilities/GULSwizzledObject.h"

NSString *kGULSwizzlerAssociatedObjectKey = @"gul_objectSwizzler";
static NSString *const kGULSwizzlerDeallocSEL = @"dealloc";

@interface GULSwizzledObject ()

@end

@implementation GULSwizzledObject

+ (void)copyDonorSelectorsUsingObjectSwizzler:(GULObjectSwizzler *)objectSwizzler {
  [objectSwizzler copySelector:@selector(gul_objectSwizzler) fromClass:self isClassSelector:NO];
  [objectSwizzler copySelector:@selector(gul_class) fromClass:self isClassSelector:NO];
  // ARC does not allow `@selector(dealloc)` so `NSSelectorFromString(@"dealloc")` is used instead.
  [objectSwizzler copySelector:NSSelectorFromString(kGULSwizzlerDeallocSEL)
                     fromClass:self
               isClassSelector:NO];
  // This is needed because NSProxy objects usually override -[NSObjectProtocol respondsToSelector:]
  // and ask this question to the underlying object. Since we don't swizzle the underlying object
  // but swizzle the proxy, when someone calls -[NSObjectProtocol respondsToSelector:] on the proxy,
  // the answer ends up being NO even if we added new methods to the subclass through ISA Swizzling.
  // To solve that, we override -[NSObjectProtocol respondsToSelector:] in such a way that takes
  // into account the fact that we've added new methods.
  if ([objectSwizzler isSwizzlingProxyObject]) {
    [objectSwizzler copySelector:@selector(respondsToSelector:) fromClass:self isClassSelector:NO];
  }
}

- (instancetype)init {
  NSAssert(NO, @"Do not instantiate this class, it's only a donor class");
  return nil;
}

- (GULObjectSwizzler *)gul_objectSwizzler {
  return [GULObjectSwizzler getAssociatedObject:self key:kGULSwizzlerAssociatedObjectKey];
}

#pragma mark - Donor methods

- (Class)gul_class {
  return [[self gul_objectSwizzler] generatedClass];
}

// Only added to a class when we detect it is a proxy.
- (BOOL)respondsToSelector:(SEL)aSelector {
  Class gulClass = [[self gul_objectSwizzler] generatedClass];
  return [gulClass instancesRespondToSelector:aSelector] || [super respondsToSelector:aSelector];
}

- (void)dealloc {
  // The goal of this `dealloc` is to switch the swizzled object's class to
  // the original object's class before complete deallocation.
  //
  // Additional Context:
  //
  // - Problem
  //   When the Zombies instrument is enabled, a zombie is created as a subclass
  //   of the deallocating object. In the case of a deallocated swizzled object,
  //   the zombie will subclass the swizzled object's generated class. This
  //   leads to a crash that occurs when the generated class is later disposed
  //   by the swizzler (see `dealloc` in `GULObjectSwizzler.m`).
  //
  //   This problem only occurs when the Zombies instrument is enabled
  //   for the above reasoning. See firebase-ios-sdk/issues/8321
  //
  // - Solution
  //   The solution is to switch the swizzled object's class to the original
  //   object's class before complete deallocation. This way, when the
  //   Zombies instrument is enabled, a zombie will be created using the
  //   original class. This allows `GULObjectSwizzler` to safely dispose its
  //   generated classes. This approach yields the following order of
  //   deallocation when a swizzled object's reference count goes to 0.
  //   - Order of deallocation:
  //     1. Swizzled object (generated class)
  //     2. Original object (original class) and its super classes
  //     3. Swizzler

  // Create a local autorelease pool to avoid retaining the swizzler past the
  // swizzled object's deallocation.
  //
  // Additional Context:
  //
  // - Without the local autorelease pool, a retain cycle is formed
  //   when `[self gul_class]` is called because the call strongly references
  //   the swizzler and the swizzler references the swizzled object.
  //   Note, although the swizzler has a `weak` reference to the
  //   swizzled object, this `weak` reference does not seem to work as intended
  //   when the logic is performed in `dealloc`.
  @autoreleasepool {
    // Retrieve the original class that the swizzler swizzled.
    Class originalClass = [[self gul_class] superclass];

    // In some cases, it is possible for the `originalClass` to be
    // nil (i.e. the swizzled object does not have not have a superclass).
    if (!originalClass) {
      return;
    }

    // Set the swizzled object's class to the original class.
    object_setClass(self, originalClass);

    // Note: `self` is now the original class.

    // If `self` is now a root class or an object inheriting from `NSProxy`, we
    // cannot call `dealloc` on it and should return now.
    //
    // Additional context:
    //
    // A root class is a class that does not have a superclass. Foundation has
    // two root classes: `NSObject` and `NSProxy`.
    BOOL classIsARootClass = ![self superclass] || [self isProxy];
    if (classIsARootClass) {
      return;
    }

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    // Call the original class's `dealloc` implementation.
    // ARC does not allow `@selector(dealloc)` so `NSSelectorFromString(@"dealloc")` is used
    // instead.
    [self performSelector:NSSelectorFromString(kGULSwizzlerDeallocSEL)];
#pragma clang diagnostic pop
  }
}

@end
