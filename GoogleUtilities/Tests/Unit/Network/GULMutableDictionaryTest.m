// Copyright 2018 Google
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

#import <XCTest/XCTest.h>

#import "GoogleUtilities/Network/Public/GoogleUtilities/GULMutableDictionary.h"

const static NSString *const kKey = @"testKey1";
const static NSString *const kValue = @"testValue1";
const static NSString *const kKey2 = @"testKey2";
const static NSString *const kValue2 = @"testValue2";

@interface GULMutableDictionaryTest : XCTestCase
@property(nonatomic) GULMutableDictionary *dictionary;
@end

@implementation GULMutableDictionaryTest

- (void)setUp {
  [super setUp];
  self.dictionary = [[GULMutableDictionary alloc] init];
}

- (void)tearDown {
  self.dictionary = nil;
  [super tearDown];
}

- (void)testSetGetAndRemove {
  XCTAssertNil([self.dictionary objectForKey:kKey]);
  [self.dictionary setObject:kValue forKey:kKey];
  XCTAssertEqual(kValue, [self.dictionary objectForKey:kKey]);
  [self.dictionary removeObjectForKey:kKey];
  XCTAssertNil([self.dictionary objectForKey:kKey]);
}

- (void)testSetGetAndRemoveKeyed {
  XCTAssertNil(self.dictionary[kKey]);
  self.dictionary[kKey] = kValue;
  XCTAssertEqual(kValue, self.dictionary[kKey]);
  [self.dictionary removeObjectForKey:kKey];
  XCTAssertNil(self.dictionary[kKey]);
}

- (void)testRemoveAll {
  XCTAssertNil(self.dictionary[kKey]);
  XCTAssertNil(self.dictionary[kKey2]);
  self.dictionary[kKey] = kValue;
  self.dictionary[kKey2] = kValue2;
  [self.dictionary removeAllObjects];
  XCTAssertNil(self.dictionary[kKey]);
  XCTAssertNil(self.dictionary[kKey2]);
}

- (void)testCount {
  XCTAssertEqual([self.dictionary count], 0);
  self.dictionary[kKey] = kValue;
  XCTAssertEqual([self.dictionary count], 1);
  self.dictionary[kKey2] = kValue2;
  XCTAssertEqual([self.dictionary count], 2);
  [self.dictionary removeAllObjects];
  XCTAssertEqual([self.dictionary count], 0);
}

- (void)testUnderlyingDictionary {
  XCTAssertEqual([self.dictionary count], 0);
  self.dictionary[kKey] = kValue;
  self.dictionary[kKey2] = kValue2;

  NSDictionary *dict = self.dictionary.dictionary;
  XCTAssertEqual([dict count], 2);
  XCTAssertEqual(dict[kKey], kValue);
  XCTAssertEqual(dict[kKey2], kValue2);
}

- (void)testDictionaryReturnsSnapshot {
  self.dictionary[kKey] = kValue;
  NSDictionary *snapshot = self.dictionary.dictionary;

  self.dictionary[kKey2] = kValue2;
  [self.dictionary removeObjectForKey:kKey];
  XCTAssertNil(self.dictionary[kKey]);
  XCTAssertEqual(self.dictionary[kKey2], kValue2);

  XCTAssertEqual([snapshot count], 1);
  XCTAssertEqual(snapshot[kKey], kValue);
}

- (void)testSetObjectForKeyCopiesKeyBeforeReturning {
  NSMutableString *key = [NSMutableString stringWithString:@"key"];
  [self.dictionary setObject:kValue forKey:key];

  [key appendString:@"Mutated"];

  XCTAssertEqual([self.dictionary count], 1);
  XCTAssertEqual(self.dictionary[@"key"], kValue);
  XCTAssertNil(self.dictionary[@"keyMutated"]);
}

- (void)testKeyedSetObjectCopiesKeyBeforeReturning {
  NSMutableString *key = [NSMutableString stringWithString:@"key"];
  self.dictionary[key] = kValue;

  [key appendString:@"Mutated"];

  XCTAssertEqual([self.dictionary count], 1);
  XCTAssertEqual(self.dictionary[@"key"], kValue);
  XCTAssertNil(self.dictionary[@"keyMutated"]);
}

- (void)testRemoveMissingKey {
  self.dictionary[kKey] = kValue;
  [self.dictionary removeObjectForKey:kKey2];
  XCTAssertEqual([self.dictionary count], 1);
  XCTAssertEqual(self.dictionary[kKey], kValue);
}

- (void)testRemoveAllWhenEmpty {
  XCTAssertEqual([self.dictionary count], 0);
  [self.dictionary removeAllObjects];
  XCTAssertEqual([self.dictionary count], 0);
}

