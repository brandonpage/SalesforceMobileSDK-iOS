/*
 Copyright (c) 2025-present, salesforce.com, inc. All rights reserved.
 
 Redistribution and use of this software in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright notice, this list of conditions
 and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of
 conditions and the following disclaimer in the documentation and/or other materials provided
 with the distribution.
 * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
 endorse or promote products derived from this software without specific prior written
 permission of salesforce.com, inc.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
 FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
 CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
 WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <XCTest/XCTest.h>
#import <SalesforceSDKCore/SalesforceSDKCore.h>
#import "SFOAuthCoordinator+Internal.h"
#import "SFUserAccount+Internal.h"
#import "SFOAuthCredentials+Internal.h"
#import "SFSDKAuthSession.h"
#import "SFUserAccountManager+Internal.h"
#import "SFSDKAuthRequest.h"
#import "SFOAuthTestFlowCoordinatorDelegate.h"
#import "SFSDKAppFeatureMarkers.h"

@interface SFSDKAuthSession (SceneAssociationTesting)

- (BOOL)associateWithSceneIfUnscoped:(nullable UIScene *)scene;
- (void)captureStandardWebAuthIntentWithLoginHint:(nullable NSString *)loginHint
                               frontDoorBridgeUrl:(nullable NSURL *)frontDoorBridgeUrl
                                     codeVerifier:(nullable NSString *)codeVerifier;

@end

@interface SFUserAccountManager (SFOAuthCoordinatorContinuationTesting)

- (void)resetAuthentication:(SFSDKAuthSession *)authSession;
- (void)setAuthSession:(SFSDKAuthSession *)authSession forRoutingKey:(NSString *)routingKey;

@end

@interface SFSDKPresentationRecordingDelegate : SFOAuthTestFlowCoordinatorDelegate

@property (nonatomic, assign) NSUInteger browserPresentationCount;
@property (nonatomic, assign) NSUInteger webViewPresentationCount;

@end

@implementation SFSDKPresentationRecordingDelegate

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator
didBeginAuthenticationWithSession:(ASWebAuthenticationSession *)session {
    self.browserPresentationCount += 1;
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator
willBeginAuthenticationWithView:(WKWebView *)view {
    self.webViewPresentationCount += 1;
}

@end

@interface SFOAuthCoordinator (WebViewLoadingTesting)

- (void)loadWebViewWithUrlString:(NSString *)urlString cookie:(BOOL)enableCookie;

@end

@interface SFSDKCoordinatorTestSceneSession : NSObject

@property (nonatomic, copy) NSString *persistentIdentifier;

@end

@implementation SFSDKCoordinatorTestSceneSession
@end

@interface SFSDKCoordinatorTestScene : NSObject

@property (nonatomic, strong) SFSDKCoordinatorTestSceneSession *session;

@end

@implementation SFSDKCoordinatorTestScene
@end

@interface SFOAuthCoordinatorTests : XCTestCase

@end

@implementation SFOAuthCoordinatorTests

- (void)testMigrateRefreshTokenSetup {
    // Create test credentials
    SFOAuthCredentials *credentials = [[SFOAuthCredentials alloc] initWithIdentifier:@"testIdentifier" clientId:@"testClientId" encrypted:NO];
    credentials.redirectUri = @"testapp://callback";
    credentials.domain = @"test.salesforce.com";
    credentials.accessToken = @"testAccessToken";
    credentials.refreshToken = @"testRefreshToken";
    credentials.instanceUrl = [NSURL URLWithString:@"https://test.salesforce.com"];
    
    // Create a test user account (not fully logged in to avoid actual API calls)
    SFUserAccount *userAccount = [[SFUserAccount alloc] initWithCredentials:credentials];
    
    // Create auth request and session
    SFSDKAuthRequest *authRequest = [[SFSDKAuthRequest alloc] init];
    authRequest.oauthClientId = @"newClientId";
    authRequest.oauthCompletionUrl = @"newapp://callback";
    authRequest.loginHost = @"login.salesforce.com";
    
    SFSDKAuthSession *authSession = [[SFSDKAuthSession alloc] initWith:authRequest credentials:nil];
    
    // Track whether callbacks are invoked
    __block BOOL failureCallbackInvoked = NO;
    __block SFOAuthInfo *capturedAuthInfo = nil;
    __block NSError *capturedError = nil;
    
    authSession.authFailureCallback = ^(SFOAuthInfo *authInfo, NSError *error) {
        failureCallbackInvoked = YES;
        capturedAuthInfo = authInfo;
        capturedError = error;
    };
    
    // Create coordinator
    SFOAuthCoordinator *coordinator = [[SFOAuthCoordinator alloc] initWithAuthSession:authSession];
    coordinator.credentials = credentials;
    
    // Verify initial state
    XCTAssertNotNil(coordinator.credentials);
    XCTAssertEqualObjects(coordinator.credentials.clientId, @"testClientId");
    
    // Call migrateRefreshToken - this will attempt to make a REST API call
    // which will fail because the user is not properly logged in
    [coordinator migrateRefreshToken:userAccount];
    
    // Wait a bit for the async failure callback
    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for failure callback"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [expectation fulfill];
    });
    [self waitForExpectations:@[expectation] timeout:2.0];
    
    // Verify that the auth info was set to the correct type
    // This happens synchronously before the REST call
    XCTAssertNotNil(coordinator.authInfo, @"Auth info should be set");
    XCTAssertEqual(coordinator.authInfo.authType, SFOAuthTypeRefreshTokenMigration, @"Auth type should be refresh token migration");
    
    // Verify initialRequestLoaded was set to false
    XCTAssertFalse(coordinator.initialRequestLoaded, @"Initial request loaded should be false");
    
    // Verify the failure callback was invoked (because the user isn't logged in properly)
    XCTAssertTrue(failureCallbackInvoked, @"Failure callback should be invoked when REST API fails");
    XCTAssertNotNil(capturedError, @"Should have captured an error");
    XCTAssertEqual(capturedAuthInfo.authType, SFOAuthTypeRefreshTokenMigration, @"AuthInfo type should be refresh token migration");
}

// Must match kSFSDKAuthSessionUnscopedSceneIdPrefix in SFSDKAuthSession.m.
static NSString * const kExpectedUnscopedSceneIdPrefix = @"com.salesforce.mobilesdk.unscopedAuthSession-";

// A session created before any UIScene connects must still expose a non-nil sceneId, otherwise the
// advanced-auth browser callback crashes and the session is dropped from the authSessions store.
- (void)test_givenNoConnectedScene_whenAuthSessionCreated_thenSceneIdIsNonNilWithUnscopedPrefix {
    SFSDKAuthRequest *authRequest = [[SFSDKAuthRequest alloc] init];
    authRequest.oauthClientId = @"testClientId";
    authRequest.oauthCompletionUrl = @"testapp://callback";
    authRequest.loginHost = @"login.salesforce.com";
    XCTAssertNil(authRequest.scene, @"Precondition: no scene connected yet");

    SFSDKAuthSession *authSession = [[SFSDKAuthSession alloc] initWith:authRequest credentials:nil];

    XCTAssertNotNil(authSession.sceneId, @"sceneId must be non-nil so the advanced-auth callback options dictionary is safe to build and the session is stored under a valid key");
    XCTAssertTrue([authSession.sceneId hasPrefix:kExpectedUnscopedSceneIdPrefix], @"A scene-less session should get the synthesized unscoped scene id, got: %@", authSession.sceneId);
}

// Two scene-less sessions must get distinct sceneIds so they cannot collide on a single authSessions[]
// key, and each sceneId must be stable for the session's lifetime.
- (void)test_givenTwoNoSceneAuthSessions_whenCreated_thenSceneIdsAreDistinctAndStable {
    SFSDKAuthRequest *request1 = [[SFSDKAuthRequest alloc] init];
    request1.oauthClientId = @"testClientId";
    request1.oauthCompletionUrl = @"testapp://callback";
    request1.loginHost = @"login.salesforce.com";

    SFSDKAuthRequest *request2 = [[SFSDKAuthRequest alloc] init];
    request2.oauthClientId = @"testClientId";
    request2.oauthCompletionUrl = @"testapp://callback";
    request2.loginHost = @"login.salesforce.com";

    SFSDKAuthSession *session1 = [[SFSDKAuthSession alloc] initWith:request1 credentials:nil];
    SFSDKAuthSession *session2 = [[SFSDKAuthSession alloc] initWith:request2 credentials:nil];

    XCTAssertNotNil(session1.sceneId);
    XCTAssertNotNil(session2.sceneId);
    XCTAssertNotEqualObjects(session1.sceneId, session2.sceneId, @"Two scene-less sessions must get distinct scene ids so they cannot collide on a single authSessions[] key");
    // Frozen for the session's lifetime: reading again yields the same value.
    XCTAssertEqualObjects(session1.sceneId, session1.sceneId, @"sceneId must be stable for the session's lifetime");
}

// Helper to build a coordinator whose browser-callback options we can inspect.
- (SFOAuthCoordinator *)browserFlowCoordinator {
    SFSDKAuthRequest *authRequest = [[SFSDKAuthRequest alloc] init];
    authRequest.oauthClientId = @"testClientId";
    authRequest.oauthCompletionUrl = @"testapp://callback";
    authRequest.loginHost = @"login.salesforce.com";
    SFSDKAuthSession *authSession = [[SFSDKAuthSession alloc] initWith:authRequest credentials:nil];
    return [[SFOAuthCoordinator alloc] initWithAuthSession:authSession];
}

// When a scene is connected, the advanced-auth browser callback must key its options dictionary by
// the scene id so the URL handler routes the response to the originating scene.
- (void)test_givenSceneId_whenBuildingBrowserCallbackOptions_thenOptionsAreKeyedBySceneId {
    SFOAuthCoordinator *coordinator = [self browserFlowCoordinator];

    NSDictionary *options = [coordinator browserCallbackOptionsForSceneId:@"scene-42"];

    XCTAssertEqualObjects(options[kSFIDPSceneIdKey], @"scene-42", @"A non-nil sceneId must be carried under kSFIDPSceneIdKey so the callback routes to the originating scene");
    XCTAssertEqual(options.count, (NSUInteger)1, @"Only the scene id key should be present");
}

// When no scene id is available (e.g. login started before a UIScene connected, or the weak
// authSession deallocated before the callback), the options must be an empty dictionary rather than
// crashing on a nil insert; the URL handler then falls back to the default scene.
- (void)test_givenNilSceneId_whenBuildingBrowserCallbackOptions_thenOptionsAreEmptyAndDoNotCrash {
    SFOAuthCoordinator *coordinator = [self browserFlowCoordinator];

    NSDictionary *options = [coordinator browserCallbackOptionsForSceneId:nil];

    XCTAssertNotNil(options, @"Options must never be nil");
    XCTAssertEqual(options.count, (NSUInteger)0, @"A nil sceneId must yield an empty options dictionary so nil is never inserted and the handler falls back to the default scene");
}

- (void)test_givenUnscopedSession_whenWebViewFlowStarts_thenSceneAssociationIsRejected {
    SFSDKAuthRequest *authRequest = [[SFSDKAuthRequest alloc] init];
    authRequest.oauthClientId = @"testClientId";
    authRequest.oauthCompletionUrl = @"testapp://callback";
    authRequest.loginHost = @"login.salesforce.com";
    SFSDKAuthSession *authSession = [[SFSDKAuthSession alloc] initWith:authRequest credentials:nil];
    [authSession captureStandardWebAuthIntentWithLoginHint:nil frontDoorBridgeUrl:nil codeVerifier:nil];

    [authSession.oauthCoordinator beginWebViewFlow];

    XCTAssertFalse([authSession associateWithSceneIfUnscoped:(UIScene *)[NSObject new]]);
}

- (void)test_givenEligibleUnscopedSession_whenGenericWebViewLoadStarts_thenSceneAssociationRemainsAvailable {
    SFSDKAuthRequest *authRequest = [[SFSDKAuthRequest alloc] init];
    authRequest.oauthClientId = @"testClientId";
    authRequest.oauthCompletionUrl = @"testapp://callback";
    authRequest.loginHost = @"login.salesforce.com";
    SFSDKAuthSession *authSession = [[SFSDKAuthSession alloc] initWith:authRequest credentials:nil];
    [authSession captureStandardWebAuthIntentWithLoginHint:nil frontDoorBridgeUrl:nil codeVerifier:nil];

    [authSession.oauthCoordinator loadWebViewWithUrlString:@"https://login.salesforce.com" cookie:YES];

    SFSDKCoordinatorTestSceneSession *sceneSession = [SFSDKCoordinatorTestSceneSession new];
    sceneSession.persistentIdentifier = @"connected-scene";
    SFSDKCoordinatorTestScene *scene = [SFSDKCoordinatorTestScene new];
    scene.session = sceneSession;
    XCTAssertTrue([authSession associateWithSceneIfUnscoped:(UIScene *)scene]);
}

- (void)test_givenPresentationContinuation_whenCallbackRuns_thenSessionMonitorIsAvailableToAnotherThread {
    SFSDKAuthRequest *request = [SFSDKAuthRequest new];
    request.oauthClientId = @"testClientId";
    request.oauthCompletionUrl = @"testapp://callback";
    request.loginHost = @"login.salesforce.com";
    SFSDKAuthSession *session = [[SFSDKAuthSession alloc] initWith:request credentials:nil];
    [session captureStandardWebAuthIntentWithLoginHint:nil frontDoorBridgeUrl:nil codeVerifier:nil];
    __block BOOL acquiredSessionMonitor = NO;

    BOOL performed = [session performPresentationContinuation:^{
        dispatch_semaphore_t completed = dispatch_semaphore_create(0);
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            @synchronized (session) {
                acquiredSessionMonitor = YES;
            }
            dispatch_semaphore_signal(completed);
        });
        dispatch_semaphore_wait(completed, dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC));
    }];

    XCTAssertTrue(performed);
    XCTAssertTrue(acquiredSessionMonitor, @"Presentation/delegate code must execute outside the auth-session monitor");
}

- (void)test_givenForcedBrowserContinuationQueued_whenSessionReset_thenStaleBrowserIsNotPresented {
    SFUserAccountManager *manager = [SFUserAccountManager sharedInstance];
    SFSDKAuthRequest *request = [SFSDKAuthRequest new];
    request.oauthClientId = @"testClientId";
    request.oauthCompletionUrl = @"testapp://callback";
    request.loginHost = @"login.salesforce.com";
    request.useBrowserAuth = YES;
    SFSDKAuthSession *session = [[SFSDKAuthSession alloc] initWith:request credentials:nil];
    [session captureStandardWebAuthIntentWithLoginHint:nil frontDoorBridgeUrl:nil codeVerifier:nil];
    session.isAuthenticating = YES;
    session.credentials.redirectUri = request.oauthCompletionUrl;
    SFSDKPresentationRecordingDelegate *delegate = [SFSDKPresentationRecordingDelegate new];
    delegate.isNetworkAvailable = YES;
    session.oauthCoordinator.delegate = delegate;
    [manager setAuthSession:session forRoutingKey:session.sceneId];

    [session.oauthCoordinator authenticate];
    [manager resetAuthentication:session];
    XCTestExpectation *mainQueueDrained = [self expectationWithDescription:@"forced browser continuation drained"];
    dispatch_async(dispatch_get_main_queue(), ^{
        [mainQueueDrained fulfill];
    });
    [self waitForExpectations:@[mainQueueDrained] timeout:5.0];

    XCTAssertEqual(delegate.browserPresentationCount, 0u,
                   @"Reset must revoke a queued standard-web browser presentation continuation");
    XCTAssertFalse(delegate.willBeginAuthenticationCalled,
                   @"Reset must suppress stale forced-browser begin notifications");
    XCTAssertFalse([[SFSDKAppFeatureMarkers appFeatures] containsObject:kSFAppFeatureSafariBrowserForLogin],
                   @"Reset must not allow a stale forced-browser continuation to restore feature ownership");
}

- (void)test_givenAuthConfigContinuationReadyToPresent_whenSessionReplaced_thenStaleWebViewIsNotPresented {
    SFUserAccountManager *manager = [SFUserAccountManager sharedInstance];
    SFSDKAuthRequest *request = [SFSDKAuthRequest new];
    request.oauthClientId = @"testClientId";
    request.oauthCompletionUrl = @"testapp://callback";
    request.loginHost = @"login.salesforce.com";
    SFSDKAuthSession *session = [[SFSDKAuthSession alloc] initWith:request credentials:nil];
    [session captureStandardWebAuthIntentWithLoginHint:nil frontDoorBridgeUrl:nil codeVerifier:nil];
    session.isAuthenticating = YES;
    session.credentials.redirectUri = request.oauthCompletionUrl;
    SFSDKPresentationRecordingDelegate *delegate = [SFSDKPresentationRecordingDelegate new];
    delegate.isNetworkAvailable = YES;
    session.oauthCoordinator.delegate = delegate;
    [manager setAuthSession:session forRoutingKey:session.sceneId];

    [session.oauthCoordinator authenticate];
    SFOAuthInfo *authInfoBeforeReplacement = session.oauthCoordinator.authInfo;
    SFSDKAuthSession *replacement = [[SFSDKAuthSession alloc] initWith:request credentials:nil routingSceneId:session.sceneId];
    replacement.isAuthenticating = YES;
    [manager setAuthSession:replacement forRoutingKey:session.sceneId];
    XCTestExpectation *mainQueueDrained = [self expectationWithDescription:@"auth-config continuation drained"];
    dispatch_async(dispatch_get_main_queue(), ^{
        [mainQueueDrained fulfill];
    });
    [self waitForExpectations:@[mainQueueDrained] timeout:5.0];

    XCTAssertEqual(delegate.webViewPresentationCount, 0u,
                    @"Replacement must revoke a queued standard-web auth-config presentation continuation");
    XCTAssertFalse(delegate.willBeginAuthenticationCalled,
                   @"A replaced session's auth-config continuation must not emit a begin notification");
    XCTAssertEqual(session.oauthCoordinator.authInfo, authInfoBeforeReplacement,
                   @"A replaced session's auth-config continuation must not mutate authInfo after replacement");
    XCTAssertFalse([[SFSDKAppFeatureMarkers appFeatures] containsObject:kSFAppFeatureSafariBrowserForLogin],
                   @"A replaced session's auth-config continuation must not resurrect browser feature ownership");
    [manager resetAuthentication:replacement];
}

- (void)test_givenAuthConfigContinuationQueued_whenSessionReset_thenCallbackHasNoSideEffects {
    SFUserAccountManager *manager = [SFUserAccountManager sharedInstance];
    SFSDKAuthRequest *request = [SFSDKAuthRequest new];
    request.oauthClientId = @"testClientId";
    request.oauthCompletionUrl = @"testapp://callback";
    request.loginHost = @"login.salesforce.com";
    SFSDKAuthSession *session = [[SFSDKAuthSession alloc] initWith:request credentials:nil];
    [session captureStandardWebAuthIntentWithLoginHint:nil frontDoorBridgeUrl:nil codeVerifier:nil];
    session.isAuthenticating = YES;
    session.credentials.redirectUri = request.oauthCompletionUrl;
    SFSDKPresentationRecordingDelegate *delegate = [SFSDKPresentationRecordingDelegate new];
    delegate.isNetworkAvailable = YES;
    session.oauthCoordinator.delegate = delegate;
    [manager setAuthSession:session forRoutingKey:session.sceneId];

    [session.oauthCoordinator authenticate];
    [manager resetAuthentication:session];
    XCTestExpectation *mainQueueDrained = [self expectationWithDescription:@"reset auth-config continuation drained"];
    dispatch_async(dispatch_get_main_queue(), ^{
        [mainQueueDrained fulfill];
    });
    [self waitForExpectations:@[mainQueueDrained] timeout:5.0];

    XCTAssertEqual(delegate.webViewPresentationCount, 0u);
    XCTAssertEqual(delegate.browserPresentationCount, 0u);
    XCTAssertFalse(delegate.willBeginAuthenticationCalled);
    XCTAssertFalse(session.oauthCoordinator.authInfo.authType == SFOAuthTypeUserAgent ||
                   session.oauthCoordinator.authInfo.authType == SFOAuthTypeWebServer ||
                   session.oauthCoordinator.authInfo.authType == SFOAuthTypeAdvancedBrowser,
                   @"A reset session's auth-config continuation must not choose a standard-web auth type after reset");
    XCTAssertFalse([[SFSDKAppFeatureMarkers appFeatures] containsObject:kSFAppFeatureSafariBrowserForLogin]);
}

#pragma mark - App Attestation Feature Flag Tests

- (void)test_givenAttestationEnabled_whenAuthenticateCalled_thenAAFlagRegisteredGlobally {
    // Arrange
    BOOL originalValue = [SFUserAccountManager sharedInstance].appAttestationEnabled;
    [SFUserAccountManager sharedInstance].appAttestationEnabled = YES;
    [SFSDKAppFeatureMarkers unregisterAppFeature:kSFAppFeatureAppAttestation];

    SFOAuthCredentials *creds = [[SFOAuthCredentials alloc] initWithIdentifier:@"testAttest" clientId:@"testClient" encrypted:NO];
    creds.domain = @"mydomain.my.salesforce.com";
    creds.refreshToken = @"testRefreshToken";
    creds.redirectUri = @"testapp://callback";
    creds.instanceUrl = [NSURL URLWithString:@"https://mydomain.my.salesforce.com"];

    SFOAuthCoordinator *coordinator = [[SFOAuthCoordinator alloc] initWithCredentials:creds];
    SFOAuthTestFlowCoordinatorDelegate *delegate = [[SFOAuthTestFlowCoordinatorDelegate alloc] init];
    delegate.isNetworkAvailable = NO; // Prevent actual network calls
    coordinator.delegate = delegate;

    // Act
    [coordinator authenticate];

    // Assert: AA flag should be registered globally
    XCTAssertTrue([[SFSDKAppFeatureMarkers appFeatures] containsObject:kSFAppFeatureAppAttestation],
                  @"AA flag should be registered globally when attestation is enabled");

    // Cleanup
    [SFSDKAppFeatureMarkers unregisterAppFeature:kSFAppFeatureAppAttestation];
    [SFUserAccountManager sharedInstance].appAttestationEnabled = originalValue;
    [creds revoke];
}

- (void)test_givenAttestationEnabledSession_whenAuthenticateCalled_thenAAFlagRegisteredGloballyAndOnSession {
    BOOL originalValue = [SFUserAccountManager sharedInstance].appAttestationEnabled;
    [SFUserAccountManager sharedInstance].appAttestationEnabled = YES;
    [SFSDKAppFeatureMarkers unregisterAppFeature:kSFAppFeatureAppAttestation];
    SFSDKAuthRequest *request = [SFSDKAuthRequest new];
    request.oauthClientId = @"testClient";
    request.oauthCompletionUrl = @"testapp://callback";
    request.loginHost = @"mydomain.my.salesforce.com";
    SFSDKAuthSession *session = [[SFSDKAuthSession alloc] initWith:request credentials:nil];
    SFOAuthTestFlowCoordinatorDelegate *delegate = [[SFOAuthTestFlowCoordinatorDelegate alloc] init];
    delegate.isNetworkAvailable = NO;
    session.oauthCoordinator.delegate = delegate;

    [session.oauthCoordinator authenticate];

    XCTAssertTrue([session.transientAuthFeatures containsObject:kSFAppFeatureAppAttestation]);
    XCTAssertTrue([[SFSDKAppFeatureMarkers appFeatures] containsObject:kSFAppFeatureAppAttestation]);

    [session clearTransientAuthFeatures];
    [SFUserAccountManager sharedInstance].appAttestationEnabled = originalValue;
}

- (void)test_givenDirectGlobalMarkerAndSessionMarker_whenSessionClears_thenDirectGlobalMarkerRemains {
    [SFSDKAppFeatureMarkers registerAppFeature:kSFAppFeatureAppAttestation];
    SFSDKAuthRequest *request = [SFSDKAuthRequest new];
    request.oauthClientId = @"testClient";
    request.oauthCompletionUrl = @"testapp://callback";
    request.loginHost = @"login.salesforce.com";
    SFSDKAuthSession *session = [[SFSDKAuthSession alloc] initWith:request credentials:nil];
    [session setTransientAuthFeature:kSFAppFeatureAppAttestation enabled:YES];

    [session clearTransientAuthFeatures];

    XCTAssertTrue([[SFSDKAppFeatureMarkers appFeatures] containsObject:kSFAppFeatureAppAttestation],
                  @"Session cleanup must not erase a marker registered directly outside session tracking");
    [SFSDKAppFeatureMarkers unregisterAppFeature:kSFAppFeatureAppAttestation];
}

- (void)test_givenAttestationDisabled_whenAuthenticateCalled_thenAAFlagNotRegistered {
    // Arrange
    BOOL originalValue = [SFUserAccountManager sharedInstance].appAttestationEnabled;
    [SFUserAccountManager sharedInstance].appAttestationEnabled = NO;
    [SFSDKAppFeatureMarkers unregisterAppFeature:kSFAppFeatureAppAttestation];

    SFOAuthCredentials *creds = [[SFOAuthCredentials alloc] initWithIdentifier:@"testAttest2" clientId:@"testClient2" encrypted:NO];
    creds.domain = @"mydomain.my.salesforce.com";
    creds.refreshToken = @"testRefreshToken";
    creds.redirectUri = @"testapp://callback";
    creds.instanceUrl = [NSURL URLWithString:@"https://mydomain.my.salesforce.com"];

    SFOAuthCoordinator *coordinator = [[SFOAuthCoordinator alloc] initWithCredentials:creds];
    SFOAuthTestFlowCoordinatorDelegate *delegate = [[SFOAuthTestFlowCoordinatorDelegate alloc] init];
    delegate.isNetworkAvailable = NO; // Prevent actual network calls
    coordinator.delegate = delegate;

    // Act
    [coordinator authenticate];

    // Assert: AA flag should NOT be registered
    XCTAssertFalse([[SFSDKAppFeatureMarkers appFeatures] containsObject:kSFAppFeatureAppAttestation],
                   @"AA flag should not be registered when attestation is disabled");

    // Cleanup
    [SFUserAccountManager sharedInstance].appAttestationEnabled = originalValue;
    [creds revoke];
}

#pragma mark - App Attestation Forces Web Server Flow Tests

- (void)test_givenAttestationEnabled_andWebServerFlowDisabled_whenAuthenticateCalled_thenUsesWebServerFlowType {
    // Arrange
    BOOL originalAttestation = [SFUserAccountManager sharedInstance].appAttestationEnabled;
    BOOL originalWebServer = [[SalesforceSDKManager sharedManager] useWebServerAuthentication];
    [SFUserAccountManager sharedInstance].appAttestationEnabled = YES;
    [SalesforceSDKManager sharedManager].useWebServerAuthentication = NO;

    SFOAuthCredentials *creds = [[SFOAuthCredentials alloc] initWithIdentifier:@"testFlowType" clientId:@"testClient" encrypted:NO];
    creds.domain = @"mydomain.my.salesforce.com";
    creds.redirectUri = @"testapp://callback";
    creds.instanceUrl = [NSURL URLWithString:@"https://mydomain.my.salesforce.com"];
    // No refresh token — forces the auth type selection path (not refresh flow)

    SFOAuthCoordinator *coordinator = [[SFOAuthCoordinator alloc] initWithCredentials:creds];
    coordinator.useBrowserAuth = NO;
    SFOAuthTestFlowCoordinatorDelegate *delegate = [[SFOAuthTestFlowCoordinatorDelegate alloc] init];
    delegate.isNetworkAvailable = NO;
    coordinator.delegate = delegate;

    // Act
    [coordinator authenticate];

    // Assert: should select web server flow despite useWebServerAuthentication = NO
    XCTAssertEqual(coordinator.authInfo.authType, SFOAuthTypeWebServer,
                   @"Auth type should be WebServer when attestation is enabled, even if useWebServerAuthentication is NO");

    // Cleanup
    [SFUserAccountManager sharedInstance].appAttestationEnabled = originalAttestation;
    [SalesforceSDKManager sharedManager].useWebServerAuthentication = originalWebServer;
    [SFSDKAppFeatureMarkers unregisterAppFeature:kSFAppFeatureAppAttestation];
    [creds revoke];
}

- (void)test_givenAttestationDisabled_andWebServerFlowDisabled_whenAuthenticateCalled_thenUsesUserAgentFlowType {
    // Arrange
    BOOL originalAttestation = [SFUserAccountManager sharedInstance].appAttestationEnabled;
    BOOL originalWebServer = [[SalesforceSDKManager sharedManager] useWebServerAuthentication];
    [SFUserAccountManager sharedInstance].appAttestationEnabled = NO;
    [SalesforceSDKManager sharedManager].useWebServerAuthentication = NO;

    SFOAuthCredentials *creds = [[SFOAuthCredentials alloc] initWithIdentifier:@"testFlowType2" clientId:@"testClient2" encrypted:NO];
    creds.domain = @"mydomain.my.salesforce.com";
    creds.redirectUri = @"testapp://callback";
    creds.instanceUrl = [NSURL URLWithString:@"https://mydomain.my.salesforce.com"];
    // No refresh token — forces the auth type selection path

    SFOAuthCoordinator *coordinator = [[SFOAuthCoordinator alloc] initWithCredentials:creds];
    coordinator.useBrowserAuth = NO;
    SFOAuthTestFlowCoordinatorDelegate *delegate = [[SFOAuthTestFlowCoordinatorDelegate alloc] init];
    delegate.isNetworkAvailable = NO;
    coordinator.delegate = delegate;

    // Act
    [coordinator authenticate];

    // Assert: should use user agent flow when both attestation and web server are off
    XCTAssertEqual(coordinator.authInfo.authType, SFOAuthTypeUserAgent,
                   @"Auth type should be UserAgent when both attestation and useWebServerAuthentication are disabled");

    // Cleanup
    [SFUserAccountManager sharedInstance].appAttestationEnabled = originalAttestation;
    [SalesforceSDKManager sharedManager].useWebServerAuthentication = originalWebServer;
    [creds revoke];
}

- (void)test_givenAttestationEnabled_whenGeneratingApprovalUrl_thenContainsResponseTypeCode {
    // Arrange
    BOOL originalAttestation = [SFUserAccountManager sharedInstance].appAttestationEnabled;
    BOOL originalWebServer = [[SalesforceSDKManager sharedManager] useWebServerAuthentication];
    [SFUserAccountManager sharedInstance].appAttestationEnabled = YES;
    [SalesforceSDKManager sharedManager].useWebServerAuthentication = NO;

    SFOAuthCredentials *creds = [[SFOAuthCredentials alloc] initWithIdentifier:@"testApprovalUrl" clientId:@"testClient" encrypted:NO];
    creds.domain = @"mydomain.my.salesforce.com";
    creds.redirectUri = @"testapp://callback";
    creds.instanceUrl = [NSURL URLWithString:@"https://mydomain.my.salesforce.com"];

    SFOAuthCoordinator *coordinator = [[SFOAuthCoordinator alloc] initWithCredentials:creds];
    coordinator.useBrowserAuth = NO;

    // Act
    NSString *approvalUrl = [coordinator generateApprovalUrlString];

    // Assert: URL should contain response_type=code (web server flow)
    XCTAssertTrue([approvalUrl containsString:@"response_type=code"],
                  @"Approval URL should use response_type=code when attestation is enabled; got: %@", approvalUrl);
    XCTAssertFalse([approvalUrl containsString:@"response_type=token"],
                   @"Approval URL should NOT use response_type=token when attestation is enabled; got: %@", approvalUrl);

    // Cleanup
    [SFUserAccountManager sharedInstance].appAttestationEnabled = originalAttestation;
    [SalesforceSDKManager sharedManager].useWebServerAuthentication = originalWebServer;
    [creds revoke];
}

- (void)test_givenAttestationDisabled_andWebServerFlowDisabled_whenGeneratingApprovalUrl_thenDoesNotContainResponseTypeCode {
    // Arrange
    BOOL originalAttestation = [SFUserAccountManager sharedInstance].appAttestationEnabled;
    BOOL originalWebServer = [[SalesforceSDKManager sharedManager] useWebServerAuthentication];
    [SFUserAccountManager sharedInstance].appAttestationEnabled = NO;
    [SalesforceSDKManager sharedManager].useWebServerAuthentication = NO;

    SFOAuthCredentials *creds = [[SFOAuthCredentials alloc] initWithIdentifier:@"testApprovalUrl2" clientId:@"testClient2" encrypted:NO];
    creds.domain = @"mydomain.my.salesforce.com";
    creds.redirectUri = @"testapp://callback";
    creds.instanceUrl = [NSURL URLWithString:@"https://mydomain.my.salesforce.com"];

    SFOAuthCoordinator *coordinator = [[SFOAuthCoordinator alloc] initWithCredentials:creds];
    coordinator.useBrowserAuth = NO;

    // Act
    NSString *approvalUrl = [coordinator generateApprovalUrlString];

    // Assert: URL should NOT contain response_type=code (user agent flow uses token or hybrid_token)
    XCTAssertFalse([approvalUrl containsString:@"response_type=code"],
                   @"Approval URL should NOT use response_type=code when attestation and web server flow are both disabled; got: %@", approvalUrl);

    // Cleanup
    [SFUserAccountManager sharedInstance].appAttestationEnabled = originalAttestation;
    [SalesforceSDKManager sharedManager].useWebServerAuthentication = originalWebServer;
    [creds revoke];
}

@end
