//
//  RakamTests.m
//  Rakam
//
//  Created by Daniel Jih on 8/7/15.
//  Copyright (c) 2015 Rakam. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <UIKit/UIKit.h>
#import <OCMock/OCMock.h>
#import "Rakam.h"
#import "RakamConstants.h"
#import "Rakam+Test.h"
#import "BaseTestCase.h"
#import "RakamDeviceInfo.h"
#import "RakamARCMacros.h"
#import "RakamUtils.h"

// expose private methods for unit testing
@interface Rakam (Tests)
- (NSDictionary *)mergeEventsAndIdentifys:(NSMutableArray *)events identifys:(NSMutableArray *)identifys numEvents:(long)numEvents;

- (id)truncate:(id)obj;

- (long long)getNextSequenceNumber;
@end

@interface RakamTVOSTests : BaseTestCase

@end

@implementation RakamTVOSTests {
    id _connectionMock;
    int _connectionCallCount;
}

- (void)setUp {
    [super setUp];
    _connectionMock = [OCMockObject mockForClass:NSURLConnection.class];
    _connectionCallCount = 0;
    [self.rakam initializeApiKey:[NSURL URLWithString:@"http://127.0.0.1:9998"] :apiKey];
}

- (void)tearDown {
    [_connectionMock stopMocking];
}

- (void)setupAsyncResponse:(id)connectionMock response:(NSMutableDictionary *)serverResponse {
    [[[connectionMock expect] andDo:^(NSInvocation *invocation) {
        _connectionCallCount++;
        void (^handler)(NSURLResponse *, NSData *, NSError *);
        [invocation getArgument:&handler atIndex:4];
        handler(serverResponse[@"response"], serverResponse[@"data"], serverResponse[@"error"]);
    }] sendAsynchronousRequest:OCMOCK_ANY queue:OCMOCK_ANY completionHandler:OCMOCK_ANY];
}

- (void)testLogEventUploadLogic {
    NSMutableDictionary *serverResponse = [NSMutableDictionary dictionaryWithDictionary:
            @{@"response": [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"/"] statusCode:200 HTTPVersion:nil headerFields:@{}],
                    @"data": [@"bad_checksum" dataUsingEncoding:NSUTF8StringEncoding]
            }];
    [self setupAsyncResponse:_connectionMock response:serverResponse];

    // tv os should have upload event upload threshold set to 1
    XCTAssertEqual(kRKMEventUploadThreshold, 1);

    [self.rakam logEvent:@"test"];
    [self.rakam flushQueue];

    XCTAssertEqual(_connectionCallCount, 1);
    XCTAssertEqual([self.databaseHelper getEventCount], 1);  // upload failed due to bad checksum
}

- (void)testLogEventPlatformAndOSName {
    [self.rakam logEvent:@"test"];
    [self.rakam flushQueue];
    NSDictionary *event = [self.rakam getLastEvent];

    XCTAssertEqualObjects([event objectForKey:@"collection"], @"test");
    XCTAssertEqualObjects([event objectForKey:@"os_name"], @"tvos");
    XCTAssertEqualObjects([event objectForKey:@"platform"], @"tvOS");
}

@end