- (void)testDescription {
  self.dictionary[kKey] = kValue;
  NSString *description = [self.dictionary description];
  XCTAssertNotNil(description);
  XCTAssertTrue([description containsString:(NSString *)kKey]);
}

- (void)testSetObjectForNilKeyIsIgnored {
  id nilKey = nil;
  self.dictionary[kKey] = kValue;
  [self.dictionary setObject:kValue2 forKey:nilKey];

  NSDictionary *dict = self.dictionary.dictionary;
  XCTAssertEqual([dict count], 1);
  XCTAssertEqual(dict[kKey], kValue);
}

- (void)testKeyedSetObjectForNilKeyIsIgnored {
  id nilKey = nil;
  self.dictionary[kKey] = kValue;
  self.dictionary[nilKey] = kValue2;

  NSDictionary *dict = self.dictionary.dictionary;
  XCTAssertEqual([dict count], 1);
  XCTAssertEqual(dict[kKey], kValue);
}

- (void)testKeyedSetNilObjectForNilKeyIsIgnored {
  id nilKey = nil;
  id nilObj = nil;
  self.dictionary[kKey] = kValue;
  self.dictionary[nilKey] = nilObj;

  NSDictionary *dict = self.dictionary.dictionary;
  XCTAssertEqual([dict count], 1);
  XCTAssertEqual(dict[kKey], kValue);
}

- (void)testRemoveObjectForNilKeyIsIgnored {
  id nilKey = nil;
  self.dictionary[kKey] = kValue;
  [self.dictionary removeObjectForKey:nilKey];

  NSDictionary *dict = self.dictionary.dictionary;
  XCTAssertEqual([dict count], 1);
  XCTAssertEqual(dict[kKey], kValue);
}

- (void)testNilObjectIsIgnored {
  id nilObject = nil;
  self.dictionary[kKey] = kValue;

  // Unlike keyed subscripting, -setObject:forKey: with a nil object leaves the existing entry.
  [self.dictionary setObject:nilObject forKey:kKey];

  NSDictionary *dict = self.dictionary.dictionary;
  XCTAssertEqual([dict count], 1);
  XCTAssertEqual(dict[kKey], kValue);
}

- (void)testKeyedNilObjectRemovesKey {
  self.dictionary[kKey] = kValue;
  XCTAssertEqual(self.dictionary[kKey], kValue);
  // The object parameter is nullable, so no workaround is needed to pass nil.
  id nilObj = nil;
  self.dictionary[kKey] = nilObj;
  XCTAssertNil(self.dictionary[kKey]);
  XCTAssertEqual([self.dictionary count], 0);
}

- (void)testObjectForNilKey {
  id nilKey = nil;
  self.dictionary[kKey] = kValue;
  XCTAssertEqual([self.dictionary count], 1);
  XCTAssertNil([self.dictionary objectForKey:nilKey]);
}

- (void)testObjectForNilKeyedSubscript {
  id nilKey = nil;
  self.dictionary[kKey] = kValue;
  XCTAssertEqual([self.dictionary count], 1);
  XCTAssertNil([self.dictionary objectForKeyedSubscript:nilKey]);
}

- (void)testConcurrentAccess {
  GULMutableDictionary *dictionary = self.dictionary;
  id nilKey = nil;
  const size_t keyCount = 10;

  dispatch_apply(10000, DISPATCH_APPLY_AUTO, ^(size_t i) {
    NSString *key = [NSString stringWithFormat:@"key%zu", i % keyCount];
    NSNumber *value = @(i);

    dictionary[key] = value;
    [dictionary setObject:value forKey:key];
    (void)dictionary[key];
    (void)[dictionary objectForKey:key];

    dictionary[nilKey] = value;
    [dictionary setObject:value forKey:nilKey];
    [dictionary removeObjectForKey:nilKey];
    (void)dictionary[nilKey];
    (void)[dictionary objectForKey:nilKey];

    if (i % 7 == 0) {
      [dictionary removeObjectForKey:key];
    }
    if (i % 997 == 0) {
      [dictionary removeAllObjects];
    }

    (void)dictionary.count;
    (void)dictionary.dictionary;
    (void)dictionary.description;
  });

  NSDictionary *snapshot = dictionary.dictionary;
  XCTAssertEqual([snapshot count], [dictionary count]);
  XCTAssertLessThanOrEqual([snapshot count], keyCount);
  for (NSString *key in snapshot) {
    XCTAssertTrue([key hasPrefix:@"key"]);
    XCTAssertTrue([snapshot[key] isKindOfClass:[NSNumber class]]);
  }
}

@end
