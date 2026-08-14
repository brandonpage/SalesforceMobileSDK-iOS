/*
 Copyright (c) 2012-present, salesforce.com, inc. All rights reserved.
 
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
#import <SalesforceSDKCommon/SFJsonUtils.h>
#import <SalesforceSDKCore/SalesforceSDKCore.h>
#import "SFSDKLogoutBlocker.h"
#import "SFSDKAuthViewHandler.h"
#import "SFUserAccountManager+Internal.h"
#import "SFUserAccount+Internal.h"
#import "SFDefaultUserAccountPersister.h"
#import "SFOAuthCredentials+Internal.h"
#import "TestSetupUtils.h"
#import "SFSDKAuthRequest.h"
#import "SFUserAccountConstants.h"
#import "SFOAuthCoordinator+Internal.h"
#import "SalesforceSDKManager+Internal.h"
#import "SFSDKLoginHostStorage.h"
#import "SFSDKLoginHost.h"
static NSString * const kUserIdFormatString = @"005R0000000Dsl%lu";
static NSString * const kOrgIdFormatString = @"00D000000000062EA%lu";

@interface SFSDKSafeMutableDictionary (SFUserAccountManagerTestsMove)

- (BOOL)moveObject:(id)expectedObject
           fromKey:(id<NSCopying>)sourceKey
             toKey:(id<NSCopying>)destinationKey
 beforeMovingBlock:(nullable BOOL (^)(id object))beforeMovingBlock;

@end

@interface NSURL (SFSDKQrCodeLoginRequestTesting)
@property (nonatomic, assign) BOOL sfsdk_isQrCodeLoginRequest;
@end

@interface SFUserAccountManager ()

- (void)notifyLoginCompletion:(SFUserAccount *)userAccount authInfo:(SFOAuthInfo *)authInfo;
- (BOOL)authenticateWithCompletion:(SFUserAccountManagerSuccessCallbackBlock)completionBlock
                           failure:(SFUserAccountManagerFailureCallbackBlock)failureBlock
                             scene:(UIScene *)scene;
- (BOOL)authenticateWithRequest:(SFSDKAuthRequest *)request
                      loginHint:(nullable NSString *)loginHint
                     completion:(SFUserAccountManagerSuccessCallbackBlock)completionBlock
                        failure:(SFUserAccountManagerFailureCallbackBlock)failureBlock
             frontDoorBridgeUrl:(nullable NSURL *)frontDoorBridgeUrl
                   codeVerifier:(nullable NSString *)codeVerifier
                 routingSceneId:(nullable NSString *)routingSceneId;
- (void)restartAuthentication:(SFSDKAuthSession *)session;
- (void)resetAuthentication:(SFSDKAuthSession *)authSession;
- (void)startAuthenticationForSession:(SFSDKAuthSession *)authSession
                            coordinator:(SFOAuthCoordinator *)coordinator
                            credentials:(SFOAuthCredentials *)credentials;
- (void)loggedIn:(BOOL)fromOffline coordinator:(SFOAuthCoordinator *)coordinator notifyDelegatesOfFailure:(BOOL)shouldNotify;
- (void)retrievedIdentityData:(SFSDKAuthSession *)authSession;
- (BOOL)finalizeAuthCompletion:(SFSDKAuthSession *)authSession;
- (void)restartAuthentication:(SFSDKAuthSession *)session recoveryToken:(id)recoveryToken;
- (void)notifyUserCancelledOrDismissedAuth:(SFOAuthCredentials *)credentials andAuthInfo:(SFOAuthInfo *)info;
- (void)handleFailure:(NSError *)error session:(SFSDKAuthSession *)authSession;
- (void)oauthCoordinatorDidCancelBrowserAuthentication:(SFOAuthCoordinator *)coordinator;
- (void)identityCoordinator:(SFIdentityCoordinator *)coordinator didFailWithError:(NSError *)error;
- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didFailWithError:(NSError *)error authInfo:(nullable SFOAuthInfo *)info;
- (void)beforeIrreversibleHostRecoveryForSession:(SFSDKAuthSession *)session;
- (void)sceneDidDisconnect:(NSNotification *)notification;

@end

@interface SFSDKSceneDisconnectPresentationDelegate : NSObject <SFOAuthCoordinatorDelegate>

@property (nonatomic, assign) NSUInteger beginNotificationCount;
@property (nonatomic, assign) NSUInteger presentationCount;

@end

@implementation SFSDKSceneDisconnectPresentationDelegate

- (BOOL)oauthCoordinatorIsNetworkAvailable:(SFOAuthCoordinator *)coordinator {
    return YES;
}

- (void)oauthCoordinatorDidAuthenticate:(SFOAuthCoordinator *)coordinator authInfo:(SFOAuthInfo *)info {}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didFailWithError:(NSError *)error authInfo:(SFOAuthInfo *)info {}

- (void)oauthCoordinatorDidCancelBrowserAuthentication:(SFOAuthCoordinator *)coordinator {}

- (void)oauthCoordinatorWillBeginAuthentication:(SFOAuthCoordinator *)coordinator authInfo:(SFOAuthInfo *)info {
    self.beginNotificationCount += 1;
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator willBeginAuthenticationWithView:(WKWebView *)view {
    self.presentationCount += 1;
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didBeginAuthenticationWithSession:(ASWebAuthenticationSession *)session {
    self.presentationCount += 1;
}

@end

@interface SFSDKTestSceneSession : NSObject

@property (nonatomic, copy) NSString *persistentIdentifier;

@end


@implementation SFSDKTestSceneSession

@end


@interface SFSDKTestScene : NSObject

@property (nonatomic, strong) SFSDKTestSceneSession *session;

@end


@implementation SFSDKTestScene

@end


@interface SFSDKAuthenticationStartRecordingCoordinator : SFOAuthCoordinator

@property (nonatomic, assign) NSUInteger authenticateWithCredentialsCallCount;

@end


@implementation SFSDKAuthenticationStartRecordingCoordinator

- (void)beginAuthenticationWithCredentials:(SFOAuthCredentials *)credentials {
    self.authenticateWithCredentialsCallCount += 1;
}

@end

@interface SFSDKRecoveryStopRecordingCoordinator : SFOAuthCoordinator

@property (nonatomic, assign) NSUInteger stopAuthenticationCallCount;

@end

@implementation SFSDKRecoveryStopRecordingCoordinator

- (void)stopAuthentication {
    self.stopAuthenticationCallCount += 1;
}

@end

@interface SFSDKIdentityRetrievalRecordingCoordinator : SFIdentityCoordinator

@property (nonatomic, assign) NSUInteger initiateIdentityDataRetrievalCallCount;

@end

@implementation SFSDKIdentityRetrievalRecordingCoordinator

- (void)initiateIdentityDataRetrieval {
    self.initiateIdentityDataRetrievalCallCount += 1;
}

@end

@interface SFSDKRevocationRecordingOAuthClient : NSObject <SFSDKOAuthProtocol>

@property (nonatomic, assign) NSUInteger revokeRefreshTokenCallCount;

@end

@implementation SFSDKRevocationRecordingOAuthClient

- (void)accessTokenForApprovalCode:(SFSDKOAuthTokenEndpointRequest *)endpointReq completion:(void (^)(SFSDKOAuthTokenEndpointResponse *))completionBlock {}
- (void)accessTokenForRefresh:(SFSDKOAuthTokenEndpointRequest *)endpointReq completion:(void (^)(SFSDKOAuthTokenEndpointResponse *))completionBlock {}
- (void)openIDTokenForRefresh:(SFSDKOAuthTokenEndpointRequest *)endpointReq completion:(void (^)(NSString *))completionBlock {}
- (void)revokeRefreshToken:(SFOAuthCredentials *)credentials reason:(SFLogoutReason)reason {
    self.revokeRefreshTokenCallCount += 1;
}

@end


@interface SFSDKStartupGapTestUserAccountManager : SFUserAccountManager

@property (nonatomic, copy) void (^beforeCoordinatorStartup)(SFSDKAuthSession *authSession);

@end


@implementation SFSDKStartupGapTestUserAccountManager

- (void)startAuthenticationForSession:(SFSDKAuthSession *)authSession
                           coordinator:(SFOAuthCoordinator *)coordinator
                           credentials:(SFOAuthCredentials *)credentials {
    if (self.beforeCoordinatorStartup) {
        self.beforeCoordinatorStartup(authSession);
    }
    [super startAuthenticationForSession:authSession coordinator:coordinator credentials:credentials];
}

@end


@interface SFSDKAuthGuardTestUserAccountManager : SFUserAccountManager

@property (nonatomic, assign) NSUInteger authenticateWithRequestCallCount;
@property (nonatomic, assign) NSUInteger stopCurrentAuthenticationCallCount;
@property (nonatomic, assign) BOOL storesAuthSession;
@property (nonatomic, assign) BOOL useNativeLoginRequest;
@property (nonatomic, assign) BOOL useIDPRequest;
@property (nonatomic, assign) BOOL failAuthentication;
@property (nonatomic, assign) BOOL defersDismissalCompletion;
@property (nonatomic, assign) NSUInteger authenticateUsingIDPCallCount;
@property (nonatomic, copy) SFUserAccountManagerSuccessCallbackBlock capturedSuccessBlock;
@property (nonatomic, copy) SFUserAccountManagerFailureCallbackBlock capturedFailureBlock;
@property (nonatomic, copy) void (^deferredDismissalCompletion)(void);
@property (nonatomic, copy) void (^capturedErrorAlertCompletion)(void);
@property (nonatomic, assign) BOOL returnsLoggingOutAccount;
@property (nonatomic, assign) BOOL defersShouldBlockCompletion;
@property (nonatomic, assign) NSUInteger shouldBlockCallCount;
@property (nonatomic, assign) NSUInteger applyCredentialsCallCount;
@property (nonatomic, copy) void (^deferredShouldBlockCompletion)(BOOL);
@property (nonatomic, copy) void (^beforeFinalizeAuthCompletion)(SFSDKAuthSession *authSession);
@property (nonatomic, assign) BOOL interceptRecoveryRestart;
@property (nonatomic, assign) NSUInteger recoveryRestartCallCount;
@property (nonatomic, assign) NSUInteger cancellationNotificationCallCount;
@property (nonatomic, assign) NSUInteger loginWithCompletionCallCount;
@property (nonatomic, assign) NSUInteger handleFailureCallCount;
@property (nonatomic, assign) BOOL fallbackToWebAuthentication;
@property (nonatomic, assign) BOOL interceptFailureHandling;
@property (nonatomic, assign) BOOL observeFailureHandlingLock;
@property (nonatomic, assign) BOOL failureHandlingObservedAccountsLockAvailable;
@property (nonatomic, copy) void (^beforeIrreversibleHostRecovery)(SFSDKAuthSession *authSession);
@property (nonatomic, strong) NSURL *capturedFrontDoorBridgeUrl;

- (void)fireDismissalCompletion;
- (void)fireErrorAlertCompletion;
- (void)fireShouldBlockCompletion:(BOOL)shouldBlock;
- (BOOL)isAccountsLockAvailableFromAnotherThread;

@end


@implementation SFSDKAuthGuardTestUserAccountManager

- (SFSDKAuthRequest *)defaultAuthRequest {
    return [self defaultAuthRequestWithLoginHost:nil];
}

- (SFSDKAuthRequest *)defaultAuthRequestWithLoginHost:(NSString *)loginHost {
    SFSDKAuthRequest *request = [SFSDKAuthRequest new];
    request.oauthClientId = @"test-client-id";
    request.oauthCompletionUrl = @"testapp://callback";
    request.loginHost = loginHost ?: @"login.salesforce.com";
    if (self.useIDPRequest) {
        request.idpAppURIScheme = @"test-idp";
    }
    return request;
}

- (SFSDKAuthRequest *)nativeLoginAuthRequest {
    SFSDKAuthRequest *request = [self defaultAuthRequest];
    request.loginHost = @"native-login.example.com";
    return request;
}

- (BOOL)nativeLoginEnabled {
    return self.useNativeLoginRequest;
}

- (BOOL)shouldFallbackToWebAuthentication {
    return self.fallbackToWebAuthentication;
}

- (BOOL)loginWithCompletion:(SFUserAccountManagerSuccessCallbackBlock)completionBlock
                    failure:(SFUserAccountManagerFailureCallbackBlock)failureBlock {
    self.loginWithCompletionCallCount += 1;
    return YES;
}

- (BOOL)authenticateUsingIDP:(SFSDKAuthRequest *)request
                  completion:(SFUserAccountManagerSuccessCallbackBlock)completionBlock
                     failure:(SFUserAccountManagerFailureCallbackBlock)failureBlock {
    self.authenticateUsingIDPCallCount += 1;
    return YES;
}

- (BOOL)authenticateWithRequest:(SFSDKAuthRequest *)request
                      loginHint:(NSString *)loginHint
                     completion:(SFUserAccountManagerSuccessCallbackBlock)completionBlock
                        failure:(SFUserAccountManagerFailureCallbackBlock)failureBlock
             frontDoorBridgeUrl:(NSURL *)frontDoorBridgeUrl
                    codeVerifier:(NSString *)codeVerifier {
    self.authenticateWithRequestCallCount += 1;
    self.capturedSuccessBlock = completionBlock;
    self.capturedFailureBlock = failureBlock;
    self.capturedFrontDoorBridgeUrl = frontDoorBridgeUrl;
    if (self.failAuthentication) {
        failureBlock([[SFOAuthInfo alloc] initWithAuthType:SFOAuthTypeUserAgent],
                     [NSError errorWithDomain:@"SFSDKAuthHelperTests" code:1 userInfo:nil]);
        return NO;
    }
    if (self.storesAuthSession) {
        SFOAuthCredentials *credentials = [[SFOAuthCredentials alloc] initWithIdentifier:[[NSUUID UUID] UUIDString]
                                                                                clientId:request.oauthClientId
                                                                               encrypted:NO];
        SFSDKAuthSession *session = [[SFSDKAuthSession alloc] initWith:request credentials:credentials];
        session.isAuthenticating = YES;
        self.authSessions[session.sceneId] = session;
    }
    return YES;
}

- (BOOL)authenticateWithRequest:(SFSDKAuthRequest *)request
                      loginHint:(NSString *)loginHint
                     completion:(SFUserAccountManagerSuccessCallbackBlock)completionBlock
                        failure:(SFUserAccountManagerFailureCallbackBlock)failureBlock
             frontDoorBridgeUrl:(NSURL *)frontDoorBridgeUrl
                   codeVerifier:(NSString *)codeVerifier
                  routingSceneId:(NSString *)routingSceneId {
    self.authenticateWithRequestCallCount += 1;
    if (self.failAuthentication) {
        return NO;
    }
    SFSDKAuthSession *session = [[SFSDKAuthSession alloc] initWith:request credentials:nil routingSceneId:routingSceneId];
    session.isAuthenticating = YES;
    session.authSuccessCallback = completionBlock;
    session.authFailureCallback = failureBlock;
    [session captureStandardWebAuthIntentWithLoginHint:loginHint
                                    frontDoorBridgeUrl:frontDoorBridgeUrl
                                          codeVerifier:codeVerifier];
    self.authSessions[session.sceneId] = session;
    return YES;
}

- (void)stopCurrentAuthentication:(void (^)(BOOL))completionBlock {
    self.stopCurrentAuthenticationCallCount += 1;
    if (completionBlock) {
        completionBlock(YES);
    }
}

- (void)dismissAuthViewControllerIfPresentForScene:(UIScene *)scene completion:(void (^)(void))completion {
    if (self.defersDismissalCompletion && completion) {
        self.deferredDismissalCompletion = completion;
        return;
    }
    if (completion) {
        completion();
    }
}

- (void)fireDismissalCompletion {
    void (^completion)(void) = self.deferredDismissalCompletion;
    self.deferredDismissalCompletion = nil;
    if (completion) {
        completion();
    }
}

- (void)showErrorAlertWithMessage:(NSString *)alertMessage buttonTitle:(NSString *)buttonTitle scene:(UIScene *)scene andCompletion:(void (^)(void))completionBlock {
    self.capturedErrorAlertCompletion = completionBlock;
}

- (void)fireErrorAlertCompletion {
    void (^completion)(void) = self.capturedErrorAlertCompletion;
    self.capturedErrorAlertCompletion = nil;
    if (completion) {
        completion();
    }
}

- (void)restartAuthentication:(SFSDKAuthSession *)session recoveryToken:(id)recoveryToken {
    if (self.interceptRecoveryRestart) {
        self.recoveryRestartCallCount += 1;
        return;
    }
    [super restartAuthentication:session recoveryToken:recoveryToken];
}

- (void)notifyUserCancelledOrDismissedAuth:(SFOAuthCredentials *)credentials andAuthInfo:(SFOAuthInfo *)info {
    self.cancellationNotificationCallCount += 1;
}

- (void)handleFailure:(NSError *)error session:(SFSDKAuthSession *)authSession {
    self.handleFailureCallCount += 1;
    if (self.observeFailureHandlingLock) {
        self.failureHandlingObservedAccountsLockAvailable = [self isAccountsLockAvailableFromAnotherThread];
    }
    if (!self.interceptFailureHandling) {
        [super handleFailure:error session:authSession];
    }
}

- (void)beforeIrreversibleHostRecoveryForSession:(SFSDKAuthSession *)session {
    if (self.beforeIrreversibleHostRecovery) {
        self.beforeIrreversibleHostRecovery(session);
    }
}

- (SFUserAccount *)applyCredentials:(SFOAuthCredentials *)credentials withIdData:(SFIdentityData *)identityData {
    self.applyCredentialsCallCount += 1;
    SFUserAccount *account = [super applyCredentials:credentials withIdData:identityData];
    if (self.returnsLoggingOutAccount) {
        [account transitionToLoginState:SFUserAccountLoginStateLoggedIn];
        [account transitionToLoginState:SFUserAccountLoginStateLoggingOut];
    }
    return account;
}

- (void)shouldBlockUser:(SFOAuthCredentials *)credentials completion:(void (^)(BOOL))completion errorBlock:(void (^)(NSError *))errorBlock {
    self.shouldBlockCallCount += 1;
    if (self.defersShouldBlockCompletion) {
        self.deferredShouldBlockCompletion = completion;
    } else {
        completion(NO);
    }
}

- (void)fireShouldBlockCompletion:(BOOL)shouldBlock {
    void (^completion)(BOOL) = self.deferredShouldBlockCompletion;
    self.deferredShouldBlockCompletion = nil;
    if (completion) {
        completion(shouldBlock);
    }
}

- (BOOL)finalizeAuthCompletion:(SFSDKAuthSession *)authSession {
    if (self.beforeFinalizeAuthCompletion) {
        self.beforeFinalizeAuthCompletion(authSession);
    }
    return [super finalizeAuthCompletion:authSession];
}

- (BOOL)isAccountsLockAvailableFromAnotherThread {
    NSRecursiveLock *accountsLock = [self valueForKey:@"accountsLock"];
    __block BOOL lockAvailable = NO;
    dispatch_semaphore_t completed = dispatch_semaphore_create(0);
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        lockAvailable = [accountsLock tryLock];
        if (lockAvailable) {
            [accountsLock unlock];
        }
        dispatch_semaphore_signal(completed);
    });
    dispatch_semaphore_wait(completed, DISPATCH_TIME_FOREVER);
    return lockAvailable;
}

@end

@interface SFSDKTerminalDuringCallbackRegistrationAuthSession : SFSDKAuthSession

@property (nonatomic, strong) SFOAuthInfo *completionAuthInfo;
@property (nonatomic, strong) SFUserAccount *completionUserAccount;

@end

@implementation SFSDKTerminalDuringCallbackRegistrationAuthSession

- (void (^)(void))registerAuthSuccessCallback:(void (^)(SFOAuthInfo *, SFUserAccount *))successCallback
                             failureCallback:(void (^)(SFOAuthInfo *, NSError *))failureCallback {
    [self completeAuthenticationWithAuthInfo:self.completionAuthInfo userAccount:self.completionUserAccount];
    return [super registerAuthSuccessCallback:successCallback failureCallback:failureCallback];
}

@end

@interface SFSDKAuthGuardRaceDictionary : SFSDKSafeMutableDictionary

@property (nonatomic, copy) NSString *sourceKeyToRemoveAfterSnapshot;
@property (nonatomic, assign) NSUInteger snapshotCountBeforeRemoval;

@end

@implementation SFSDKAuthGuardRaceDictionary

- (NSDictionary *)dictionary {
    NSDictionary *snapshot = [super dictionary];
    NSString *sourceKey = self.sourceKeyToRemoveAfterSnapshot;
    if (sourceKey && self.snapshotCountBeforeRemoval == 0) {
        self.sourceKeyToRemoveAfterSnapshot = nil;
        [self removeObject:sourceKey];
    } else if (sourceKey) {
        self.snapshotCountBeforeRemoval -= 1;
    }
    return snapshot;
}

@end

@interface SFSDKAuthHelper (LoginAttempt)

+ (void)attemptLoginWithAccountManager:(SFUserAccountManager *)accountManager
                                 scene:(UIScene *)scene
                             loginHint:(nullable NSString *)loginHint
                             loginHost:(nullable NSString *)loginHost
                    frontDoorBridgeUrl:(nullable NSURL *)frontDoorBridgeUrl
                          codeVerifier:(nullable NSString *)codeVerifier
                            completion:(nullable void (^)(void))completionBlock;

@end

@interface SFUserAccountManager (FailureHandlingTests)

- (void)handleFailure:(NSError *)error session:(SFSDKAuthSession *)authSession;

@end

@interface TestUserAccountManagerDelegate : NSObject <SFUserAccountManagerDelegate>

@property (nonatomic, strong) SFUserAccount *willSwitchOrigUserAccount;
@property (nonatomic, strong) SFUserAccount *willSwitchNewUserAccount;
@property (nonatomic, strong) SFUserAccount *didSwitchOrigUserAccount;
@property (nonatomic, strong) SFUserAccount *didSwitchNewUserAccount;
@property (nonatomic,strong) SFOAuthCredentials *willLoginCredentials;
@property (nonatomic,strong) SFUserAccount *didLoginUserAccount;
@property (nonatomic,strong) NSError *error;

@end

@implementation TestUserAccountManagerDelegate

- (id)init {
    self = [super init];
    if (self) {
        [[SFUserAccountManager sharedInstance] addDelegate:self];
    }
    return self;
}

- (void)dealloc {
    [[SFUserAccountManager sharedInstance] removeDelegate:self];
}

- (BOOL)userAccountManager:(SFUserAccountManager *)userAccountManager error:(NSError *)error info:(SFOAuthInfo *)info {
    self.error = error;
    return NO;
}

- (void)userAccountManager:(SFUserAccountManager *)userAccountManager
        willSwitchFromUser:(SFUserAccount *)fromUser
                    toUser:(SFUserAccount *)toUser {
    self.willSwitchOrigUserAccount = fromUser;
    self.willSwitchNewUserAccount = toUser;
}

- (void)userAccountManager:(SFUserAccountManager *)userAccountManager
         didSwitchFromUser:(SFUserAccount *)fromUser
                    toUser:(SFUserAccount *)toUser {
    self.didSwitchOrigUserAccount = fromUser;
    self.didSwitchNewUserAccount = toUser;
}

@end

/** Unit tests for the SFUserAccountManager
 */
@interface SFUserAccountManagerTests : XCTestCase

@property (nonatomic, strong) SFUserAccountManager *uam;
@property (nonatomic, strong) SFSDKAuthViewHandler *authViewHandler;
@property (nonatomic, strong) SFSDKLoginViewControllerConfig *config;
@property (nonatomic, strong) NSString *origLoginHost;
@property (nonatomic, strong) SFUserAccount *origAccount;

- (SFUserAccount *)createNewUserWithIndex:(NSUInteger)index;
- (NSArray *)createAndVerifyUserAccounts:(NSUInteger)numAccounts;
- (UIScene *)sceneWithIdentifier:(NSString *)identifier;
- (SFSDKAuthSession *)authenticatingSessionForScene:(UIScene *)scene;
- (SFSDKAuthRequest *)standardWebRequestForScene:(UIScene *)scene;
- (NSURL *)frontDoorBridgeURLWithClientId:(NSString *)clientId identifier:(NSString *)identifier;

@end

@implementation SFUserAccountManagerTests

+ (void)setUp
{
    [SFSDKLogoutBlocker block];
    [super setUp];
}

- (void)setUp {
    [super setUp];
    // Delete the content of the global library directory
    NSString *globalLibraryDirectory = [[SFDirectoryManager sharedManager] globalDirectoryOfType:NSLibraryDirectory components:nil];
    [[NSFileManager defaultManager] removeItemAtPath:globalLibraryDirectory error:nil];
    // Set the oauth client ID after deleting the content of the global library directory
    // to ensure the SFUserAccountManager sharedInstance loads from an empty directory
    self.uam = [SFUserAccountManager sharedInstance];
    _origLoginHost = self.uam.loginHost;
    _origAccount = [SFUserAccountManager sharedInstance].currentUser;
    // Ensure the user account manager doesn't contain any account
    NSArray *userAccounts = [[SFUserAccountManager sharedInstance] allUserAccounts];
    for (SFUserAccount *account in userAccounts) {
        if (account != _origAccount) {
            NSError *error = nil;
            [self.uam deleteAccountForUser:account error:&error];
        }
    }
    [self.uam clearAllAccountState];
    [[SFUserAccountManager sharedInstance] setCurrentUserInternal:nil];
    self.uam.useBrowserAuth = NO;
    self.authViewHandler = [SFUserAccountManager sharedInstance].authViewHandler;
    self.config = self.uam.loginViewControllerConfig;
}

- (void)tearDown {
    [SFUserAccountManager sharedInstance].authViewHandler = self.authViewHandler;
    self.uam.loginViewControllerConfig = self.config;
    self.uam.loginHost = _origLoginHost;
    [[SFUserAccountManager sharedInstance] setCurrentUser:_origAccount];
    [[SFUserAccountManager sharedInstance] setCurrentUserInternal:_origAccount];
    [super tearDown];
}


#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"

- (void)testAccountIdentityEquality {
    NSDictionary *accountIdentityMatrix = @{
                                            @"MatchGroup1": @[
                                                    [[SFUserAccountIdentity alloc] initWithUserId:@"UserID1" orgId:@"OrgID1"],
                                                    [[SFUserAccountIdentity alloc] initWithUserId:@"UserID1" orgId:@"OrgID1"]
                                                    ],
                                            @"MatchGroup2": @[
                                                    [[SFUserAccountIdentity alloc] initWithUserId:@"UserID2" orgId:@"OrgID2"],
                                                    [[SFUserAccountIdentity alloc] initWithUserId:@"UserID2" orgId:@"OrgID2"]
                                                    ]
                                            };
    NSArray *keys = [accountIdentityMatrix allKeys];
    for (NSUInteger i = 0; i < [keys count]; i++) {
        
        // Equality
        NSArray *equalIdentitiesArray = accountIdentityMatrix[keys[i]];
        for (NSUInteger j = 0; j < [equalIdentitiesArray count]; j++) {
            SFUserAccountIdentity *obj1 = equalIdentitiesArray[j];
            for (NSUInteger k = 0; k < [equalIdentitiesArray count]; k++) {
                SFUserAccountIdentity *obj2 = equalIdentitiesArray[k];
                XCTAssertEqualObjects(obj1, obj2, @"Account identity '%@' and '%@' should be equal", obj1, obj2);
            }
        }
        
        // Inequality
        for (NSUInteger j = 0; j < [equalIdentitiesArray count]; j++) {
            SFUserAccountIdentity *obj1 = equalIdentitiesArray[j];
            for (NSUInteger k = 0; k < [keys count]; k++) {
                if (k == i) continue;
                NSArray *unequalIdentitiesArray = accountIdentityMatrix[keys[k]];
                for (NSUInteger l = 0; l < [unequalIdentitiesArray count]; l++) {
                    SFUserAccountIdentity *obj2 = unequalIdentitiesArray[l];
                    XCTAssertFalse([obj1 isEqual:obj2], @"Account identity '%@' and '%@' should NOT be equal", obj1, obj2);
                }
            }
        }
    }
}

#pragma clang diagnostic pop

- (void)testAccountIdentityUpdateFromCredentialsUpdate {
    NSArray *accounts = [self createAndVerifyUserAccounts:1];
    SFUserAccount *user = accounts[0];
    XCTAssertEqual(user.accountIdentity.userId, user.credentials.userId, @"Account identity UserID and credentials User ID should be equal.");
    XCTAssertEqual(user.accountIdentity.orgId, user.credentials.organizationId, @"Account identity UserID and credentials User ID should be equal.");
    
    // Changed credentials IDs.
    user.credentials.userId = @"NewUserId";
    user.credentials.organizationId = @"NewOrgId";
    XCTAssertEqual(user.accountIdentity.userId, @"NewUserId", @"Updated User ID in credentials not reflected in account identity.");
    XCTAssertEqual(user.accountIdentity.orgId, @"NewOrgId", @"Updated Org ID in credentials not reflected in account identity.");
    
    // Swap out credentials entirely.
    NSString *newCredentialsIdentifier = [NSString stringWithFormat:@"%@_1", user.credentials.identifier];
    SFOAuthCredentials *newCreds = [[SFOAuthCredentials alloc] initWithIdentifier:newCredentialsIdentifier clientId:user.credentials.clientId encrypted:YES];
    newCreds.userId = @"NewCredsUserId";
    newCreds.organizationId = @"NewCredsOrgId";
    user.credentials = newCreds;
    XCTAssertEqual(user.accountIdentity.userId, @"NewCredsUserId", @"User ID in new credentials not reflected in account identity.");
    XCTAssertEqual(user.accountIdentity.orgId, @"NewCredsOrgId", @"Org ID in new credentials not reflected in account identity.");
}

- (void)testSingleAccount {
    // Ensure we start with a clean state
    XCTAssertEqual([self.uam.allUserIdentities count], (NSUInteger)0, @"There should be no accounts");
    
    // Create a single user
    NSArray *accounts = [self createAndVerifyUserAccounts:1];
    SFUserAccount *user = accounts[0];
    // Check if the UserAccount.plist is stored at the right location
    NSString *expectedLocation = [[SFDirectoryManager sharedManager] directoryForOrg:user.credentials.organizationId user:user.credentials.userId community:nil type:NSLibraryDirectory components:nil];
    expectedLocation = [expectedLocation stringByAppendingPathComponent:@"UserAccount.plist"];
    XCTAssertEqualObjects(expectedLocation, [SFDefaultUserAccountPersister userAccountPlistFileForUser:user], @"Mismatching user account paths");
    NSFileManager *fm = [NSFileManager defaultManager];
    XCTAssertTrue([fm fileExistsAtPath:expectedLocation], @"Unable to find new UserAccount.plist");

    NSString *userId = [NSString stringWithFormat:kUserIdFormatString, (unsigned long)0];
    XCTAssertEqualObjects(((SFUserAccountIdentity *)self.uam.allUserIdentities[0]).userId, userId, @"User ID doesn't match after reload");
     [self deleteUserAndVerify:user userDir:expectedLocation];
}

- (void)testMultipleAccounts {
    // Ensure we start with a clean state
    XCTAssertEqual([self.uam.allUserIdentities count], (NSUInteger)0, @"There should be no accounts");

    // Create 10 users
    [self createAndVerifyUserAccounts:10];
    NSFileManager *fm = [NSFileManager defaultManager];

    // Ensure all directories have been correctly created
    {
        for (NSUInteger index=0; index<10; index++) {
            NSString *orgId = [NSString stringWithFormat:kOrgIdFormatString, (unsigned long)index];
            NSString *userId = [NSString stringWithFormat:kUserIdFormatString, (unsigned long)index];
            NSString *location = [[SFDirectoryManager sharedManager] directoryForOrg:orgId user:userId community:nil type:NSLibraryDirectory components:nil];
            location = [location stringByAppendingPathComponent:@"UserAccount.plist"];
            XCTAssertTrue([fm fileExistsAtPath:location], @"Unable to find new UserAccount.plist at %@", location);
        }
    }
    
    // Remove and verify that allUserAccounts property implicitly loads the accounts from disk.
    [self.uam clearAllAccountState];
    NSError *error =nil;
    [self.uam loadAccounts:&error];
    XCTAssertNil(error, @"Accounts should have been loaded");
    // Now make sure each account has a different access token to ensure
    // they are not overlapping in the keychain.
    NSMutableSet *allTokens = [NSMutableSet new];
    NSArray *allIdentities = self.uam.allUserIdentities;
    for (NSUInteger index=0; index<10; index++) {
        SFUserAccount *user = [self.uam userAccountForUserIdentity:allIdentities[index]];
        if (![allTokens containsObject:user.credentials.accessToken]) {
            [allTokens addObject:user.credentials.accessToken];
        }
    }
    XCTAssertEqual(allTokens.count,10, @"Should not contain overlapping tokens");
    
    // Remove each account and verify that its user folder is gone.
    for (NSUInteger index = 0; index < 10; index++) {
        NSString *orgId = [NSString stringWithFormat:kOrgIdFormatString, (unsigned long)index];
        NSString *userId = [NSString stringWithFormat:kUserIdFormatString, (unsigned long)index];
        NSString *location = [[SFDirectoryManager sharedManager] directoryForOrg:orgId user:userId community:nil type:NSLibraryDirectory components:nil];
        SFUserAccountIdentity *accountIdentity = [[SFUserAccountIdentity alloc] initWithUserId:userId orgId:orgId];
        
        SFUserAccount *userAccount = [self.uam userAccountForUserIdentity:accountIdentity];
        XCTAssertNotNil(userAccount, @"User acccount with User ID '%@' and Org ID '%@' should exist.", userId, orgId);
        XCTAssertTrue([fm fileExistsAtPath:location], @"User directory for User ID '%@' and Org ID '%@' should exist.", userId, orgId);
        
        [self deleteUserAndVerify:userAccount userDir:location];
    }
     XCTAssertEqual([self.uam allUserAccounts].count, (NSUInteger)0, @"There should be 0 accounts after delete");
}

- (void)testSwitchToUser {
    NSArray *accounts = [self createAndVerifyUserAccounts:2];
    SFUserAccount *origUser = accounts[0];
    SFUserAccount *newUser = accounts[1];
    [[SFUserAccountManager sharedInstance] setCurrentUserInternal:origUser];
    TestUserAccountManagerDelegate *acctDelegate = [[TestUserAccountManagerDelegate alloc] init];
    [self.uam switchToUser:newUser];
    XCTAssertEqual(acctDelegate.willSwitchOrigUserAccount, origUser, @"origUser is not equal.");
    XCTAssertEqual(acctDelegate.willSwitchNewUserAccount, newUser, @"New user should be the same as the argument to switchToUser.");
    XCTAssertEqual(acctDelegate.didSwitchOrigUserAccount, origUser, @"origUser is not equal.");
    XCTAssertEqual(acctDelegate.didSwitchNewUserAccount, newUser, @"New user should be the same as the argument to switchToUser.");
    XCTAssertEqual(self.uam.currentUser, newUser, @"The current user should be set to newUser.");
}


- (void)testSwitchToNewUserNoCurrentUser {
    [self createAndVerifyUserAccounts:1];
    [[SFUserAccountManager sharedInstance] setCurrentUserInternal:nil];
    XCTestExpectation *switchExpectation = [self expectationWithDescription:@"testSwitchToNewUserWithCompletionErrorCase"];
    __block NSError *error = nil;
    [self.uam switchToNewUserWithCompletion:^(NSError * err, SFUserAccount * account) {
         error = err;
        [switchExpectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
    XCTAssertNotNil(error, @"switchToNewUserWithCompletion should not be called without a current user");
}

- (void)testLoginHostForSwitchToUser {
    [SFUserAccountManager sharedInstance].nativeLoginEnabled = NO;
    
    NSArray *accounts = [self createAndVerifyUserAccounts:2];
    SFUserAccount *origUser = accounts[0];
    self.uam.loginHost = @"my.prev.domain";
    SFUserAccount *newUser = accounts[1];
    NSString *testDomain = @"my.test.domain";
    newUser.credentials.domain = testDomain;
    [[SFUserAccountManager sharedInstance] setCurrentUserInternal:origUser];
    TestUserAccountManagerDelegate *acctDelegate = [[TestUserAccountManagerDelegate alloc] init];
    XCTAssertNotEqual(self.uam.loginHost, testDomain, @"The domains should be different before the test.");
    XCTAssertEqual(newUser.credentials.domain, testDomain, @"User domain should have been set in the credentials.");
    
    [self.uam switchToUser:newUser];
    XCTAssertEqual(acctDelegate.didSwitchOrigUserAccount, origUser, @"The user switched from is not the same user as expected.");
    XCTAssertEqual(acctDelegate.didSwitchNewUserAccount, newUser, @"The user switched to is not the same user as expected.");
    XCTAssertEqual(self.uam.currentUser, newUser, @"The current user should be set to the new user.");
    XCTAssertEqual(newUser.credentials.domain, testDomain, @"Switch user should not have changed users domain in credentials.");
    XCTAssertEqual(self.uam.loginHost, newUser.credentials.domain, @"Switch user should set current login host to users domain.");
}

- (void)testUserAccountManagerPersistentProperties {
    NSArray *oldAdditionalOAuthParameterKeys = [SFUserAccountManager sharedInstance].additionalOAuthParameterKeys;
    NSArray *addlKeys = @[@"A", @"__B", @"123", @""];
    [SFUserAccountManager sharedInstance].additionalOAuthParameterKeys = addlKeys;
    XCTAssertNotNil([SFUserAccountManager sharedInstance].additionalOAuthParameterKeys,"SFUserAccountManager additionalOAuthParameterKeys should not be nil");
    XCTAssertTrue([[SFUserAccountManager sharedInstance].additionalOAuthParameterKeys count] == [addlKeys count],"SFUserAccountManager additionalOAuthParameterKeys should not be nil");
    [SFUserAccountManager sharedInstance].additionalOAuthParameterKeys = oldAdditionalOAuthParameterKeys;
    
    NSDictionary *oldAdditionalTokenRefreshParams = [SFUserAccountManager sharedInstance].additionalTokenRefreshParams;
    NSDictionary *addlRefreshParams = @ {@"A":@"A",@"B":@"B", @"C":@"C"};
    [SFUserAccountManager sharedInstance].additionalTokenRefreshParams = addlRefreshParams;
    XCTAssertNotNil([SFUserAccountManager sharedInstance].additionalTokenRefreshParams,"SFUserAccountManager additionalTokenRefreshParams should not be nil");
    XCTAssertTrue([[SFUserAccountManager sharedInstance].additionalTokenRefreshParams count] == [addlRefreshParams count],"SFUserAccountManager additionalOAuthParameterKeys should not be nil");
    [SFUserAccountManager sharedInstance].additionalTokenRefreshParams = oldAdditionalTokenRefreshParams;
    
    NSString *oldLoginHost = [SFUserAccountManager sharedInstance].loginHost;
    NSString *newLoginHost = @"https://sample.test";
    [SFUserAccountManager sharedInstance].loginHost = newLoginHost;
    XCTAssertEqualObjects([SFUserAccountManager sharedInstance].loginHost, newLoginHost, @"SFUserAccountManager loginHost should be set correctly");
    [SFUserAccountManager sharedInstance].loginHost = oldLoginHost;
    XCTAssertEqualObjects([SFUserAccountManager sharedInstance].loginHost, oldLoginHost, @"SFUserAccountManager loginHost should be set back correctly");
    
    NSString *oldOauthCompletionUrl = [SFUserAccountManager sharedInstance].oauthCompletionUrl;
    NSString *newOauthCompletionUrl = @"new://new.url";
    [SFUserAccountManager sharedInstance].oauthCompletionUrl = newOauthCompletionUrl;
    XCTAssertEqualObjects([SFUserAccountManager sharedInstance].oauthCompletionUrl, newOauthCompletionUrl, @"SFUserAccountManager oauthCompletionUrl should be set correctly");
    [SFUserAccountManager sharedInstance].oauthCompletionUrl = oldOauthCompletionUrl;
    XCTAssertEqualObjects([SFUserAccountManager sharedInstance].oauthCompletionUrl, oldOauthCompletionUrl, @"SFUserAccountManager oauthCompletionUrl should be set back correctly");
    
    NSString *oldOauthClientId = [SFUserAccountManager sharedInstance].oauthClientId;
    NSString *newOauthClientId = @"NEW_OAUTH_CLIENT_ID";
    [SFUserAccountManager sharedInstance].oauthClientId = newOauthClientId;
    XCTAssertEqualObjects([SFUserAccountManager sharedInstance].oauthClientId, newOauthClientId, @"SFUserAccountManager oAuthClientId should be set correctly");
    [SFUserAccountManager sharedInstance].oauthClientId = oldOauthClientId;
    XCTAssertEqualObjects([SFUserAccountManager sharedInstance].oauthClientId, oldOauthClientId, @"SFUserAccountManager oAuthClientId should be set back correctly");
    
    NSString *oldBrandLoginPath = [SFUserAccountManager sharedInstance].brandLoginPath;
    NSString *newBrandLoginPath = @"NEW_BRAND";
    [SFUserAccountManager sharedInstance].brandLoginPath = newBrandLoginPath;
    XCTAssertEqualObjects([SFUserAccountManager sharedInstance].brandLoginPath, newBrandLoginPath, @"SFUserAccountManager brandLoginPath should be set correctly");
    [SFUserAccountManager sharedInstance].brandLoginPath = oldBrandLoginPath;
    XCTAssertEqualObjects([SFUserAccountManager sharedInstance].brandLoginPath, oldBrandLoginPath, @"SFUserAccountManager brandLoginPath should be set back correctly");
}

- (void)testLogin {
    
    SFOAuthCredentials *credentials = [self populateAuthCredentialsFromConfigFileForClass:self.class];
    XCTestExpectation *refreshExpectation = [self expectationWithDescription:@"refresh"];
    __block SFUserAccount *user = nil;
    [[SFUserAccountManager sharedInstance]
     refreshCredentials:credentials
     completion:^(SFOAuthInfo *authInfo, SFUserAccount *userAccount) {
         [refreshExpectation fulfill];
         user = userAccount;
     } failure:^(SFOAuthInfo *authInfo, NSError *error) {
     }];
   
    [self waitForExpectations:@[refreshExpectation] timeout:20];
    
}

- (void)testEntityId {
    NSString *userId = @"ABCDE12345ABCDE".sfsdk_entityId18;
    SFUserAccountIdentity *identity = [[SFUserAccountIdentity alloc] initWithUserId:userId  orgId:@"ABCDE12345ABCDE"];
    XCTAssertNotNil(identity);
    XCTAssertTrue(userId.length == 18,@"EntityId18 should not be nil");
    XCTAssertNotNil(identity.userId,@"userId should not be nil");
    XCTAssertNotNil(identity.orgId,@"orgId should not be nil");
    XCTAssertTrue(identity.userId.length == 18, @"userId should be set to EntityId 18 format");
}

- (void)testAuthHandler {
    SFSDKAuthViewHandler *origAuthViewHandler = [SFUserAccountManager sharedInstance].authViewHandler;
    XCTestExpectation *expectation = [self expectationWithDescription:@"testAuthHandler"];
    SFSDKAuthViewHandler *authViewHandler = [[SFSDKAuthViewHandler alloc] initWithDisplayBlock:^(SFSDKAuthViewHolder *holder) {
        [expectation fulfill];
    } dismissBlock:^{
        [expectation fulfill];
    }];
    [[SFUserAccountManager sharedInstance] setAuthViewHandler:authViewHandler];
    XCTAssertNotNil(authViewHandler);
    XCTAssertNotNil(authViewHandler.authViewDismissBlock);
    XCTAssertNotNil(authViewHandler.authViewDisplayBlock);
    XCTAssertTrue([SFUserAccountManager sharedInstance].authViewHandler == authViewHandler);
    SFSDKAuthRequest *request = [[SFUserAccountManager sharedInstance] defaultAuthRequest];
    request.oauthClientId = @"DUMMY_ID";
    request.oauthCompletionUrl = @"DUMMY_URL";
    request.loginHost = @"login.salesforce.com";
    
    SFSDKAuthSession *session = [[SFSDKAuthSession alloc] initWith:request credentials:nil];
    SFOAuthCoordinator *coordinator = [[SFOAuthCoordinator alloc] initWithAuthSession:session];
    coordinator.delegate = [SFUserAccountManager sharedInstance];
    [coordinator beginWebViewFlow];

    [self waitForExpectations:@[expectation] timeout:20];
    
    [SFUserAccountManager sharedInstance].authViewHandler = origAuthViewHandler;
}

- (void)testLoginViewControllerCustomizations {
    
    SFSDKLoginViewControllerConfig *config = [[SFSDKLoginViewControllerConfig alloc] init];
    
    //test defaults
    XCTAssertNotNil(config);
    XCTAssertNil(config.navBarFont);
    XCTAssertNotNil(config.navBarColor);
    XCTAssertTrue(config.showNavbar == YES);
    XCTAssertTrue(config.showSettingsIcon == YES);
    
    config.navBarColor = [UIColor redColor];
    config.navBarFont = [UIFont systemFontOfSize:10.0f];
    config.showNavbar = NO;
    config.showSettingsIcon = NO;
    __block BOOL success = NO;
    XCTestExpectation *expectation = [self expectationWithDescription:@"testConfig"];
    
    SFSDKAuthViewHandler *authViewHandler = [[SFSDKAuthViewHandler alloc] initWithDisplayBlock:^(SFSDKAuthViewHolder *holder) {
        success = [SFUserAccountManager sharedInstance].loginViewControllerConfig == holder.loginController.config;
        [expectation fulfill];
    } dismissBlock:^{
        [expectation fulfill];
    }];
    [[SFUserAccountManager sharedInstance] setAuthViewHandler:authViewHandler];
    
    XCTAssertTrue(config.navBarColor == [UIColor redColor], @"SFSDKLoginViewController config nav bar color should have changed" );
    XCTAssertTrue(config.navBarFont == [UIFont systemFontOfSize:10.0f], @"SFSDKLoginViewController config nav bar font should have changed" );
    XCTAssertFalse(config.showNavbar, @"SFSDKLoginViewController nav bar should have been disabled");
    XCTAssertFalse(config.showSettingsIcon, @"SFSDKLoginViewController nav bar settings icon should have been disabled");
    SFSDKAuthRequest *request = [[SFUserAccountManager sharedInstance] defaultAuthRequest];
    request.oauthClientId = @"DUMMY_ID";
    request.oauthCompletionUrl = @"DUMMY_URL";
    request.loginHost = @"login.salesforce.com";
    
    SFSDKAuthSession *session = [[SFSDKAuthSession alloc] initWith:request credentials:nil];
    SFOAuthCoordinator *coordinator = [[SFOAuthCoordinator alloc] initWithAuthSession:session];
    coordinator.delegate = [SFUserAccountManager sharedInstance];

    // Invoke the delegate directly — no WKWebView needed since this test only verifies
    // that loginViewControllerConfig propagates correctly to the presented controller.
    [[SFUserAccountManager sharedInstance] oauthCoordinator:coordinator didBeginAuthenticationWithView:coordinator.view];

    [self waitForExpectations:@[expectation] timeout:20];
    XCTAssertTrue(success, @"SFSDKLoginViewController config should have changed" );

}

#pragma mark - Helper methods

- (NSArray *)createAndVerifyUserAccounts:(NSUInteger)numAccounts {
    XCTAssertTrue(numAccounts > 0, @"You must create at least one account.");
    NSMutableArray *accounts = [NSMutableArray array];
    for (NSUInteger index = 0; index < numAccounts; index++) {
        SFUserAccount *user = [self createNewUserWithIndex:index];
        user.credentials.accessToken = [NSString stringWithFormat:@"accesstoken-%lu", (unsigned long)index];
        XCTAssertNotNil(user.credentials, @"User credentials shouldn't be nil");
        NSError *error = nil;
        [[SFUserAccountManager sharedInstance] saveAccountForUser:user error:&error];
        XCTAssertNil(error, @"Should be able to create user account");
        // Note: we always use index 0 because of the way the allUserIds are sorted out
        SFUserAccount *userAccount = [self.uam userAccountForUserIdentity:user.accountIdentity];
        XCTAssertEqualObjects(userAccount.accountIdentity.userId, ([NSString stringWithFormat:kUserIdFormatString, (unsigned long)index]), @"User ID doesn't match");
        XCTAssertEqualObjects(userAccount.accountIdentity.orgId, ([NSString stringWithFormat:kOrgIdFormatString, (unsigned long)index]), @"Org ID doesn't match");
        // Add to the output array.
        [accounts addObject:user];
    }
    
    return accounts;
}

- (SFUserAccount*)createNewUserWithIndex:(NSUInteger)index {
    XCTAssertTrue(index < 10, @"Supports only index up to 9");
    SFOAuthCredentials *credentials = [[SFOAuthCredentials alloc]initWithIdentifier:[NSString stringWithFormat:@"identifier-%lu", (unsigned long)index] clientId:@"fakeClientIdForTesting" encrypted:YES];
    SFUserAccount *user =[[SFUserAccount alloc] initWithCredentials:credentials];
    NSString *userId = [NSString stringWithFormat:kUserIdFormatString, (unsigned long)index];
    NSString *orgId = [NSString stringWithFormat:kOrgIdFormatString, (unsigned long)index];
    user.credentials.identityUrl = [NSURL URLWithString:[NSString stringWithFormat:@"https://login.salesforce.com/id/%@/%@", orgId, userId]];
    return user;
}

- (void)deleteUserAndVerify:(SFUserAccount *)user userDir:(NSString *)userDir {
    SFUserAccountIdentity *identity = user.accountIdentity;
    NSError *deleteAccountError = nil;
    [self.uam deleteAccountForUser:user error:&deleteAccountError];
    XCTAssertNil(deleteAccountError, @"Error deleting account with User ID '%@' and Org ID '%@': %@", identity.userId, identity.orgId, [deleteAccountError localizedDescription]);
    NSFileManager *fm = [NSFileManager defaultManager];
    XCTAssertFalse([fm fileExistsAtPath:userDir], @"User directory for User ID '%@' and Org ID '%@' should be removed.", identity.userId, identity.orgId);
    SFUserAccount *inMemoryAccount = [self.uam userAccountForUserIdentity:identity];
    XCTAssertNil(inMemoryAccount, @"deleteUser should have removed user account with User ID '%@' and OrgID '%@' from the list of users.", identity.userId, identity.orgId);
}

- (SFIdentityData *)sampleIdentityData {
    NSDictionary *sampleIdDataDict = @{
                                       @"mobile_phone" : @"+1 4155551234",
                                       @"first_name" : @"Test",
                                       @"mobile_phone_verified" : @YES,
                                       @"active" : @YES,
                                       @"utcOffset" : @(-28800000),
                                       @"username" : @"testuser@fake.salesforce.org",
                                       @"last_modified_date" : @"2013-04-19T22:12:04.000+0000",
                                       @"id" : @"https://test.salesforce.com/id/00DS0000000IDdtWAH/005S0000004y9JkCAF",
                                       @"locale" : @"en_US",
                                       @"urls" : @{
                                               @"users" : @"https://cs1.salesforce.com/services/data/v{version}/chatter/users",
                                               @"search" : @"https://cs1.salesforce.com/services/data/v{version}/search/",
                                               @"metadata" : @"https://cs1.salesforce.com/services/Soap/m/{version}/00DS0000000IDdt",
                                               @"query" : @"https://cs1.salesforce.com/services/data/v{version}/query/",
                                               @"enterprise" : @"https://cs1.salesforce.com/services/Soap/c/{version}/00DS0000000IDdt",
                                               @"profile" : @"https://cs1.salesforce.com/005S0000004y9JkCAF",
                                               @"sobjects" : @"https://cs1.salesforce.com/services/data/v{version}/sobjects/",
                                               @"groups" : @"https://cs1.salesforce.com/services/data/v{version}/chatter/groups",
                                               @"rest" : @"https://cs1.salesforce.com/services/data/v{version}/",
                                               @"feed_items" : @"https://cs1.salesforce.com/services/data/v{version}/chatter/feed-items",
                                               @"recent" : @"https://cs1.salesforce.com/services/data/v{version}/recent/",
                                               @"feeds" : @"https://cs1.salesforce.com/services/data/v{version}/chatter/feeds",
                                               @"partner" : @"https://cs1.salesforce.com/services/Soap/u/{version}/00DS0000000IDdt"
                                               },
                                       @"addr_zip" : @"94105",
                                       @"addr_country" : @"US",
                                       @"asserted_user" : @YES,
                                       @"email_verified" : @YES,
                                       @"nick_name" : @"testuser1.3664094337872896E12",
                                       @"user_id" : @"005S0000004y9JkCAF",
                                       @"is_app_installed" : @YES,
                                       @"user_type" : @"STANDARD",
                                       @"addr_street" : @"123 Test User Ln",
                                       @"timezone" : @"America/Los_Angeles",
                                       @"mobile_policy" : @{
                                               @"pin_length" : @"4",
                                               @"screen_lock" : @"10"
                                               },
                                       @"organization_id" : @"00DS0000000IDdtWAH",
                                       @"addr_city" : @"Testville",
                                       @"addr_state" : @"CA",
                                       @"language" : @"en_US",
                                       @"last_name" : @"User",
                                       @"display_name" : @"Test User",
                                       @"photos" : @{
                                               @"thumbnail" : @"https://c.cs1.content.force.com/profilephoto/729S00000009ZdF/T",
                                               @"picture" : @"https://c.cs1.content.force.com/profilephoto/729S00000009ZdF/F"
                                               },
                                       @"email" : @"testuser@salesforce.nonexistentemail",
                                       @"custom_attributes" : @{
                                               @"TestAttribute1" : @"TestVal1",
                                               @"TestAttribute2" : @"TestVal2"
                                               },
                                       @"custom_permissions": @{
                                               @"CustomPerm1" : @"CustomVal1",
                                               @"CustomPerm2" : @"CustomVal2"
                                               },
                                       @"status" : @{
                                               @"body" : [NSNull null],
                                               @"created_date" : [NSNull null]
                                               }
                                       };
    SFIdentityData *idData = [[SFIdentityData alloc] initWithJsonDict:sampleIdDataDict];
    return idData;
}

- (SFIdentityData *)sampleIdentityDataWithUserId:(NSString *)userId orgId:(NSString *)orgId {
    NSDictionary *identity = @{
        @"id": [NSString stringWithFormat:@"https://test.salesforce.com/id/%@/%@", orgId, userId],
        @"user_id": userId,
        @"organization_id": orgId,
        @"username": [NSString stringWithFormat:@"%@@example.com", userId],
        @"active": @YES,
        @"user_type": @"STANDARD",
        @"urls": @{},
        @"photos": @{}
    };
    return [[SFIdentityData alloc] initWithJsonDict:identity];
}

- (SFOAuthCredentials *)populateAuthCredentialsFromConfigFileForClass:(Class)testClass
{
    NSString *tokenPath = [[NSBundle bundleForClass:testClass] pathForResource:@"test_credentials" ofType:@"json"];
    NSAssert(nil != tokenPath, @"Test config file not found!");
    NSFileManager *fm = [NSFileManager defaultManager];
    NSData *tokenJson = [fm contentsAtPath:tokenPath];
    id jsonResponse = [SFJsonUtils objectFromJSONData:tokenJson];
    NSAssert(jsonResponse != nil, @"Error parsing JSON from config file: %@", [SFJsonUtils lastError]);
    NSDictionary *dictResponse = (NSDictionary *)jsonResponse;
    SFSDKTestCredentialsData *credsData = [[SFSDKTestCredentialsData alloc] initWithDict:dictResponse];
    NSAssert1(nil != credsData.refreshToken &&
              nil != credsData.clientId &&
              nil != credsData.redirectUri &&
              nil != credsData.loginHost &&
              nil != credsData.identityUrl &&
              nil != credsData.instanceUrl, @"config credentials are missing! %@",
              dictResponse);
    
    //check whether the test config file has never been edited
    NSAssert(![credsData.refreshToken isEqualToString:@"__INSERT_TOKEN_HERE__"],
             @"You need to obtain credentials for your test org and replace test_credentials.json");
    [[SFUserAccountManager sharedInstance] setCurrentUserInternal:nil];
    [SFUserAccountManager sharedInstance].oauthClientId = credsData.clientId;
    [SFUserAccountManager sharedInstance].oauthCompletionUrl = credsData.redirectUri;
    [SFUserAccountManager sharedInstance].scopes = [NSSet setWithObjects:@"web", @"api", nil];
    [SFUserAccountManager sharedInstance].loginHost = credsData.loginHost;
    SFOAuthCredentials *credentials = [TestSetupUtils newClientCredentials];
    credentials.instanceUrl = [NSURL URLWithString:credsData.instanceUrl];
    credentials.identityUrl = [NSURL URLWithString:credsData.identityUrl];
    NSString *communityUrlString = credsData.communityUrl;
    if (communityUrlString.length > 0) {
        credentials.communityUrl = [NSURL URLWithString:communityUrlString];
    }
    credentials.accessToken = credsData.accessToken;
    credentials.refreshToken = credsData.refreshToken;
    return credentials;
}

- (void)testUserAccountEncoding {
    NSData *data;
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initRequiringSecureCoding:YES];

    // Setup credentials
    SFOAuthCredentials *credentials = [[SFOAuthCredentials alloc] initWithIdentifier:[NSString stringWithFormat:@"identifier-%lu", (unsigned long)index] clientId:@"fakeClientIdForTesting" encrypted:YES];
    [credentials setIdentityUrl: [NSURL URLWithString:@"https://test.salesforce.com/id/00DS0000000IDdtWAH/005S0000004y9JkCAF"]];
    
    // Setup user
    SFUserAccount *userIn = [[SFUserAccount alloc] initWithCredentials:credentials];
    userIn.accessScopes = [NSSet setWithObjects:@"scope1", @"scope2", nil];
    userIn.idData = [self sampleIdentityData];
    [userIn setAccessRestrictions:SFUserAccountAccessRestrictionChatter];
    NSDictionary *customData = @{
        @"string": @"myString",
        @"number": @5,
        @"date": [NSDate now],
        @"null": [NSNull null],
        @"array": @[@"one", @"two"]
    };
    [userIn setCustomDataObject:customData forKey:@"allTheThings"];

    // Archive/unarchive
    [archiver encodeObject:userIn forKey:@"account"];
    [archiver finishEncoding];
    data = archiver.encodedData;
    
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:data error:nil];
    unarchiver.requiresSecureCoding = YES;
    SFUserAccount *userOut = [unarchiver decodeObjectOfClass:[SFUserAccount class] forKey:@"account"];
    
    XCTAssertNotNil(userOut, @"couldn't unarchive user account");
    XCTAssertNotNil(userOut.credentials, @"couldn't unarchive credentials");
    XCTAssertNotNil(userOut.idData, @"couldn't unarchive idData");
   
    XCTAssertEqualObjects(userIn.customData, userOut.customData, @"customData mismatch");
    XCTAssertEqual(userIn.accessScopes.count, userOut.accessScopes.count);
    XCTAssertEqual(userIn.accessRestrictions, userOut.accessRestrictions, @"accessRestrictions mismatch");
}

- (void)test_givenPersistedFeatureFlags_whenEncodeAndDecode_thenFlagsRoundtrip {
    SFOAuthCredentials *credentials = [[SFOAuthCredentials alloc] initWithIdentifier:@"identifier-ff-roundtrip"
                                                                            clientId:@"fakeClientIdForTesting"
                                                                           encrypted:NO];
    [credentials setIdentityUrl:[NSURL URLWithString:@"https://test.salesforce.com/id/00DS0000000IDdtWAH/005S0000004y9JkCAF"]];
    SFUserAccount *userIn = [[SFUserAccount alloc] initWithCredentials:credentials];
    userIn.persistedFeatureFlags = [NSSet setWithObjects:@"BW", @"QR", nil];

    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initRequiringSecureCoding:YES];
    [archiver encodeObject:userIn forKey:@"account"];
    [archiver finishEncoding];
    NSData *data = archiver.encodedData;

    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:data error:nil];
    unarchiver.requiresSecureCoding = YES;
    SFUserAccount *userOut = [unarchiver decodeObjectOfClass:[SFUserAccount class] forKey:@"account"];

    XCTAssertNotNil(userOut, @"Should unarchive successfully");
    XCTAssertEqual(userOut.persistedFeatureFlags.count, 2u, @"Should decode both feature flags");
    XCTAssertTrue([userOut.persistedFeatureFlags containsObject:@"BW"], @"BW flag should roundtrip");
    XCTAssertTrue([userOut.persistedFeatureFlags containsObject:@"QR"], @"QR flag should roundtrip");
}

- (void)test_givenOneAuthenticatingUnscopedSession_whenConnectedSceneAuthenticates_thenExistingSessionIsReassociated {
    SFSDKAuthGuardTestUserAccountManager *manager = [SFSDKAuthGuardTestUserAccountManager new];
    SFSDKAuthSession *session = [self authenticatingSessionForScene:nil];
    session.oauthRequest.oauthClientId = @"test-client-id";
    [session captureStandardWebAuthIntentWithLoginHint:nil frontDoorBridgeUrl:nil codeVerifier:nil];
    NSString *synthesizedSceneId = session.sceneId;
    void (^successCallback)(SFOAuthInfo *, SFUserAccount *) = ^(SFOAuthInfo *authInfo, SFUserAccount *account) {};
    void (^failureCallback)(SFOAuthInfo *, NSError *) = ^(SFOAuthInfo *authInfo, NSError *error) {};
    session.authSuccessCallback = successCallback;
    session.authFailureCallback = failureCallback;
    SFOAuthCoordinator *coordinator = session.oauthCoordinator;
    manager.authSessions[synthesizedSceneId] = session;
    UIScene *scene = [self sceneWithIdentifier:@"connected-scene"];

    BOOL result = [manager authenticateWithCompletion:nil failure:nil scene:scene];

    NSDictionary *sessions = manager.authSessions.dictionary;
    XCTAssertFalse(result, @"An in-flight pre-scene authentication should block a duplicate login");
    XCTAssertEqual(manager.authenticateWithRequestCallCount, 0u, @"A duplicate login should not create another auth session");
    XCTAssertEqual(sessions.count, 1u, @"Reassociation should retain exactly one auth session");
    XCTAssertNil(sessions[synthesizedSceneId], @"The synthesized key should be removed after reassociation");
    XCTAssertEqual(sessions[@"connected-scene"], session, @"The original session should move to the connected scene key");
    XCTAssertEqual(session.oauthRequest.scene, scene, @"The original request should be associated with the connected scene");
    XCTAssertEqualObjects(session.sceneId, @"connected-scene", @"Callback routing should use the connected scene identifier");
    XCTAssertEqual(session.oauthCoordinator, coordinator, @"Reassociation should preserve the original coordinator");
    XCTAssertEqual(session.authSuccessCallback, successCallback, @"Reassociation should preserve the success callback");
    XCTAssertEqual(session.authFailureCallback, failureCallback, @"Reassociation should preserve the failure callback");
}

- (void)test_givenMismatchedUnscopedStandardWebIntent_whenConnectedSceneAuthenticates_thenDuplicateIsBlockedWithoutReassociation {
    NSArray<NSDictionary *> *cases = @[
        @{ @"name": @"login host", @"usesBridge": @NO },
        @{ @"name": @"PKCE verifier", @"usesBridge": @YES }
    ];

    for (NSDictionary *testCase in cases) {
        SFSDKAuthGuardTestUserAccountManager *manager = [SFSDKAuthGuardTestUserAccountManager new];
        SFSDKAuthSession *session = [self authenticatingSessionForScene:nil];
        NSString *synthesizedSceneId = session.sceneId;
        __block NSUInteger originalCallbackCount = 0;
        __block NSUInteger incomingCallbackCount = 0;
        session.authSuccessCallback = ^(SFOAuthInfo *authInfo, SFUserAccount *account) {
            originalCallbackCount += 1;
        };
        manager.authSessions[synthesizedSceneId] = session;
        UIScene *scene = [self sceneWithIdentifier:@"connected-scene"];
        SFSDKAuthRequest *request = [self standardWebRequestForScene:scene];
        NSURL *bridgeURL = nil;
        NSString *codeVerifier = nil;
        if ([testCase[@"usesBridge"] boolValue]) {
            bridgeURL = [self frontDoorBridgeURLWithClientId:request.oauthClientId identifier:@"same"];
            session.oauthCoordinator.frontdoorBridgeLoginOverride = [[SFSDKAuthCoordinatorFrontdoorBridgeLoginOverride alloc]
                                                                       initWithFrontdoorBridgeUrl:bridgeURL
                                                                       codeVerifier:@"stored-verifier"];
            codeVerifier = @"different-verifier";
        } else {
            request.loginHost = @"test.salesforce.com";
        }

        BOOL blocked = [manager hasAuthenticatingSessionForScene:scene
                                                         request:request
                                                       loginHint:nil
                                              frontDoorBridgeUrl:bridgeURL
                                                    codeVerifier:codeVerifier
                                                      completion:^(SFOAuthInfo *authInfo, SFUserAccount *account) {
            incomingCallbackCount += 1;
        }
                                                         failure:nil];
        session.authSuccessCallback([[SFOAuthInfo alloc] initWithAuthType:SFOAuthTypeUserAgent], [SFUserAccount new]);

        NSDictionary<NSString *, SFSDKAuthSession *> *sessions = manager.authSessions.dictionary;
        XCTAssertTrue(blocked, @"%@ mismatch must remain a duplicate conflict", testCase[@"name"]);
        XCTAssertEqual(manager.authenticateWithRequestCallCount, 0u, @"%@ mismatch must not start another request", testCase[@"name"]);
        XCTAssertEqual(originalCallbackCount, 1u, @"%@ mismatch must preserve the original callback", testCase[@"name"]);
        XCTAssertEqual(incomingCallbackCount, 0u, @"%@ mismatch must not attach the incoming callback", testCase[@"name"]);
        XCTAssertEqual(sessions[synthesizedSceneId], session, @"%@ mismatch must preserve the synthesized-key mapping", testCase[@"name"]);
        XCTAssertNil(session.oauthRequest.scene, @"%@ mismatch must not claim the connected scene", testCase[@"name"]);
        XCTAssertEqualObjects(session.sceneId, synthesizedSceneId, @"%@ mismatch must preserve callback routing", testCase[@"name"]);
        XCTAssertNil(sessions[@"connected-scene"], @"%@ mismatch must leave the destination key empty", testCase[@"name"]);
    }
}

- (void)test_givenEquivalentStandardWebIntent_whenManagerGuardsDuplicate_thenCallbacksAreCoalesced {
    SFSDKAuthGuardTestUserAccountManager *manager = [SFSDKAuthGuardTestUserAccountManager new];
    UIScene *scene = [self sceneWithIdentifier:@"connected-scene"];
    SFSDKAuthSession *session = [self authenticatingSessionForScene:scene];
    NSString *originalConsumerKey = [SalesforceSDKManager sharedManager].appConfig.remoteAccessConsumerKey;
    [SalesforceSDKManager sharedManager].appConfig.remoteAccessConsumerKey = session.oauthRequest.oauthClientId;
    NSURL *bridgeURL = [self frontDoorBridgeURLWithClientId:session.oauthRequest.oauthClientId identifier:@"same"];
    session.oauthRequest.scopes = [NSSet setWithObjects:@"api", @"refresh_token", nil];
    session.oauthRequest.additionalOAuthParameterKeys = @[@"custom_parameter"];
    session.oauthRequest.additionalTokenRefreshParams = @{@"refresh_parameter": @"refresh_value"};
    session.oauthRequest.brandLoginPath = @"/brand";
    session.oauthRequest.retryLoginAfterFailure = YES;
    session.oauthRequest.useBrowserAuth = YES;
    session.oauthCoordinator.scopes = session.oauthRequest.scopes;
    session.oauthCoordinator.additionalOAuthParameterKeys = session.oauthRequest.additionalOAuthParameterKeys;
    session.oauthCoordinator.additionalTokenRefreshParams = session.oauthRequest.additionalTokenRefreshParams;
    session.oauthCoordinator.brandLoginPath = session.oauthRequest.brandLoginPath;
    session.oauthCoordinator.useBrowserAuth = YES;
    session.oauthCoordinator.loginHint = @"user@example.com";
    session.oauthCoordinator.frontdoorBridgeLoginOverride = [[SFSDKAuthCoordinatorFrontdoorBridgeLoginOverride alloc]
                                                               initWithFrontdoorBridgeUrl:bridgeURL
                                                               codeVerifier:@"verifier"];
    [session captureStandardWebAuthIntentWithLoginHint:session.oauthCoordinator.loginHint
                                    frontDoorBridgeUrl:bridgeURL
                                          codeVerifier:@"verifier"];
    manager.authSessions[session.sceneId] = session;
    SFSDKAuthRequest *request = [self standardWebRequestForScene:scene];
    request.scopes = [NSSet setWithObjects:@"refresh_token", @"api", nil];
    request.additionalOAuthParameterKeys = @[@"custom_parameter"];
    request.additionalTokenRefreshParams = @{@"refresh_parameter": @"refresh_value"};
    request.brandLoginPath = @"/brand";
    request.retryLoginAfterFailure = YES;
    request.useBrowserAuth = YES;
    __block NSUInteger callbackCount = 0;

    BOOL blocked = [manager hasAuthenticatingSessionForScene:scene
                                                     request:request
                                                   loginHint:@"user@example.com"
                                          frontDoorBridgeUrl:bridgeURL
                                                codeVerifier:@"verifier"
                                                  completion:^(SFOAuthInfo *authInfo, SFUserAccount *account) {
        callbackCount += 1;
    }
                                                     failure:nil];
    session.authSuccessCallback([[SFOAuthInfo alloc] initWithAuthType:SFOAuthTypeUserAgent], [SFUserAccount new]);
    [SalesforceSDKManager sharedManager].appConfig.remoteAccessConsumerKey = originalConsumerKey;

    XCTAssertTrue(blocked);
    XCTAssertEqual(manager.authenticateWithRequestCallCount, 0u);
    XCTAssertEqual(callbackCount, 1u, @"Equivalent value-based authentication intent should coalesce callbacks");
}

- (void)test_givenCapturedLoginHint_whenCoordinatorHintChanges_thenMatchingUsesOriginalHint {
    UIScene *scene = [self sceneWithIdentifier:@"connected-scene"];
    SFSDKAuthSession *session = [self authenticatingSessionForScene:scene];
    session.oauthCoordinator.loginHint = @"original@example.com";
    [session captureStandardWebAuthIntentWithLoginHint:session.oauthCoordinator.loginHint
                                    frontDoorBridgeUrl:nil
                                          codeVerifier:nil];
    SFSDKAuthRequest *request = [self standardWebRequestForScene:scene];

    session.oauthCoordinator.loginHint = @"discovered@example.com";

    XCTAssertFalse([session matchesStandardWebRequest:request
                                               loginHint:@"discovered@example.com"
                                      frontDoorBridgeUrl:nil
                                            codeVerifier:nil],
                   @"A coordinator hint discovered after startup must not redefine the original auth intent");
    XCTAssertTrue([session matchesStandardWebRequest:request
                                              loginHint:@"original@example.com"
                                     frontDoorBridgeUrl:nil
                                           codeVerifier:nil],
                  @"The original login hint must continue to identify the in-flight auth intent");
}

- (void)test_givenStandardWebIntent_whenLoginViewControllerConfigDiffers_thenOnlySameConfigMatches {
    UIScene *scene = [self sceneWithIdentifier:@"connected-scene"];
    SFSDKAuthSession *session = [self authenticatingSessionForScene:scene];
    SFSDKLoginViewControllerConfig *originalConfig = [SFSDKLoginViewControllerConfig new];
    session.oauthRequest.loginViewControllerConfig = originalConfig;
    [session captureStandardWebAuthIntentWithLoginHint:nil frontDoorBridgeUrl:nil codeVerifier:nil];
    SFSDKAuthRequest *sameConfigRequest = [self standardWebRequestForScene:scene];
    sameConfigRequest.loginViewControllerConfig = originalConfig;
    SFSDKAuthRequest *differentConfigRequest = [self standardWebRequestForScene:scene];
    differentConfigRequest.loginViewControllerConfig = [SFSDKLoginViewControllerConfig new];

    XCTAssertTrue([session matchesStandardWebRequest:sameConfigRequest
                                              loginHint:nil
                                     frontDoorBridgeUrl:nil
                                           codeVerifier:nil]);
    XCTAssertFalse([session matchesStandardWebRequest:differentConfigRequest
                                               loginHint:nil
                                      frontDoorBridgeUrl:nil
                                            codeVerifier:nil],
                   @"A distinct login view configuration must not coalesce with the in-flight request");
}

- (void)test_givenCapturedLoginViewControllerConfig_whenConfigMutates_thenOriginalIntentDoesNotChange {
    UIScene *scene = [self sceneWithIdentifier:@"connected-scene"];
    SFSDKAuthSession *session = [self authenticatingSessionForScene:scene];
    SFSDKLoginViewControllerConfig *config = [SFSDKLoginViewControllerConfig new];
    session.oauthRequest.loginViewControllerConfig = config;
    [session captureStandardWebAuthIntentWithLoginHint:nil frontDoorBridgeUrl:nil codeVerifier:nil];
    SFSDKAuthRequest *request = [self standardWebRequestForScene:scene];
    request.loginViewControllerConfig = config;

    config.showServerPicker = !config.showServerPicker;

    XCTAssertFalse([session matchesStandardWebRequest:request
                                               loginHint:nil
                                      frontDoorBridgeUrl:nil
                                            codeVerifier:nil],
                   @"Mutating the retained config must not mutate the captured auth intent");
}

- (void)test_givenStandardWebIntent_whenGlobalPoliciesDiffer_thenOnlyEquivalentPoliciesMatch {
    SalesforceSDKManager *sdkManager = [SalesforceSDKManager sharedManager];
    SFUserAccountManager *userAccountManager = [SFUserAccountManager sharedInstance];
    BOOL originalForceAdvancedAuthentication = sdkManager.sdk_forceAdvancedAuthentication;
    BOOL originalEphemeralSession = sdkManager.useEphemeralSessionForAdvancedAuth;
    BOOL originalWebServerAuthentication = sdkManager.useWebServerAuthentication;
    BOOL originalHybridAuthentication = sdkManager.useHybridAuthentication;
    BOOL originalDPoP = sdkManager.useDPoP;
    BOOL originalAppAttestation = userAccountManager.appAttestationEnabled;
    [self addTeardownBlock:^{
        sdkManager.sdk_forceAdvancedAuthentication = originalForceAdvancedAuthentication;
        sdkManager.useEphemeralSessionForAdvancedAuth = originalEphemeralSession;
        sdkManager.useWebServerAuthentication = originalWebServerAuthentication;
        sdkManager.useHybridAuthentication = originalHybridAuthentication;
        sdkManager.useDPoP = originalDPoP;
        userAccountManager.appAttestationEnabled = originalAppAttestation;
    }];
    sdkManager.sdk_forceAdvancedAuthentication = NO;
    sdkManager.useEphemeralSessionForAdvancedAuth = YES;
    sdkManager.useWebServerAuthentication = YES;
    sdkManager.useHybridAuthentication = YES;
    sdkManager.useDPoP = NO;
    userAccountManager.appAttestationEnabled = NO;
    UIScene *scene = [self sceneWithIdentifier:@"connected-scene"];
    SFSDKAuthSession *session = [self authenticatingSessionForScene:scene];
    SFSDKAuthRequest *request = [self standardWebRequestForScene:scene];

    XCTAssertTrue([session matchesStandardWebRequest:request
                                              loginHint:nil
                                     frontDoorBridgeUrl:nil
                                           codeVerifier:nil]);

    sdkManager.sdk_forceAdvancedAuthentication = YES;
    XCTAssertFalse([session matchesStandardWebRequest:request
                                               loginHint:nil
                                      frontDoorBridgeUrl:nil
                                            codeVerifier:nil],
                   @"Changing forced advanced authentication must produce a distinct auth intent");

    sdkManager.sdk_forceAdvancedAuthentication = NO;
    sdkManager.useEphemeralSessionForAdvancedAuth = NO;
    XCTAssertFalse([session matchesStandardWebRequest:request
                                               loginHint:nil
                                      frontDoorBridgeUrl:nil
                                            codeVerifier:nil],
                    @"Changing ephemeral browser policy must produce a distinct auth intent");

    sdkManager.useEphemeralSessionForAdvancedAuth = YES;
    sdkManager.useWebServerAuthentication = NO;
    XCTAssertFalse([session matchesStandardWebRequest:request
                                               loginHint:nil
                                      frontDoorBridgeUrl:nil
                                            codeVerifier:nil],
                   @"Changing web-server authentication must produce a distinct auth intent");

    sdkManager.useWebServerAuthentication = YES;
    sdkManager.useHybridAuthentication = NO;
    XCTAssertFalse([session matchesStandardWebRequest:request
                                               loginHint:nil
                                      frontDoorBridgeUrl:nil
                                            codeVerifier:nil],
                   @"Changing hybrid authentication must produce a distinct auth intent");

    sdkManager.useHybridAuthentication = YES;
    sdkManager.useDPoP = YES;
    XCTAssertFalse([session matchesStandardWebRequest:request
                                               loginHint:nil
                                      frontDoorBridgeUrl:nil
                                            codeVerifier:nil],
                   @"Changing DPoP must produce a distinct auth intent");

    sdkManager.useDPoP = NO;
    userAccountManager.appAttestationEnabled = YES;
    XCTAssertFalse([session matchesStandardWebRequest:request
                                               loginHint:nil
                                      frontDoorBridgeUrl:nil
                                            codeVerifier:nil],
                   @"Changing app attestation must produce a distinct auth intent");

    userAccountManager.appAttestationEnabled = NO;
    XCTAssertTrue([session matchesStandardWebRequest:request
                                              loginHint:nil
                                     frontDoorBridgeUrl:nil
                                           codeVerifier:nil],
                  @"Restoring equivalent global policies must restore an equivalent auth intent");
}

- (void)test_givenCapturedStandardWebIntent_whenRuntimeSelectorIdentityChanges_thenRequestDoesNotMatch {
    SalesforceSDKManager *sdkManager = [SalesforceSDKManager sharedManager];
    SFSDKAppConfigRuntimeSelectorBlock originalSelector = sdkManager.appConfigRuntimeSelectorBlock;
    [self addTeardownBlock:^{
        sdkManager.appConfigRuntimeSelectorBlock = originalSelector;
    }];
    SFSDKAppConfig *appConfig = sdkManager.appConfig;
    SFSDKAppConfigRuntimeSelectorBlock firstSelector = ^(NSString *loginHost, void (^callback)(SFSDKAppConfig *)) {
        callback(appConfig);
    };
    sdkManager.appConfigRuntimeSelectorBlock = firstSelector;
    UIScene *scene = [self sceneWithIdentifier:@"connected-scene"];
    SFSDKAuthSession *session = [self authenticatingSessionForScene:scene];
    SFSDKAuthRequest *request = [self standardWebRequestForScene:scene];
    XCTAssertTrue([session matchesStandardWebRequest:request loginHint:nil frontDoorBridgeUrl:nil codeVerifier:nil]);

    sdkManager.appConfigRuntimeSelectorBlock = ^(NSString *loginHost, void (^callback)(SFSDKAppConfig *)) {
        callback(appConfig);
    };

    XCTAssertFalse([session matchesStandardWebRequest:request loginHint:nil frontDoorBridgeUrl:nil codeVerifier:nil],
                   @"Changing the runtime boot-config selector while config is pending must prevent callback coalescing");
}

- (void)test_givenStandardWebIntent_whenWebViewPoliciesDiffer_thenOnlyEquivalentPoliciesMatch {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    SalesforceSDKManager *sdkManager = [SalesforceSDKManager sharedManager];
    SFUserAccountManager *userAccountManager = [SFUserAccountManager sharedInstance];
    WKNavigationActionPolicy (^originalNavigationPolicy)(WKWebView *, WKNavigationAction *) = userAccountManager.navigationPolicyForAction;
    WKWebView *(^originalCreateWebview)(WKWebView *, WKWebViewConfiguration *, WKNavigationAction *, WKWindowFeatures *) = userAccountManager.createWebview;
    BOOL originalShowAuthWindowWhileLoading = userAccountManager.showAuthWindowWhileLoading;
    BOOL originalLoginWebviewInspectable = sdkManager.isLoginWebviewInspectable;
    [self addTeardownBlock:^{
        userAccountManager.navigationPolicyForAction = originalNavigationPolicy;
        userAccountManager.createWebview = originalCreateWebview;
        userAccountManager.showAuthWindowWhileLoading = originalShowAuthWindowWhileLoading;
        sdkManager.isLoginWebviewInspectable = originalLoginWebviewInspectable;
    }];
    WKNavigationActionPolicy (^navigationPolicy)(WKWebView *, WKNavigationAction *) = ^WKNavigationActionPolicy(WKWebView *webView, WKNavigationAction *action) {
        return WKNavigationActionPolicyAllow;
    };
    WKWebView *(^createWebview)(WKWebView *, WKWebViewConfiguration *, WKNavigationAction *, WKWindowFeatures *) = ^WKWebView *(WKWebView *webView, WKWebViewConfiguration *configuration, WKNavigationAction *action, WKWindowFeatures *features) {
        return nil;
    };
    userAccountManager.navigationPolicyForAction = navigationPolicy;
    userAccountManager.createWebview = createWebview;
    userAccountManager.showAuthWindowWhileLoading = YES;
    sdkManager.isLoginWebviewInspectable = NO;
    UIScene *scene = [self sceneWithIdentifier:@"connected-scene"];
    SFSDKAuthSession *session = [self authenticatingSessionForScene:scene];
    SFSDKAuthRequest *request = [self standardWebRequestForScene:scene];

    XCTAssertTrue([session matchesStandardWebRequest:request loginHint:nil frontDoorBridgeUrl:nil codeVerifier:nil]);

    userAccountManager.navigationPolicyForAction = ^WKNavigationActionPolicy(WKWebView *webView, WKNavigationAction *action) {
        return WKNavigationActionPolicyAllow;
    };
    XCTAssertFalse([session matchesStandardWebRequest:request loginHint:nil frontDoorBridgeUrl:nil codeVerifier:nil],
                   @"A different navigation-policy block must not coalesce");

    userAccountManager.navigationPolicyForAction = navigationPolicy;
    userAccountManager.createWebview = ^WKWebView *(WKWebView *webView, WKWebViewConfiguration *configuration, WKNavigationAction *action, WKWindowFeatures *features) {
        return nil;
    };
    XCTAssertFalse([session matchesStandardWebRequest:request loginHint:nil frontDoorBridgeUrl:nil codeVerifier:nil],
                   @"A different WebView-creation block must not coalesce");

    userAccountManager.createWebview = createWebview;
    userAccountManager.showAuthWindowWhileLoading = NO;
    XCTAssertFalse([session matchesStandardWebRequest:request loginHint:nil frontDoorBridgeUrl:nil codeVerifier:nil],
                   @"A different auth-window loading policy must not coalesce");

    userAccountManager.showAuthWindowWhileLoading = YES;
    sdkManager.isLoginWebviewInspectable = YES;
    XCTAssertFalse([session matchesStandardWebRequest:request loginHint:nil frontDoorBridgeUrl:nil codeVerifier:nil],
                   @"A different WebView inspectability policy must not coalesce");

    sdkManager.isLoginWebviewInspectable = NO;
    XCTAssertTrue([session matchesStandardWebRequest:request loginHint:nil frontDoorBridgeUrl:nil codeVerifier:nil],
                  @"Restoring the same callback identities and flag values must coalesce");
#pragma clang diagnostic pop
}

- (void)test_givenSessionCompletesDuringDuplicateCallbackRegistration_whenManagerGuardsDuplicate_thenTerminalCallbackRunsAfterAccountsLockIsReleased {
    SFSDKAuthGuardTestUserAccountManager *manager = [SFSDKAuthGuardTestUserAccountManager new];
    UIScene *scene = [self sceneWithIdentifier:@"connected-scene"];
    SFSDKAuthRequest *storedRequest = [self standardWebRequestForScene:scene];
    SFSDKTerminalDuringCallbackRegistrationAuthSession *session = [[SFSDKTerminalDuringCallbackRegistrationAuthSession alloc]
                                                                    initWith:storedRequest
                                                                    credentials:nil];
    [session captureStandardWebAuthIntentWithLoginHint:nil frontDoorBridgeUrl:nil codeVerifier:nil];
    session.isAuthenticating = YES;
    session.completionAuthInfo = [[SFOAuthInfo alloc] initWithAuthType:SFOAuthTypeUserAgent];
    session.completionUserAccount = [SFUserAccount new];
    manager.authSessions[session.sceneId] = session;
    SFSDKAuthRequest *incomingRequest = [self standardWebRequestForScene:scene];
    __block BOOL callbackObservedAccountsLockAvailable = NO;

    BOOL blocked = [manager hasAuthenticatingSessionForScene:scene
                                                     request:incomingRequest
                                                   loginHint:nil
                                          frontDoorBridgeUrl:nil
                                                codeVerifier:nil
                                                  completion:^(SFOAuthInfo *authInfo, SFUserAccount *account) {
        callbackObservedAccountsLockAvailable = [manager isAccountsLockAvailableFromAnotherThread];
    }
                                                     failure:nil];

    XCTAssertTrue(blocked);
    XCTAssertTrue(callbackObservedAccountsLockAvailable, @"A terminal callback must not execute while the manager account lock is held");
}

- (void)test_givenDifferentStandardWebIntent_whenManagerGuardsDuplicate_thenDuplicateIsBlockedWithoutCoalescingCallbacks {
    typedef void (^SFSDKAuthIntentMutation)(SFSDKAuthRequest *, NSString **, NSURL **, NSString **);
    NSArray<NSDictionary *> *cases = @[
        @{@"name": @"login host", @"mutate": [^(SFSDKAuthRequest *request, NSString **hint, NSURL **bridge, NSString **verifier) { request.loginHost = @"test.salesforce.com"; } copy]},
        @{@"name": @"login hint", @"mutate": [^(SFSDKAuthRequest *request, NSString **hint, NSURL **bridge, NSString **verifier) { *hint = @"other@example.com"; } copy]},
        @{@"name": @"bridge URL", @"mutate": [^(SFSDKAuthRequest *request, NSString **hint, NSURL **bridge, NSString **verifier) { *bridge = [self frontDoorBridgeURLWithClientId:request.oauthClientId identifier:@"other"]; } copy]},
        @{@"name": @"PKCE verifier", @"mutate": [^(SFSDKAuthRequest *request, NSString **hint, NSURL **bridge, NSString **verifier) { *verifier = @"other-verifier"; } copy]},
        @{@"name": @"OAuth client ID", @"mutate": [^(SFSDKAuthRequest *request, NSString **hint, NSURL **bridge, NSString **verifier) { request.oauthClientId = @"other-client-id"; } copy]},
        @{@"name": @"completion URL", @"mutate": [^(SFSDKAuthRequest *request, NSString **hint, NSURL **bridge, NSString **verifier) { request.oauthCompletionUrl = @"otherapp://callback"; } copy]},
        @{@"name": @"scopes", @"mutate": [^(SFSDKAuthRequest *request, NSString **hint, NSURL **bridge, NSString **verifier) { request.scopes = [NSSet setWithObject:@"web"]; } copy]},
        @{@"name": @"additional OAuth parameter keys", @"mutate": [^(SFSDKAuthRequest *request, NSString **hint, NSURL **bridge, NSString **verifier) { request.additionalOAuthParameterKeys = @[@"other_parameter"]; } copy]},
        @{@"name": @"additional token refresh parameters", @"mutate": [^(SFSDKAuthRequest *request, NSString **hint, NSURL **bridge, NSString **verifier) { request.additionalTokenRefreshParams = @{@"refresh_parameter": @"other_value"}; } copy]},
        @{@"name": @"brand path", @"mutate": [^(SFSDKAuthRequest *request, NSString **hint, NSURL **bridge, NSString **verifier) { request.brandLoginPath = @"/other-brand"; } copy]},
        @{@"name": @"retry login after failure", @"mutate": [^(SFSDKAuthRequest *request, NSString **hint, NSURL **bridge, NSString **verifier) { request.retryLoginAfterFailure = NO; } copy]},
        @{@"name": @"browser auth", @"mutate": [^(SFSDKAuthRequest *request, NSString **hint, NSURL **bridge, NSString **verifier) { request.useBrowserAuth = YES; } copy]},
        @{@"name": @"Login for Admin", @"mutate": [^(SFSDKAuthRequest *request, NSString **hint, NSURL **bridge, NSString **verifier) { request.loginAsAdmin = YES; } copy]},
        @{@"name": @"Login for Admin My Domain", @"mutate": [^(SFSDKAuthRequest *request, NSString **hint, NSURL **bridge, NSString **verifier) { request.loginAsAdmin = YES; request.loginAsAdminMyDomain = @"admin.my.salesforce.com"; } copy]},
        @{@"name": @"Login for Admin hint", @"mutate": [^(SFSDKAuthRequest *request, NSString **hint, NSURL **bridge, NSString **verifier) { request.loginAsAdmin = YES; request.loginAsAdminLoginHint = @"admin@example.com"; } copy]}
    ];
    NSString *originalConsumerKey = [SalesforceSDKManager sharedManager].appConfig.remoteAccessConsumerKey;
    [SalesforceSDKManager sharedManager].appConfig.remoteAccessConsumerKey = @"testClientId";

    for (NSDictionary *testCase in cases) {
        SFSDKAuthGuardTestUserAccountManager *manager = [SFSDKAuthGuardTestUserAccountManager new];
        UIScene *scene = [self sceneWithIdentifier:@"connected-scene"];
        SFSDKAuthSession *session = [self authenticatingSessionForScene:scene];
        session.authSuccessCallback = ^(SFOAuthInfo *authInfo, SFUserAccount *account) {};
        session.oauthRequest.scopes = [NSSet setWithObjects:@"api", @"refresh_token", nil];
        session.oauthRequest.additionalOAuthParameterKeys = @[@"custom_parameter"];
        session.oauthRequest.additionalTokenRefreshParams = @{@"refresh_parameter": @"refresh_value"};
        session.oauthRequest.brandLoginPath = @"/brand";
        session.oauthRequest.retryLoginAfterFailure = YES;
        session.oauthCoordinator.scopes = session.oauthRequest.scopes;
        session.oauthCoordinator.additionalOAuthParameterKeys = session.oauthRequest.additionalOAuthParameterKeys;
        session.oauthCoordinator.additionalTokenRefreshParams = session.oauthRequest.additionalTokenRefreshParams;
        session.oauthCoordinator.brandLoginPath = session.oauthRequest.brandLoginPath;
        session.oauthCoordinator.loginHint = @"user@example.com";
        NSURL *storedBridgeURL = [self frontDoorBridgeURLWithClientId:session.oauthRequest.oauthClientId identifier:@"same"];
        session.oauthCoordinator.frontdoorBridgeLoginOverride = [[SFSDKAuthCoordinatorFrontdoorBridgeLoginOverride alloc]
                                                                   initWithFrontdoorBridgeUrl:storedBridgeURL
                                                                   codeVerifier:@"verifier"];
        [session captureStandardWebAuthIntentWithLoginHint:session.oauthCoordinator.loginHint
                                        frontDoorBridgeUrl:storedBridgeURL
                                              codeVerifier:@"verifier"];
        manager.authSessions[session.sceneId] = session;
        SFSDKAuthRequest *request = [self standardWebRequestForScene:scene];
        request.scopes = [NSSet setWithObjects:@"refresh_token", @"api", nil];
        request.additionalOAuthParameterKeys = @[@"custom_parameter"];
        request.additionalTokenRefreshParams = @{@"refresh_parameter": @"refresh_value"};
        request.brandLoginPath = @"/brand";
        request.retryLoginAfterFailure = YES;
        NSString *loginHint = @"user@example.com";
        NSURL *bridgeURL = storedBridgeURL;
        NSString *codeVerifier = @"verifier";
        SFSDKAuthIntentMutation mutation = testCase[@"mutate"];
        mutation(request, &loginHint, &bridgeURL, &codeVerifier);
        __block NSUInteger callbackCount = 0;

        BOOL blocked = [manager hasAuthenticatingSessionForScene:scene
                                                         request:request
                                                       loginHint:loginHint
                                              frontDoorBridgeUrl:bridgeURL
                                                    codeVerifier:codeVerifier
                                                      completion:^(SFOAuthInfo *authInfo, SFUserAccount *account) {
            callbackCount += 1;
        }
                                                         failure:nil];
        session.authSuccessCallback([[SFOAuthInfo alloc] initWithAuthType:SFOAuthTypeUserAgent], [SFUserAccount new]);

        XCTAssertTrue(blocked, @"%@ must remain blocked", testCase[@"name"]);
        XCTAssertEqual(manager.authenticateWithRequestCallCount, 0u, @"%@ must not start another request", testCase[@"name"]);
        XCTAssertEqual(callbackCount, 0u, @"%@ must not coalesce callbacks", testCase[@"name"]);
    }
    [SalesforceSDKManager sharedManager].appConfig.remoteAccessConsumerKey = originalConsumerKey;
}

- (void)test_givenInvalidRawBridgeIntent_whenNormalLoginIsActive_thenDuplicateIsBlockedWithoutCoalescingCallbacks {
    SFSDKAuthGuardTestUserAccountManager *manager = [SFSDKAuthGuardTestUserAccountManager new];
    UIScene *scene = [self sceneWithIdentifier:@"connected-scene"];
    SFSDKAuthSession *session = [self authenticatingSessionForScene:scene];
    session.authSuccessCallback = ^(SFOAuthInfo *authInfo, SFUserAccount *account) {};
    session.oauthCoordinator.loginHint = nil;
    manager.authSessions[session.sceneId] = session;
    SFSDKAuthRequest *request = [self standardWebRequestForScene:scene];
    NSURL *invalidBridgeURL = [self frontDoorBridgeURLWithClientId:@"mismatched-client-id" identifier:@"invalid"];
    __block NSUInteger callbackCount = 0;

    BOOL blocked = [manager hasAuthenticatingSessionForScene:scene
                                                     request:request
                                                   loginHint:nil
                                          frontDoorBridgeUrl:invalidBridgeURL
                                                codeVerifier:@"verifier"
                                                  completion:^(SFOAuthInfo *authInfo, SFUserAccount *account) {
        callbackCount += 1;
    }
                                                     failure:nil];
    session.authSuccessCallback([[SFOAuthInfo alloc] initWithAuthType:SFOAuthTypeUserAgent], [SFUserAccount new]);

    XCTAssertTrue(blocked);
    XCTAssertEqual(manager.authenticateWithRequestCallCount, 0u);
    XCTAssertEqual(callbackCount, 0u, @"A rejected raw bridge request must not receive a normal login's callback");
}

- (void)test_givenOneAuthenticatingUnscopedSession_whenAuthHelperLogsInForConnectedScene_thenExistingSessionIsNotStopped {
    SFSDKAuthGuardTestUserAccountManager *manager = [SFSDKAuthGuardTestUserAccountManager new];
    SFSDKAuthSession *session = [self authenticatingSessionForScene:nil];
    session.oauthRequest.oauthClientId = @"test-client-id";
    NSString *originalConsumerKey = [SalesforceSDKManager sharedManager].appConfig.remoteAccessConsumerKey;
    [SalesforceSDKManager sharedManager].appConfig.remoteAccessConsumerKey = session.oauthRequest.oauthClientId;
    NSURL *bridgeURL = [self frontDoorBridgeURLWithClientId:session.oauthRequest.oauthClientId identifier:@"auth-helper"];
    session.oauthCoordinator.loginHint = nil;
    session.oauthCoordinator.frontdoorBridgeLoginOverride = [[SFSDKAuthCoordinatorFrontdoorBridgeLoginOverride alloc]
                                                               initWithFrontdoorBridgeUrl:bridgeURL
                                                               codeVerifier:@"test-code-verifier"];
    [session captureStandardWebAuthIntentWithLoginHint:nil
                                    frontDoorBridgeUrl:bridgeURL
                                          codeVerifier:@"test-code-verifier"];
    NSString *synthesizedSceneId = session.sceneId;
    manager.authSessions[synthesizedSceneId] = session;
    UIScene *scene = [self sceneWithIdentifier:@"connected-scene"];

    [SFSDKAuthHelper attemptLoginWithAccountManager:manager
                                             scene:scene
                                         loginHint:nil
                                         loginHost:nil
                                frontDoorBridgeUrl:bridgeURL
                                      codeVerifier:@"test-code-verifier"
                                        completion:nil];
    [SalesforceSDKManager sharedManager].appConfig.remoteAccessConsumerKey = originalConsumerKey;

    NSDictionary *sessions = manager.authSessions.dictionary;
    XCTAssertEqual(manager.stopCurrentAuthenticationCallCount, 0u, @"AuthHelper should not cancel an authentication that is already in progress");
    XCTAssertEqual(manager.authenticateWithRequestCallCount, 0u, @"AuthHelper should not start a replacement authentication");
    XCTAssertEqual(sessions.count, 1u);
    XCTAssertEqual(sessions[@"connected-scene"], session);
    XCTAssertEqual(session.oauthRequest.scene, scene);
}

- (void)test_givenOneAuthenticatingUnscopedSession_whenAuthHelperLogsIn_thenCompletionIsAttachedToExistingSession {
    SFSDKAuthGuardTestUserAccountManager *manager = [SFSDKAuthGuardTestUserAccountManager new];
    SFSDKAuthSession *session = [self authenticatingSessionForScene:nil];
    session.oauthRequest.oauthClientId = @"test-client-id";
    NSString *originalConsumerKey = [SalesforceSDKManager sharedManager].appConfig.remoteAccessConsumerKey;
    [SalesforceSDKManager sharedManager].appConfig.remoteAccessConsumerKey = session.oauthRequest.oauthClientId;
    NSURL *bridgeURL = [self frontDoorBridgeURLWithClientId:session.oauthRequest.oauthClientId identifier:@"auth-helper"];
    session.oauthCoordinator.loginHint = nil;
    session.oauthCoordinator.frontdoorBridgeLoginOverride = [[SFSDKAuthCoordinatorFrontdoorBridgeLoginOverride alloc]
                                                               initWithFrontdoorBridgeUrl:bridgeURL
                                                               codeVerifier:@"test-code-verifier"];
    [session captureStandardWebAuthIntentWithLoginHint:nil
                                    frontDoorBridgeUrl:bridgeURL
                                          codeVerifier:@"test-code-verifier"];
    manager.authSessions[session.sceneId] = session;
    __block NSUInteger completionCallCount = 0;

    [SFSDKAuthHelper attemptLoginWithAccountManager:manager
                                             scene:[self sceneWithIdentifier:@"connected-scene"]
                                         loginHint:nil
                                         loginHost:nil
                                frontDoorBridgeUrl:bridgeURL
                                      codeVerifier:@"test-code-verifier"
                                        completion:^{
        completionCallCount += 1;
    }];
    SFUserAccount *userAccount = [SFUserAccount new];
    session.authSuccessCallback([[SFOAuthInfo alloc] initWithAuthType:SFOAuthTypeUserAgent], userAccount);
    [SalesforceSDKManager sharedManager].appConfig.remoteAccessConsumerKey = originalConsumerKey;

    XCTAssertEqual(completionCallCount, 1u);
}

- (void)test_givenIndependentSceneLogins_whenOneSucceeds_thenOnlyItsAuthHelperCompletionRuns {
    SFSDKAuthGuardTestUserAccountManager *firstManager = [SFSDKAuthGuardTestUserAccountManager new];
    SFSDKAuthGuardTestUserAccountManager *secondManager = [SFSDKAuthGuardTestUserAccountManager new];
    __block NSUInteger firstCompletionCallCount = 0;
    __block NSUInteger secondCompletionCallCount = 0;

    [SFSDKAuthHelper attemptLoginWithAccountManager:firstManager
                                             scene:[self sceneWithIdentifier:@"first-scene"]
                                         loginHint:nil
                                         loginHost:nil
                                frontDoorBridgeUrl:nil
                                      codeVerifier:nil
                                        completion:^{
        firstCompletionCallCount += 1;
    }];
    [SFSDKAuthHelper attemptLoginWithAccountManager:secondManager
                                             scene:[self sceneWithIdentifier:@"second-scene"]
                                         loginHint:nil
                                         loginHost:nil
                                frontDoorBridgeUrl:nil
                                      codeVerifier:nil
                                        completion:^{
        secondCompletionCallCount += 1;
    }];

    SFUserAccount *userAccount = [SFUserAccount new];
    firstManager.capturedSuccessBlock([[SFOAuthInfo alloc] initWithAuthType:SFOAuthTypeUserAgent], userAccount);

    XCTAssertEqual(firstCompletionCallCount, 1u);
    XCTAssertEqual(secondCompletionCallCount, 0u);
}

- (void)test_givenAuthHelperLogin_whenAuthenticationSucceeds_thenCompletionRunsOnce {
    SFSDKAuthGuardTestUserAccountManager *manager = [SFSDKAuthGuardTestUserAccountManager new];
    __block NSUInteger completionCallCount = 0;
    [SFSDKAuthHelper attemptLoginWithAccountManager:manager
                                             scene:nil
                                         loginHint:nil
                                         loginHost:nil
                                frontDoorBridgeUrl:nil
                                      codeVerifier:nil
                                        completion:^{
        completionCallCount += 1;
    }];

    SFUserAccount *userAccount = [SFUserAccount new];
    manager.capturedSuccessBlock([[SFOAuthInfo alloc] initWithAuthType:SFOAuthTypeUserAgent], userAccount);

    XCTAssertEqual(completionCallCount, 1u, @"A successful login must invoke its AuthHelper completion exactly once");
}

- (void)test_givenQrTaggedFrontdoorUrl_whenAuthHelperCarriesRequest_thenExactUrlRetainsQrMetadataAtManagerBoundary {
    SFSDKAuthGuardTestUserAccountManager *manager = [SFSDKAuthGuardTestUserAccountManager new];
    NSURL *frontdoorUrl = [self frontDoorBridgeURLWithClientId:@"test-client-id" identifier:@"qr"];
    frontdoorUrl.sfsdk_isQrCodeLoginRequest = YES;

    [SFSDKAuthHelper attemptLoginWithAccountManager:manager
                                             scene:nil
                                         loginHint:nil
                                         loginHost:nil
                                frontDoorBridgeUrl:frontdoorUrl
                                      codeVerifier:@"verifier"
                                        completion:nil];

    XCTAssertEqual(manager.capturedFrontDoorBridgeUrl, frontdoorUrl);
    XCTAssertTrue(manager.capturedFrontDoorBridgeUrl.sfsdk_isQrCodeLoginRequest);
}

- (void)test_givenFailedAuthHelperLogin_whenAuthenticationFails_thenCompletionDoesNotRun {
    SFSDKAuthGuardTestUserAccountManager *manager = [SFSDKAuthGuardTestUserAccountManager new];
    manager.failAuthentication = YES;
    __block NSUInteger completionCallCount = 0;

    [SFSDKAuthHelper attemptLoginWithAccountManager:manager
                                             scene:nil
                                         loginHint:nil
                                         loginHost:nil
                                frontDoorBridgeUrl:nil
                                      codeVerifier:nil
                                        completion:^{
        completionCallCount += 1;
    }];

    XCTAssertEqual(completionCallCount, 0u, @"A failed attempt must not invoke the AuthHelper completion");
}

- (void)test_givenCompletedAuthSession_whenSuccessCallbackIsAppended_thenCallbackReceivesStoredResultExactlyOnce {
    SFSDKAuthSession *session = [self authenticatingSessionForScene:nil];
    SFOAuthInfo *authInfo = [[SFOAuthInfo alloc] initWithAuthType:SFOAuthTypeUserAgent];
    SFUserAccount *userAccount = [SFUserAccount new];
    [session completeAuthenticationWithAuthInfo:authInfo userAccount:userAccount];
    __block NSUInteger callbackCallCount = 0;

    [session appendAuthSuccessCallback:^(SFOAuthInfo *callbackAuthInfo, SFUserAccount *callbackUserAccount) {
        callbackCallCount += 1;
        XCTAssertEqual(callbackAuthInfo, authInfo);
        XCTAssertEqual(callbackUserAccount, userAccount);
    } failureCallback:nil];

    XCTAssertEqual(callbackCallCount, 1u);
}

- (void)test_givenFailedAuthSession_whenFailureCallbackIsAppended_thenCallbackReceivesStoredErrorExactlyOnce {
    SFSDKAuthSession *session = [self authenticatingSessionForScene:nil];
    SFOAuthInfo *authInfo = [[SFOAuthInfo alloc] initWithAuthType:SFOAuthTypeUserAgent];
    NSError *error = [NSError errorWithDomain:@"SFUserAccountManagerTests" code:1 userInfo:nil];
    [session completeAuthenticationWithAuthInfo:authInfo error:error];
    __block NSUInteger callbackCallCount = 0;

    [session appendAuthSuccessCallback:nil failureCallback:^(SFOAuthInfo *callbackAuthInfo, NSError *callbackError) {
        callbackCallCount += 1;
        XCTAssertEqual(callbackAuthInfo, authInfo);
        XCTAssertEqual(callbackError, error);
    }];

    XCTAssertEqual(callbackCallCount, 1u);
}

- (void)test_givenAuthSessionCallbacks_whenAuthenticationCompletesTwice_thenCallbacksAreDeliveredOnce {
    SFSDKAuthSession *session = [self authenticatingSessionForScene:nil];
    SFOAuthInfo *authInfo = [[SFOAuthInfo alloc] initWithAuthType:SFOAuthTypeUserAgent];
    SFUserAccount *userAccount = [SFUserAccount new];
    __block NSUInteger successCallCount = 0;
    __block NSUInteger failureCallCount = 0;
    [session appendAuthSuccessCallback:^(SFOAuthInfo *callbackAuthInfo, SFUserAccount *callbackUserAccount) {
        successCallCount += 1;
    } failureCallback:^(SFOAuthInfo *callbackAuthInfo, NSError *error) {
        failureCallCount += 1;
    }];

    [session completeAuthenticationWithAuthInfo:authInfo userAccount:userAccount];
    [session completeAuthenticationWithAuthInfo:authInfo userAccount:userAccount];

    XCTAssertEqual(successCallCount, 1u);
    XCTAssertEqual(failureCallCount, 0u);
}

- (void)test_givenSuccessDeliveryInProgress_whenLateCallbackIsAppended_thenLateCallbackWaitsAndRunsInOrder {
    SFSDKAuthSession *session = [self authenticatingSessionForScene:nil];
    SFOAuthInfo *authInfo = [[SFOAuthInfo alloc] initWithAuthType:SFOAuthTypeUserAgent];
    SFUserAccount *userAccount = [SFUserAccount new];
    dispatch_semaphore_t firstStarted = dispatch_semaphore_create(0);
    dispatch_semaphore_t releaseFirst = dispatch_semaphore_create(0);
    dispatch_semaphore_t deliveryFinished = dispatch_semaphore_create(0);
    NSMutableArray<NSString *> *order = [NSMutableArray array];
    session.authSuccessCallback = ^(SFOAuthInfo *callbackAuthInfo, SFUserAccount *callbackUserAccount) {
        @synchronized (order) {
            [order addObject:@"first"];
        }
        dispatch_semaphore_signal(firstStarted);
        dispatch_semaphore_wait(releaseFirst, DISPATCH_TIME_FOREVER);
    };

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        [session completeAuthenticationWithAuthInfo:authInfo userAccount:userAccount];
        dispatch_semaphore_signal(deliveryFinished);
    });
    XCTAssertEqual(dispatch_semaphore_wait(firstStarted, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)), 0l);

    [session appendAuthSuccessCallback:^(SFOAuthInfo *callbackAuthInfo, SFUserAccount *callbackUserAccount) {
        @synchronized (order) {
            [order addObject:@"late"];
        }
    } failureCallback:nil];

    @synchronized (order) {
        XCTAssertEqualObjects(order, (@[@"first"]), @"Late delivery must queue behind the callback already in progress");
    }
    dispatch_semaphore_signal(releaseFirst);
    XCTAssertEqual(dispatch_semaphore_wait(deliveryFinished, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)), 0l);
    @synchronized (order) {
        XCTAssertEqualObjects(order, (@[@"first", @"late"]));
    }
}

- (void)test_givenReentrantSuccessRegistrations_whenAuthenticationCompletes_thenCallbacksDrainIterativelyInOrder {
    SFSDKAuthSession *session = [self authenticatingSessionForScene:nil];
    SFOAuthInfo *authInfo = [[SFOAuthInfo alloc] initWithAuthType:SFOAuthTypeUserAgent];
    SFUserAccount *userAccount = [SFUserAccount new];
    const NSUInteger callbackCount = 1000;
    __block NSUInteger currentDepth = 0;
    __block NSUInteger maximumDepth = 0;
    __block NSUInteger nextIndex = 0;
    NSMutableArray<NSNumber *> *order = [NSMutableArray arrayWithCapacity:callbackCount];
    __block __weak void (^weakRegisterNextCallback)(void);
    void (^registerNextCallback)(void) = ^{
        NSUInteger registeredIndex = nextIndex++;
        [session appendAuthSuccessCallback:^(SFOAuthInfo *callbackAuthInfo, SFUserAccount *callbackUserAccount) {
            currentDepth += 1;
            maximumDepth = MAX(maximumDepth, currentDepth);
            [order addObject:@(registeredIndex)];
            if (nextIndex < callbackCount) {
                weakRegisterNextCallback();
            }
            currentDepth -= 1;
        } failureCallback:nil];
    };
    weakRegisterNextCallback = registerNextCallback;
    registerNextCallback();

    [session completeAuthenticationWithAuthInfo:authInfo userAccount:userAccount];

    XCTAssertEqual(order.count, callbackCount);
    XCTAssertEqual(maximumDepth, 1u, @"Reentrant terminal registrations must enqueue instead of recursively invoking callbacks");
    [order enumerateObjectsUsingBlock:^(NSNumber *value, NSUInteger index, BOOL *stop) {
        XCTAssertEqual(value.unsignedIntegerValue, index);
    }];
}

- (void)test_givenFailureDeliveryInProgress_whenLateCallbackIsAppended_thenLateCallbackWaitsAndRunsInOrder {
    SFSDKAuthSession *session = [self authenticatingSessionForScene:nil];
    SFOAuthInfo *authInfo = [[SFOAuthInfo alloc] initWithAuthType:SFOAuthTypeUserAgent];
    NSError *error = [NSError errorWithDomain:@"SFUserAccountManagerTests" code:1 userInfo:nil];
    dispatch_semaphore_t firstStarted = dispatch_semaphore_create(0);
    dispatch_semaphore_t releaseFirst = dispatch_semaphore_create(0);
    dispatch_semaphore_t deliveryFinished = dispatch_semaphore_create(0);
    NSMutableArray<NSString *> *order = [NSMutableArray array];
    session.authFailureCallback = ^(SFOAuthInfo *callbackAuthInfo, NSError *callbackError) {
        @synchronized (order) {
            [order addObject:@"first"];
        }
        dispatch_semaphore_signal(firstStarted);
        dispatch_semaphore_wait(releaseFirst, DISPATCH_TIME_FOREVER);
    };

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        [session completeAuthenticationWithAuthInfo:authInfo error:error];
        dispatch_semaphore_signal(deliveryFinished);
    });
    XCTAssertEqual(dispatch_semaphore_wait(firstStarted, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)), 0l);

    [session appendAuthSuccessCallback:nil failureCallback:^(SFOAuthInfo *callbackAuthInfo, NSError *callbackError) {
        @synchronized (order) {
            [order addObject:@"late"];
        }
    }];

    @synchronized (order) {
        XCTAssertEqualObjects(order, (@[@"first"]), @"Late failure delivery must queue behind the callback already in progress");
    }
    dispatch_semaphore_signal(releaseFirst);
    XCTAssertEqual(dispatch_semaphore_wait(deliveryFinished, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)), 0l);
    @synchronized (order) {
        XCTAssertEqualObjects(order, (@[@"first", @"late"]));
    }
}

- (void)test_givenNonStandardAuthenticatingUnscopedSession_whenConnectedSceneAuthenticates_thenSessionIsIgnoredAndNotReassociated {
    SFSDKAuthGuardTestUserAccountManager *manager = [SFSDKAuthGuardTestUserAccountManager new];
    SFSDKAuthRequest *request = [SFSDKAuthRequest new];
    request.oauthClientId = @"test-client-id";
    request.idpInitiatedAuth = YES;
    SFSDKAuthSession *session = [[SFSDKAuthSession alloc] initWith:request credentials:nil];
    session.isAuthenticating = YES;
    NSString *routingKey = session.sceneId;
    manager.authSessions[routingKey] = session;

    BOOL result = [manager authenticateWithCompletion:nil failure:nil scene:[self sceneWithIdentifier:@"connected-scene"]];

    XCTAssertTrue(result);
    XCTAssertEqual(manager.authenticateWithRequestCallCount, 1u);
    XCTAssertEqual(manager.authSessions[routingKey], session);
    XCTAssertNil(session.oauthRequest.scene);
}

- (void)test_givenEligibleStandardWebSession_whenHeadlessNativeLoginStarts_thenNativeLoginIsNotBlockedOrReassociated {
    SFSDKAuthGuardTestUserAccountManager *manager = [SFSDKAuthGuardTestUserAccountManager new];
    manager.useNativeLoginRequest = YES;
    SFSDKAuthSession *session = [self authenticatingSessionForScene:nil];
    NSString *routingKey = session.sceneId;
    manager.authSessions[routingKey] = session;

    BOOL result = [manager authenticateWithCompletion:nil failure:nil scene:[self sceneWithIdentifier:@"connected-scene"]];

    XCTAssertTrue(result);
    XCTAssertEqual(manager.authenticateWithRequestCallCount, 1u);
    XCTAssertEqual(manager.authSessions[routingKey], session);
    XCTAssertNil(session.oauthRequest.scene);
}

- (void)test_givenEligibleStandardWebSession_whenCrossAppIDPLoginStarts_thenIDPLoginIsNotBlockedOrReassociated {
    SFSDKAuthGuardTestUserAccountManager *manager = [SFSDKAuthGuardTestUserAccountManager new];
    manager.useIDPRequest = YES;
    SFSDKAuthSession *session = [self authenticatingSessionForScene:nil];
    NSString *routingKey = session.sceneId;
    manager.authSessions[routingKey] = session;

    BOOL result = [manager authenticateWithCompletion:nil failure:nil scene:[self sceneWithIdentifier:@"connected-scene"]];

    XCTAssertTrue(result);
    XCTAssertEqual(manager.authenticateUsingIDPCallCount, 1u);
    XCTAssertEqual(manager.authSessions[routingKey], session);
    XCTAssertNil(session.oauthRequest.scene);
}

- (void)test_givenActiveSessionAtSceneKey_whenHeadlessNativeLoginStarts_thenNativeLoginIsBlocked {
    SFSDKAuthGuardTestUserAccountManager *manager = [SFSDKAuthGuardTestUserAccountManager new];
    manager.useNativeLoginRequest = YES;
    UIScene *scene = [self sceneWithIdentifier:@"connected-scene"];
    SFSDKAuthSession *session = [self authenticatingSessionForScene:scene];
    manager.authSessions[session.sceneId] = session;

    BOOL result = [manager authenticateWithCompletion:nil failure:nil scene:scene];

    XCTAssertFalse(result);
    XCTAssertEqual(manager.authenticateWithRequestCallCount, 0u);
    XCTAssertEqual(manager.authSessions[@"connected-scene"], session);
}

- (void)test_givenActiveSessionAtSceneKey_whenCrossAppIDPLoginStarts_thenIDPLoginIsBlocked {
    SFSDKAuthGuardTestUserAccountManager *manager = [SFSDKAuthGuardTestUserAccountManager new];
    manager.useIDPRequest = YES;
    UIScene *scene = [self sceneWithIdentifier:@"connected-scene"];
    SFSDKAuthSession *session = [self authenticatingSessionForScene:scene];
    manager.authSessions[session.sceneId] = session;

    BOOL result = [manager authenticateWithCompletion:nil failure:nil scene:scene];

    XCTAssertFalse(result);
    XCTAssertEqual(manager.authenticateUsingIDPCallCount, 0u);
    XCTAssertEqual(manager.authSessions[@"connected-scene"], session);
}

- (void)test_givenInactiveSessionAtSceneKey_whenStandardWebLoginStarts_thenStandardLoginIsBlocked {
    SFSDKAuthGuardTestUserAccountManager *manager = [SFSDKAuthGuardTestUserAccountManager new];
    UIScene *scene = [self sceneWithIdentifier:@"connected-scene"];
    SFSDKAuthSession *session = [self authenticatingSessionForScene:scene];
    session.isAuthenticating = NO;
    manager.authSessions[session.sceneId] = session;

    BOOL result = [manager authenticateWithCompletion:nil failure:nil scene:scene];

    XCTAssertFalse(result);
    XCTAssertEqual(manager.authenticateWithRequestCallCount, 0u);
    XCTAssertEqual(manager.authSessions[@"connected-scene"], session);
}

- (void)test_givenInactiveSessionAtSceneKey_whenHeadlessNativeLoginStarts_thenNativeLoginIsBlocked {
    SFSDKAuthGuardTestUserAccountManager *manager = [SFSDKAuthGuardTestUserAccountManager new];
    manager.useNativeLoginRequest = YES;
    UIScene *scene = [self sceneWithIdentifier:@"connected-scene"];
    SFSDKAuthSession *session = [self authenticatingSessionForScene:scene];
    session.isAuthenticating = NO;
    manager.authSessions[session.sceneId] = session;

    BOOL result = [manager authenticateWithCompletion:nil failure:nil scene:scene];

    XCTAssertFalse(result);
    XCTAssertEqual(manager.authenticateWithRequestCallCount, 0u);
    XCTAssertEqual(manager.authSessions[@"connected-scene"], session);
}

- (void)test_givenInactiveSessionAtSceneKey_whenCrossAppIDPLoginStarts_thenIDPLoginIsBlocked {
    SFSDKAuthGuardTestUserAccountManager *manager = [SFSDKAuthGuardTestUserAccountManager new];
    manager.useIDPRequest = YES;
    UIScene *scene = [self sceneWithIdentifier:@"connected-scene"];
    SFSDKAuthSession *session = [self authenticatingSessionForScene:scene];
    session.isAuthenticating = NO;
    manager.authSessions[session.sceneId] = session;

    BOOL result = [manager authenticateWithCompletion:nil failure:nil scene:scene];

    XCTAssertFalse(result);
    XCTAssertEqual(manager.authenticateUsingIDPCallCount, 0u);
    XCTAssertEqual(manager.authSessions[@"connected-scene"], session);
}

- (void)test_givenActiveNonStandardSessionAtSceneKey_whenStandardWebLoginStarts_thenStandardLoginIsBlocked {
    SFSDKAuthGuardTestUserAccountManager *manager = [SFSDKAuthGuardTestUserAccountManager new];
    UIScene *scene = [self sceneWithIdentifier:@"connected-scene"];
    SFSDKAuthRequest *request = [SFSDKAuthRequest new];
    request.oauthClientId = @"test-client-id";
    request.idpInitiatedAuth = YES;
    request.scene = scene;
    SFSDKAuthSession *session = [[SFSDKAuthSession alloc] initWith:request credentials:nil];
    session.isAuthenticating = YES;
    manager.authSessions[session.sceneId] = session;

    BOOL result = [manager authenticateWithCompletion:nil failure:nil scene:scene];

    XCTAssertFalse(result);
    XCTAssertEqual(manager.authenticateWithRequestCallCount, 0u);
    XCTAssertEqual(manager.authSessions[@"connected-scene"], session);
}

- (void)test_givenPresentedUnscopedStandardWebSession_whenRestarted_thenReplacementReusesRoutingKeyAndCallbacks {
    SFSDKAuthGuardTestUserAccountManager *manager = [SFSDKAuthGuardTestUserAccountManager new];
    SFSDKAuthSession *session = [self authenticatingSessionForScene:nil];
    NSString *routingKey = session.sceneId;
    void (^successCallback)(SFOAuthInfo *, SFUserAccount *) = ^(SFOAuthInfo *authInfo, SFUserAccount *account) {};
    void (^failureCallback)(SFOAuthInfo *, NSError *) = ^(SFOAuthInfo *authInfo, NSError *error) {};
    session.authSuccessCallback = successCallback;
    session.authFailureCallback = failureCallback;
    [session markPresentationStarted];
    manager.authSessions[routingKey] = session;

    [manager restartAuthentication:session];

    NSDictionary<NSString *, SFSDKAuthSession *> *sessions = manager.authSessions.dictionary;
    SFSDKAuthSession *replacement = sessions[routingKey];
    XCTAssertEqual(sessions.count, 1u);
    XCTAssertNotNil(replacement);
    XCTAssertNotEqual(replacement, session);
    XCTAssertFalse(session.isAuthenticating);
    XCTAssertEqualObjects(replacement.sceneId, routingKey);
    XCTAssertEqual(replacement.authSuccessCallback, successCallback);
    XCTAssertEqual(replacement.authFailureCallback, failureCallback);
}

- (void)test_givenStaleCoordinatorSuccess_whenNewerSessionOwnsRoutingKey_thenSuccessPipelineDoesNotStart {
    SFSDKAuthGuardTestUserAccountManager *manager = [SFSDKAuthGuardTestUserAccountManager new];
    SFSDKAuthSession *staleSession = [self authenticatingSessionForScene:nil];
    NSString *routingKey = staleSession.sceneId;
    SFSDKAuthSession *newerSession = [[SFSDKAuthSession alloc] initWith:[self standardWebRequestForScene:nil]
                                                            credentials:nil
                                                          routingSceneId:routingKey];
    newerSession.isAuthenticating = YES;
    manager.authSessions[routingKey] = newerSession;
    XCTAssertEqual(manager.authSessions[routingKey], newerSession);

    [manager oauthCoordinatorDidAuthenticate:staleSession.oauthCoordinator
                                    authInfo:[[SFOAuthInfo alloc] initWithAuthType:SFOAuthTypeUserAgent]];

    XCTAssertEqual(manager.shouldBlockCallCount, 0u);
    XCTAssertNil(staleSession.identityCoordinator.idData);
    XCTAssertEqual(manager.applyCredentialsCallCount, 0u);
    XCTAssertNil(manager.currentUser);
    XCTAssertEqual(manager.authSessions[routingKey], newerSession);
}

- (void)test_givenStaleCoordinatorFailure_whenNewerSessionOwnsRoutingKey_thenFailurePipelineIsInert {
    SFSDKAuthGuardTestUserAccountManager *manager = [SFSDKAuthGuardTestUserAccountManager new];
    manager.interceptFailureHandling = YES;
    SFSDKAuthSession *staleSession = [self authenticatingSessionForScene:nil];
    NSString *routingKey = staleSession.sceneId;
    __block NSUInteger failureCallbackCount = 0;
    staleSession.authFailureCallback = ^(SFOAuthInfo *authInfo, NSError *error) {
        failureCallbackCount += 1;
    };
    SFSDKAuthSession *newerSession = [[SFSDKAuthSession alloc] initWith:[self standardWebRequestForScene:nil]
                                                            credentials:nil
                                                         routingSceneId:routingKey];
    newerSession.isAuthenticating = YES;
    manager.authSessions[routingKey] = newerSession;
    NSError *error = [NSError errorWithDomain:@"SFUserAccountManagerTests" code:40 userInfo:nil];

    [manager oauthCoordinator:staleSession.oauthCoordinator didFailWithError:error authInfo:nil];

    XCTAssertNil(staleSession.authError);
    XCTAssertFalse(staleSession.notifiesDelegatesOfFailure);
    XCTAssertEqual(manager.handleFailureCallCount, 0u);
    XCTAssertEqual(failureCallbackCount, 0u);
    XCTAssertEqual(manager.authSessions[routingKey], newerSession);
    XCTAssertTrue(newerSession.isAuthenticating);
}

- (void)test_givenStaleBrowserCancellation_whenNewerSessionOwnsRoutingKey_thenCancellationPipelineIsInert {
    SFSDKAuthGuardTestUserAccountManager *manager = [SFSDKAuthGuardTestUserAccountManager new];
    manager.useNativeLoginRequest = YES;
    manager.fallbackToWebAuthentication = YES;
    SFSDKAuthSession *staleSession = [self authenticatingSessionForScene:nil];
    NSString *routingKey = staleSession.sceneId;
    staleSession.oauthRequest.loginAsAdmin = YES;
    staleSession.oauthRequest.loginAsAdminMyDomain = @"admin.example.com";
    staleSession.oauthRequest.loginAsAdminLoginHint = @"admin@example.com";
    SFSDKAuthSession *newerSession = [[SFSDKAuthSession alloc] initWith:[self standardWebRequestForScene:nil]
                                                            credentials:nil
                                                         routingSceneId:routingKey];
    newerSession.isAuthenticating = YES;
    manager.authSessions[routingKey] = newerSession;

    [manager oauthCoordinatorDidCancelBrowserAuthentication:staleSession.oauthCoordinator];

    XCTAssertTrue(staleSession.oauthRequest.loginAsAdmin);
    XCTAssertEqualObjects(staleSession.oauthRequest.loginAsAdminMyDomain, @"admin.example.com");
    XCTAssertEqualObjects(staleSession.oauthRequest.loginAsAdminLoginHint, @"admin@example.com");
    XCTAssertEqual(manager.stopCurrentAuthenticationCallCount, 0u);
    XCTAssertEqual(manager.loginWithCompletionCallCount, 0u);
    XCTAssertEqual(manager.cancellationNotificationCallCount, 0u);
    XCTAssertEqual(manager.authenticateWithRequestCallCount, 0u);
    XCTAssertEqual(manager.authSessions[routingKey], newerSession);
    XCTAssertTrue(newerSession.isAuthenticating);
}

- (void)test_givenStaleIdentityFailure_whenNewerSessionOwnsRoutingKey_thenFailureAndRetryAreInert {
    SFSDKAuthGuardTestUserAccountManager *manager = [SFSDKAuthGuardTestUserAccountManager new];
    manager.interceptFailureHandling = YES;
    SFSDKRevocationRecordingOAuthClient *oauthClient = [SFSDKRevocationRecordingOAuthClient new];
    manager.authClient = ^id<SFSDKOAuthProtocol> { return oauthClient; };
    __block NSUInteger alertCount = 0;
    __block SFSDKAlertMessage *capturedAlert = nil;
    __block XCTestExpectation *alertExpectation = nil;
    manager.alertDisplayBlock = ^(SFSDKAlertMessage *message, SFSDKWindowContainer *window) {
        alertCount += 1;
        capturedAlert = message;
        [alertExpectation fulfill];
    };
    SFSDKAuthSession *staleSession = [self authenticatingSessionForScene:nil];
    NSString *routingKey = staleSession.sceneId;
    SFSDKIdentityRetrievalRecordingCoordinator *identityCoordinator = [[SFSDKIdentityRetrievalRecordingCoordinator alloc] initWithAuthSession:staleSession];
    staleSession.identityCoordinator = identityCoordinator;
    SFSDKAuthSession *newerSession = [[SFSDKAuthSession alloc] initWith:[self standardWebRequestForScene:nil]
                                                            credentials:nil
                                                         routingSceneId:routingKey];
    newerSession.isAuthenticating = YES;
    manager.authSessions[routingKey] = newerSession;

    [manager identityCoordinator:identityCoordinator
                didFailWithError:[NSError errorWithDomain:@"SFUserAccountManagerTests" code:41 userInfo:nil]];
    [manager identityCoordinator:identityCoordinator
                didFailWithError:[NSError errorWithDomain:@"SFUserAccountManagerTests" code:kSFIdentityErrorMissingParameters userInfo:nil]];
    if (capturedAlert.actionOneCompletion) {
        capturedAlert.actionOneCompletion();
    }

    XCTAssertEqual(oauthClient.revokeRefreshTokenCallCount, 0u);
    XCTAssertEqual(alertCount, 0u);
    XCTAssertEqual(identityCoordinator.initiateIdentityDataRetrievalCallCount, 0u);
    XCTAssertEqual(manager.handleFailureCallCount, 0u);
    XCTAssertEqual(manager.authSessions[routingKey], newerSession);
    XCTAssertTrue(newerSession.isAuthenticating);

    SFSDKAuthSession *retrySession = [self authenticatingSessionForScene:nil];
    NSString *retryRoutingKey = retrySession.sceneId;
    SFSDKIdentityRetrievalRecordingCoordinator *retryCoordinator = [[SFSDKIdentityRetrievalRecordingCoordinator alloc] initWithAuthSession:retrySession];
    retrySession.identityCoordinator = retryCoordinator;
    manager.authSessions[retryRoutingKey] = retrySession;
    alertExpectation = [self expectationWithDescription:@"identity failure alert"];
    [manager identityCoordinator:retryCoordinator
                didFailWithError:[NSError errorWithDomain:@"SFUserAccountManagerTests" code:42 userInfo:nil]];
    SFSDKAuthSession *retryReplacement = [[SFSDKAuthSession alloc] initWith:[self standardWebRequestForScene:nil]
                                                               credentials:nil
                                                            routingSceneId:retryRoutingKey];
    retryReplacement.isAuthenticating = YES;
    manager.authSessions[retryRoutingKey] = retryReplacement;
    [self waitForExpectations:@[alertExpectation] timeout:5];
    capturedAlert.actionOneCompletion();

    XCTAssertEqual(alertCount, 1u);
    XCTAssertEqual(retryCoordinator.initiateIdentityDataRetrievalCallCount, 0u);
    XCTAssertEqual(manager.authSessions[retryRoutingKey], retryReplacement);
}

- (void)test_givenShouldBlockCompletionForStaleSession_whenNewerSessionOwnsRoutingKey_thenIdentityRetrievalDoesNotStart {
    SFSDKAuthGuardTestUserAccountManager *manager = [SFSDKAuthGuardTestUserAccountManager new];
    manager.defersShouldBlockCompletion = YES;
    SFSDKAuthSession *staleSession = [self authenticatingSessionForScene:nil];
    NSString *routingKey = staleSession.sceneId;
    manager.authSessions[routingKey] = staleSession;
    [manager oauthCoordinatorDidAuthenticate:staleSession.oauthCoordinator
                                    authInfo:[[SFOAuthInfo alloc] initWithAuthType:SFOAuthTypeUserAgent]];
    SFSDKAuthSession *newerSession = [[SFSDKAuthSession alloc] initWith:[self standardWebRequestForScene:nil]
                                                            credentials:nil
                                                         routingSceneId:routingKey];
    newerSession.isAuthenticating = YES;
    manager.authSessions[routingKey] = newerSession;

    [manager fireShouldBlockCompletion:NO];

    XCTAssertNil(staleSession.identityCoordinator.idData);
    XCTAssertEqual(manager.applyCredentialsCallCount, 0u);
    XCTAssertNil(manager.currentUser);
    XCTAssertEqual(manager.authSessions[routingKey], newerSession);
}

- (void)test_givenStaleIdentityDismissalCompletion_whenNewerSessionOwnsRoutingKey_thenGlobalLoginStateIsUnchanged {
    SFSDKAuthGuardTestUserAccountManager *manager = [SFSDKAuthGuardTestUserAccountManager new];
    manager.defersDismissalCompletion = YES;
    SFSDKAuthSession *staleSession = [self authenticatingSessionForScene:nil];
    NSString *routingKey = staleSession.sceneId;
    staleSession.identityCoordinator = [[SFIdentityCoordinator alloc] initWithAuthSession:staleSession];
    staleSession.identityCoordinator.idData = [self sampleIdentityData];
    manager.authSessions[routingKey] = staleSession;
    __block NSUInteger successCallCount = 0;
    staleSession.authSuccessCallback = ^(SFOAuthInfo *authInfo, SFUserAccount *account) {
        successCallCount += 1;
    };
    __block NSUInteger notificationCount = 0;
    id observer = [[NSNotificationCenter defaultCenter] addObserverForName:kSFNotificationUserDidLogIn
                                                                    object:manager
                                                                     queue:nil
                                                                usingBlock:^(NSNotification *note) {
        notificationCount += 1;
    }];
    [self addTeardownBlock:^{
        [[NSNotificationCenter defaultCenter] removeObserver:observer];
    }];
    [manager retrievedIdentityData:staleSession];
    SFSDKAuthSession *newerSession = [self authenticatingSessionForScene:nil];
    manager.authSessions[routingKey] = newerSession;

    [manager fireDismissalCompletion];

    XCTAssertEqual(manager.applyCredentialsCallCount, 0u);
    XCTAssertNil(manager.currentUser);
    XCTAssertEqual(successCallCount, 0u);
    XCTAssertEqual(notificationCount, 0u);
    XCTAssertEqual(manager.authSessions[routingKey], newerSession);
}

- (void)test_givenOwningSessionIsReplacedAtFinalizationBoundary_whenFinalizationRuns_thenGlobalLoginStateIsUnchanged {
    SFSDKAuthGuardTestUserAccountManager *manager = [SFSDKAuthGuardTestUserAccountManager new];
    SFSDKAuthSession *staleSession = [self authenticatingSessionForScene:nil];
    NSString *routingKey = staleSession.sceneId;
    staleSession.identityCoordinator = [[SFIdentityCoordinator alloc] initWithAuthSession:staleSession];
    staleSession.identityCoordinator.idData = [self sampleIdentityData];
    manager.authSessions[routingKey] = staleSession;
    SFSDKAuthSession *newerSession = [self authenticatingSessionForScene:nil];
    __weak SFSDKAuthGuardTestUserAccountManager *weakManager = manager;
    manager.beforeFinalizeAuthCompletion = ^(SFSDKAuthSession *authSession) {
        weakManager.authSessions[routingKey] = newerSession;
    };

    [manager finalizeAuthCompletion:staleSession];

    XCTAssertEqual(manager.applyCredentialsCallCount, 0u);
    XCTAssertNil(manager.currentUser);
    XCTAssertEqual(manager.authSessions[routingKey], newerSession);
}

- (void)test_givenOwningSessionFinalizes_whenSuccessCallbackRuns_thenCompletionOccursOnceWithoutHoldingAccountsLock {
    SFSDKAuthGuardTestUserAccountManager *manager = [SFSDKAuthGuardTestUserAccountManager new];
    SFSDKAuthSession *session = [self authenticatingSessionForScene:nil];
    session.identityCoordinator = [[SFIdentityCoordinator alloc] initWithAuthSession:session];
    session.identityCoordinator.idData = [self sampleIdentityData];
    manager.authSessions[session.sceneId] = session;
    __block NSUInteger successCallCount = 0;
    __block BOOL callbackObservedAccountsLockAvailable = NO;
    session.authSuccessCallback = ^(SFOAuthInfo *authInfo, SFUserAccount *account) {
        successCallCount += 1;
        callbackObservedAccountsLockAvailable = [manager isAccountsLockAvailableFromAnotherThread];
    };

    BOOL finalized = [manager finalizeAuthCompletion:session];

    XCTAssertTrue(finalized);
    XCTAssertEqual(successCallCount, 1u);
    XCTAssertTrue(callbackObservedAccountsLockAvailable);
    XCTAssertEqual(manager.applyCredentialsCallCount, 1u);
}

- (void)test_givenIndependentSessionsWithConflictingTelemetry_whenFinalizedInOppositeOrder_thenEachUserReceivesOnlyItsSessionMarkers {
    SFSDKAuthGuardTestUserAccountManager *manager = [SFSDKAuthGuardTestUserAccountManager new];
    SFSDKAuthSession *browserSession = [self authenticatingSessionForScene:nil];
    browserSession.credentials.domain = @"resolved.my.salesforce.com";
    browserSession.oauthCoordinator.authInfo = [[SFOAuthInfo alloc] initWithAuthType:SFOAuthTypeAdvancedBrowser];
    browserSession.identityCoordinator = [[SFIdentityCoordinator alloc] initWithAuthSession:browserSession];
    browserSession.identityCoordinator.idData = [self sampleIdentityDataWithUserId:@"005S00000000001" orgId:@"00DS00000000001"];
    [browserSession setTransientAuthFeature:kSFAppFeatureSafariBrowserForLogin enabled:YES];
    [browserSession setTransientAuthFeature:kSFAppFeatureWelcomeDiscovery enabled:YES];
    [browserSession setTransientAuthFeature:kSFAppFeatureAppAttestation enabled:YES];
    __block SFUserAccount *browserUser = nil;
    browserSession.authSuccessCallback = ^(SFOAuthInfo *authInfo, SFUserAccount *account) {
        browserUser = account;
    };

    SFSDKAuthSession *qrSession = [self authenticatingSessionForScene:nil];
    qrSession.credentials.domain = @"login.salesforce.com";
    qrSession.oauthCoordinator.authInfo = [[SFOAuthInfo alloc] initWithAuthType:SFOAuthTypeUserAgent];
    qrSession.identityCoordinator = [[SFIdentityCoordinator alloc] initWithAuthSession:qrSession];
    qrSession.identityCoordinator.idData = [self sampleIdentityDataWithUserId:@"005S00000000002" orgId:@"00DS00000000002"];
    [qrSession setTransientAuthFeature:kSFAppFeatureQrCodeLogin enabled:YES];
    __block SFUserAccount *qrUser = nil;
    qrSession.authSuccessCallback = ^(SFOAuthInfo *authInfo, SFUserAccount *account) {
        qrUser = account;
    };
    manager.authSessions[browserSession.sceneId] = browserSession;
    manager.authSessions[qrSession.sceneId] = qrSession;

    XCTAssertTrue([manager finalizeAuthCompletion:browserSession]);
    NSSet<NSString *> *browserFeatures = browserUser.persistedFeatureFlags;
    XCTAssertTrue([browserFeatures containsObject:kSFAppFeatureSafariBrowserForLogin]);
    XCTAssertTrue([browserFeatures containsObject:kSFAppFeatureWelcomeDiscovery]);
    XCTAssertTrue([browserFeatures containsObject:kSFAppFeatureAppAttestation]);
    XCTAssertTrue([browserFeatures containsObject:kSFAppFeatureLoginServerWelcomeDiscovery]);
    XCTAssertFalse([browserFeatures containsObject:kSFAppFeatureQrCodeLogin]);
    XCTAssertTrue([[SFSDKAppFeatureMarkers appFeatures] containsObject:kSFAppFeatureQrCodeLogin],
                  @"Finalizing one session must leave another session's active global compatibility marker intact");

    XCTAssertTrue([manager finalizeAuthCompletion:qrSession]);
    NSSet<NSString *> *qrFeatures = qrUser.persistedFeatureFlags;
    XCTAssertTrue([qrFeatures containsObject:kSFAppFeatureQrCodeLogin]);
    XCTAssertTrue([qrFeatures containsObject:kSFAppFeatureLoginServerProduction]);
    XCTAssertFalse([qrFeatures containsObject:kSFAppFeatureSafariBrowserForLogin]);
    XCTAssertFalse([qrFeatures containsObject:kSFAppFeatureWelcomeDiscovery]);
    XCTAssertFalse([qrFeatures containsObject:kSFAppFeatureAppAttestation]);
}

- (void)test_givenConcurrentNormalAndQrSessions_whenFinalized_thenQrAttributionDoesNotLeakToNormalSession {
    SFSDKAuthGuardTestUserAccountManager *manager = [SFSDKAuthGuardTestUserAccountManager new];
    SFSDKAuthSession *normalSession = [self authenticatingSessionForScene:nil];
    normalSession.oauthCoordinator.authInfo = [[SFOAuthInfo alloc] initWithAuthType:SFOAuthTypeUserAgent];
    normalSession.identityCoordinator = [[SFIdentityCoordinator alloc] initWithAuthSession:normalSession];
    normalSession.identityCoordinator.idData = [self sampleIdentityDataWithUserId:@"005S00000000003" orgId:@"00DS00000000003"];
    __block SFUserAccount *normalUser = nil;
    normalSession.authSuccessCallback = ^(SFOAuthInfo *authInfo, SFUserAccount *account) {
        normalUser = account;
    };
    SFSDKAuthSession *qrSession = [self authenticatingSessionForScene:nil];
    qrSession.oauthCoordinator.authInfo = [[SFOAuthInfo alloc] initWithAuthType:SFOAuthTypeUserAgent];
    qrSession.identityCoordinator = [[SFIdentityCoordinator alloc] initWithAuthSession:qrSession];
    qrSession.identityCoordinator.idData = [self sampleIdentityDataWithUserId:@"005S00000000004" orgId:@"00DS00000000004"];
    [qrSession setTransientAuthFeature:kSFAppFeatureQrCodeLogin enabled:YES];
    __block SFUserAccount *qrUser = nil;
    qrSession.authSuccessCallback = ^(SFOAuthInfo *authInfo, SFUserAccount *account) {
        qrUser = account;
    };
    manager.authSessions[normalSession.sceneId] = normalSession;
    manager.authSessions[qrSession.sceneId] = qrSession;

    XCTAssertTrue([manager finalizeAuthCompletion:normalSession]);
    XCTAssertTrue([manager finalizeAuthCompletion:qrSession]);

    XCTAssertFalse([normalUser.persistedFeatureFlags containsObject:kSFAppFeatureQrCodeLogin]);
    XCTAssertTrue([qrUser.persistedFeatureFlags containsObject:kSFAppFeatureQrCodeLogin]);
}

- (void)test_givenLoginStateTransitionFails_whenFailureCallbackRuns_thenItRunsOnceWithoutHoldingAccountsLock {
    SFSDKAuthGuardTestUserAccountManager *manager = [SFSDKAuthGuardTestUserAccountManager new];
    manager.returnsLoggingOutAccount = YES;
    manager.errorManager = [SFSDKAuthErrorManager new];
    SFSDKAuthSession *session = [self authenticatingSessionForScene:nil];
    session.identityCoordinator = [[SFIdentityCoordinator alloc] initWithAuthSession:session];
    session.identityCoordinator.idData = [self sampleIdentityData];
    manager.authSessions[session.sceneId] = session;
    __block NSUInteger failureCallCount = 0;
    __block BOOL callbackObservedAccountsLockAvailable = NO;
    session.authFailureCallback = ^(SFOAuthInfo *authInfo, NSError *error) {
        failureCallCount += 1;
        callbackObservedAccountsLockAvailable = [manager isAccountsLockAvailableFromAnotherThread];
    };

    BOOL finalized = [manager finalizeAuthCompletion:session];

    XCTAssertFalse(finalized);
    XCTAssertEqual(failureCallCount, 1u);
    XCTAssertTrue(callbackObservedAccountsLockAvailable);
}

- (void)test_givenRecoverableFailure_whenErrorManagerRestarts_thenReplacementPreservesCallbackChain {
    SFSDKAuthGuardTestUserAccountManager *manager = [SFSDKAuthGuardTestUserAccountManager new];
    SFSDKAuthSession *session = [self authenticatingSessionForScene:nil];
    NSString *routingKey = session.sceneId;
    __block NSUInteger originalSuccessCallCount = 0;
    __block NSUInteger coalescedSuccessCallCount = 0;
    __block NSUInteger originalFailureCallCount = 0;
    __block NSUInteger coalescedFailureCallCount = 0;
    [session appendAuthSuccessCallback:^(SFOAuthInfo *authInfo, SFUserAccount *account) {
        originalSuccessCallCount += 1;
    } failureCallback:^(SFOAuthInfo *authInfo, NSError *error) {
        originalFailureCallCount += 1;
    }];
    [session appendAuthSuccessCallback:^(SFOAuthInfo *authInfo, SFUserAccount *account) {
        coalescedSuccessCallCount += 1;
    } failureCallback:^(SFOAuthInfo *authInfo, NSError *error) {
        coalescedFailureCallCount += 1;
    }];
    session.notifiesDelegatesOfFailure = YES;
    manager.authSessions[routingKey] = session;
    NSError *recoverableError = [NSError errorWithDomain:@"SFUserAccountManagerTests" code:1 userInfo:nil];

    [manager handleFailure:recoverableError session:session];

    XCTAssertNotNil(manager.capturedErrorAlertCompletion);
    XCTAssertEqual(manager.authSessions[routingKey], session);
    XCTAssertEqual(originalFailureCallCount, 0u, @"A recoverable error must not terminate the original caller");
    XCTAssertEqual(coalescedFailureCallCount, 0u, @"A recoverable error must not terminate coalesced callers");

    [manager fireErrorAlertCompletion];
    SFSDKAuthSession *replacement = manager.authSessions[routingKey];
    XCTAssertNotNil(replacement);
    XCTAssertNotEqual(replacement, session);
    XCTAssertNotNil(replacement.authSuccessCallback);
    XCTAssertNotNil(replacement.authFailureCallback);

    replacement.authSuccessCallback([[SFOAuthInfo alloc] initWithAuthType:SFOAuthTypeUserAgent], [SFUserAccount new]);

    XCTAssertEqual(originalSuccessCallCount, 1u);
    XCTAssertEqual(coalescedSuccessCallCount, 1u);
    XCTAssertEqual(originalFailureCallCount, 0u);
    XCTAssertEqual(coalescedFailureCallCount, 0u);
}

- (void)test_givenRecoveryContinuationForStaleSession_whenAlertActionRuns_thenOldSessionFailsOnceAndNewerSessionIsUnchanged {
    SFSDKAuthGuardTestUserAccountManager *manager = [SFSDKAuthGuardTestUserAccountManager new];
    SFSDKAuthSession *oldSession = [self authenticatingSessionForScene:nil];
    NSString *routingKey = oldSession.sceneId;
    __block NSUInteger failureCallCount = 0;
    __block NSError *callbackError = nil;
    [oldSession appendAuthSuccessCallback:nil failureCallback:^(SFOAuthInfo *authInfo, NSError *error) {
        failureCallCount += 1;
        callbackError = error;
    }];
    oldSession.notifiesDelegatesOfFailure = YES;
    manager.authSessions[routingKey] = oldSession;
    NSError *originalError = [NSError errorWithDomain:@"SFUserAccountManagerTests" code:30 userInfo:nil];

    manager.errorManager.hostConnectionErrorHandlerBlock(originalError, oldSession, @{});
    SFSDKAuthSession *newerSession = [self authenticatingSessionForScene:nil];
    manager.authSessions[routingKey] = newerSession;
    [manager fireErrorAlertCompletion];
    [manager fireErrorAlertCompletion];

    XCTAssertEqual(manager.authenticateWithRequestCallCount, 0u);
    XCTAssertEqual(manager.authSessions[routingKey], newerSession);
    XCTAssertTrue(newerSession.isAuthenticating);
    XCTAssertFalse(oldSession.authenticationRecoveryPending);
    XCTAssertFalse(oldSession.isAuthenticating);
    XCTAssertEqual(failureCallCount, 1u);
    XCTAssertEqual(callbackError, originalError);
}

- (void)test_givenOwningRecoverySession_whenRestartCreatesReplacement_thenOldRecoveryEndsAndCallbacksMoveToReplacement {
    SFSDKAuthGuardTestUserAccountManager *manager = [SFSDKAuthGuardTestUserAccountManager new];
    SFSDKAuthSession *session = [self authenticatingSessionForScene:nil];
    NSString *routingKey = session.sceneId;
    __block NSUInteger successCallCount = 0;
    [session appendAuthSuccessCallback:^(SFOAuthInfo *authInfo, SFUserAccount *account) {
        successCallCount += 1;
    } failureCallback:nil];
    session.notifiesDelegatesOfFailure = YES;
    manager.authSessions[routingKey] = session;
    NSError *recoverableError = [NSError errorWithDomain:@"SFUserAccountManagerTests" code:31 userInfo:nil];

    [manager handleFailure:recoverableError session:session];
    [manager fireErrorAlertCompletion];

    SFSDKAuthSession *replacement = manager.authSessions[routingKey];
    XCTAssertNotNil(replacement);
    XCTAssertNotEqual(replacement, session);
    XCTAssertFalse(session.authenticationRecoveryPending);
    XCTAssertFalse(session.isAuthenticating);
    XCTAssertNil(session.authSuccessCallback, @"The old session must not retain callbacks after restart ownership transfers");
    [replacement completeAuthenticationWithAuthInfo:[[SFOAuthInfo alloc] initWithAuthType:SFOAuthTypeUserAgent]
                                        userAccount:[SFUserAccount new]];
    XCTAssertEqual(successCallCount, 1u);
}

- (void)test_givenOwningRecoverySession_whenRestartCannotCreateReplacement_thenOriginalFailureCompletesOnce {
    SFSDKAuthGuardTestUserAccountManager *manager = [SFSDKAuthGuardTestUserAccountManager new];
    manager.failAuthentication = YES;
    SFSDKAuthSession *session = [self authenticatingSessionForScene:nil];
    NSString *routingKey = session.sceneId;
    __block NSUInteger failureCallCount = 0;
    __block NSError *callbackError = nil;
    [session appendAuthSuccessCallback:nil failureCallback:^(SFOAuthInfo *authInfo, NSError *error) {
        failureCallCount += 1;
        callbackError = error;
    }];
    session.notifiesDelegatesOfFailure = YES;
    manager.authSessions[routingKey] = session;
    NSError *originalError = [NSError errorWithDomain:@"SFUserAccountManagerTests" code:32 userInfo:nil];

    [manager handleFailure:originalError session:session];
    [manager fireErrorAlertCompletion];
    [manager fireErrorAlertCompletion];

    XCTAssertNil(manager.authSessions[routingKey]);
    XCTAssertFalse(session.authenticationRecoveryPending);
    XCTAssertFalse(session.isAuthenticating);
    XCTAssertEqual(failureCallCount, 1u);
    XCTAssertEqual(callbackError, originalError);
}

- (void)test_givenPendingRecovery_whenSessionResets_thenRecoveryAndCallbacksAreCancelled {
    SFSDKAuthGuardTestUserAccountManager *manager = [SFSDKAuthGuardTestUserAccountManager new];
    SFSDKAuthSession *session = [self authenticatingSessionForScene:nil];
    __block NSUInteger failureCallCount = 0;
    [session appendAuthSuccessCallback:nil failureCallback:^(SFOAuthInfo *authInfo, NSError *error) {
        failureCallCount += 1;
    }];
    session.authenticationRecoveryPending = YES;
    manager.authSessions[session.sceneId] = session;

    [manager resetAuthentication:session];

    XCTAssertFalse(session.authenticationRecoveryPending);
    XCTAssertFalse(session.isAuthenticating);
    XCTAssertNil(session.authFailureCallback, @"Reset cancellation must release callbacks without reporting an auth failure");
    XCTAssertEqual(failureCallCount, 0u);
}

- (void)test_givenStaleHostRecoveryAction_whenNewerSessionOwnsRoutingKey_thenHostSideEffectsAreSkippedAndOldSessionFailsOnce {
    SFSDKAuthGuardTestUserAccountManager *manager = [SFSDKAuthGuardTestUserAccountManager new];
    NSString *badHost = @"stale-recovery.example.com";
    SFSDKLoginHostStorage *storage = [SFSDKLoginHostStorage sharedInstance];
    [storage addLoginHost:[SFSDKLoginHost hostWithName:@"Stale recovery" host:badHost deletable:YES]];
    [self addTeardownBlock:^{
        SFSDKLoginHost *host = [storage loginHostForHostAddress:badHost];
        if (host) {
            [storage removeLoginHostAtIndex:[storage indexOfLoginHost:host]];
        }
    }];
    manager.loginHost = badHost;
    manager.previousLoginHost = @"login.salesforce.com";
    SFSDKAuthRequest *request = [self standardWebRequestForScene:nil];
    request.loginHost = badHost;
    SFSDKAuthSession *oldSession = [[SFSDKAuthSession alloc] initWith:request credentials:nil];
    oldSession.isAuthenticating = YES;
    SFSDKRecoveryStopRecordingCoordinator *coordinator = [[SFSDKRecoveryStopRecordingCoordinator alloc] initWithAuthSession:oldSession];
    oldSession.oauthCoordinator = coordinator;
    NSString *routingKey = oldSession.sceneId;
    __block NSUInteger failureCallCount = 0;
    NSError *originalError = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorBadURL userInfo:nil];
    [oldSession appendAuthSuccessCallback:nil failureCallback:^(SFOAuthInfo *authInfo, NSError *error) {
        failureCallCount += 1;
        XCTAssertEqual(error, originalError);
    }];
    oldSession.notifiesDelegatesOfFailure = YES;
    manager.authSessions[routingKey] = oldSession;

    manager.errorManager.hostConnectionErrorHandlerBlock(originalError, oldSession, @{});
    void (^action)(void) = manager.capturedErrorAlertCompletion;
    SFSDKAuthSession *newerSession = [[SFSDKAuthSession alloc] initWith:[self standardWebRequestForScene:nil]
                                                            credentials:nil
                                                         routingSceneId:routingKey];
    newerSession.isAuthenticating = YES;
    manager.authSessions[routingKey] = newerSession;
    XCTAssertEqual(manager.authSessions[routingKey], newerSession);
    NSUInteger stopsBeforeAction = coordinator.stopAuthenticationCallCount;
    action();

    XCTAssertNotNil([storage loginHostForHostAddress:badHost]);
    XCTAssertEqualObjects(manager.loginHost, badHost);
    XCTAssertEqual(coordinator.stopAuthenticationCallCount, stopsBeforeAction);
    XCTAssertEqual(manager.cancellationNotificationCallCount, 0u);
    XCTAssertEqual(manager.recoveryRestartCallCount, 0u);
    XCTAssertEqual(failureCallCount, 1u);
    XCTAssertFalse(oldSession.authenticationRecoveryPending);
    XCTAssertEqual(manager.authSessions[routingKey], newerSession);
    XCTAssertTrue(newerSession.isAuthenticating);
}

- (void)test_givenHostRecoveryLosesOwnershipAtIrreversibleBoundary_whenActionRuns_thenGlobalSideEffectsAreSkippedAndOldSessionFailsOnce {
    SFSDKAuthGuardTestUserAccountManager *manager = [SFSDKAuthGuardTestUserAccountManager new];
    NSString *badHost = @"boundary-recovery.example.com";
    SFSDKLoginHostStorage *storage = [SFSDKLoginHostStorage sharedInstance];
    [storage addLoginHost:[SFSDKLoginHost hostWithName:@"Boundary recovery" host:badHost deletable:YES]];
    [self addTeardownBlock:^{
        SFSDKLoginHost *host = [storage loginHostForHostAddress:badHost];
        if (host) {
            [storage removeLoginHostAtIndex:[storage indexOfLoginHost:host]];
        }
    }];
    manager.loginHost = badHost;
    manager.previousLoginHost = @"login.salesforce.com";
    SFSDKAuthRequest *request = [self standardWebRequestForScene:nil];
    request.loginHost = badHost;
    SFSDKAuthSession *oldSession = [[SFSDKAuthSession alloc] initWith:request credentials:nil];
    oldSession.isAuthenticating = YES;
    SFSDKRecoveryStopRecordingCoordinator *coordinator = [[SFSDKRecoveryStopRecordingCoordinator alloc] initWithAuthSession:oldSession];
    oldSession.oauthCoordinator = coordinator;
    NSString *routingKey = oldSession.sceneId;
    __block NSUInteger failureCallCount = 0;
    NSError *originalError = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorBadURL userInfo:nil];
    oldSession.authFailureCallback = ^(SFOAuthInfo *authInfo, NSError *error) {
        failureCallCount += 1;
        XCTAssertEqual(error, originalError);
    };
    oldSession.notifiesDelegatesOfFailure = YES;
    manager.authSessions[routingKey] = oldSession;
    SFSDKAuthSession *newerSession = [[SFSDKAuthSession alloc] initWith:[self standardWebRequestForScene:nil]
                                                            credentials:nil
                                                         routingSceneId:routingKey];
    newerSession.isAuthenticating = YES;
    __weak SFSDKAuthGuardTestUserAccountManager *weakManager = manager;
    manager.beforeIrreversibleHostRecovery = ^(SFSDKAuthSession *authSession) {
        [weakManager setAuthSession:newerSession forRoutingKey:routingKey];
    };

    manager.errorManager.hostConnectionErrorHandlerBlock(originalError, oldSession, @{});
    [manager fireErrorAlertCompletion];

    XCTAssertNotNil([storage loginHostForHostAddress:badHost]);
    XCTAssertEqualObjects(oldSession.oauthRequest.loginHost, badHost);
    XCTAssertEqualObjects(manager.loginHost, badHost);
    XCTAssertEqual(coordinator.stopAuthenticationCallCount, 0u);
    XCTAssertEqual(manager.cancellationNotificationCallCount, 0u);
    XCTAssertEqual(manager.recoveryRestartCallCount, 0u);
    XCTAssertEqual(failureCallCount, 1u);
    XCTAssertFalse(oldSession.authenticationRecoveryPending);
    XCTAssertEqual(manager.authSessions[routingKey], newerSession);
    XCTAssertTrue(newerSession.isAuthenticating);
}

- (void)test_givenGenericRecoveryActionIsResetDuplicateOrStale_whenActionRuns_thenNoPrevalidationRestartSideEffectsOccur {
    SFSDKAuthGuardTestUserAccountManager *manager = [SFSDKAuthGuardTestUserAccountManager new];
    SFSDKAuthSession *resetSession = [self authenticatingSessionForScene:nil];
    SFSDKRecoveryStopRecordingCoordinator *resetCoordinator = [[SFSDKRecoveryStopRecordingCoordinator alloc] initWithAuthSession:resetSession];
    resetSession.oauthCoordinator = resetCoordinator;
    manager.authSessions[resetSession.sceneId] = resetSession;
    NSError *error = [NSError errorWithDomain:@"SFUserAccountManagerTests" code:43 userInfo:nil];
    manager.errorManager.genericErrorHandlerBlock(error, resetSession, @{});
    void (^resetAction)(void) = manager.capturedErrorAlertCompletion;
    [resetSession cancelPendingAuthenticationRecovery];
    resetAction();
    resetAction();

    XCTAssertEqual(resetCoordinator.stopAuthenticationCallCount, 0u);
    XCTAssertEqual(manager.authenticateWithRequestCallCount, 0u);

    SFSDKAuthSession *staleSession = [self authenticatingSessionForScene:nil];
    NSString *routingKey = staleSession.sceneId;
    SFSDKRecoveryStopRecordingCoordinator *staleCoordinator = [[SFSDKRecoveryStopRecordingCoordinator alloc] initWithAuthSession:staleSession];
    staleSession.oauthCoordinator = staleCoordinator;
    manager.authSessions[routingKey] = staleSession;
    manager.errorManager.genericErrorHandlerBlock(error, staleSession, @{});
    void (^staleAction)(void) = manager.capturedErrorAlertCompletion;
    SFSDKAuthSession *newerSession = [[SFSDKAuthSession alloc] initWith:[self standardWebRequestForScene:nil]
                                                            credentials:nil
                                                         routingSceneId:routingKey];
    newerSession.isAuthenticating = YES;
    manager.authSessions[routingKey] = newerSession;
    staleAction();

    XCTAssertEqual(staleCoordinator.stopAuthenticationCallCount, 0u);
    XCTAssertEqual(manager.authenticateWithRequestCallCount, 0u);
    XCTAssertEqual(manager.authSessions[routingKey], newerSession);
    XCTAssertTrue(newerSession.isAuthenticating);
}

- (void)test_givenHostRecoveryActionAfterReset_whenActionRuns_thenNoHostGlobalOrCallbackSideEffectsOccur {
    SFSDKAuthGuardTestUserAccountManager *manager = [SFSDKAuthGuardTestUserAccountManager new];
    NSString *badHost = @"reset-recovery.example.com";
    SFSDKLoginHostStorage *storage = [SFSDKLoginHostStorage sharedInstance];
    [storage addLoginHost:[SFSDKLoginHost hostWithName:@"Reset recovery" host:badHost deletable:YES]];
    [self addTeardownBlock:^{
        SFSDKLoginHost *host = [storage loginHostForHostAddress:badHost];
        if (host) {
            [storage removeLoginHostAtIndex:[storage indexOfLoginHost:host]];
        }
    }];
    manager.loginHost = badHost;
    manager.previousLoginHost = @"login.salesforce.com";
    SFSDKAuthRequest *request = [self standardWebRequestForScene:nil];
    request.loginHost = badHost;
    SFSDKAuthSession *session = [[SFSDKAuthSession alloc] initWith:request credentials:nil];
    session.isAuthenticating = YES;
    SFSDKRecoveryStopRecordingCoordinator *coordinator = [[SFSDKRecoveryStopRecordingCoordinator alloc] initWithAuthSession:session];
    session.oauthCoordinator = coordinator;
    __block NSUInteger failureCallCount = 0;
    [session appendAuthSuccessCallback:nil failureCallback:^(SFOAuthInfo *authInfo, NSError *error) {
        failureCallCount += 1;
    }];
    session.notifiesDelegatesOfFailure = YES;
    manager.authSessions[session.sceneId] = session;

    manager.errorManager.hostConnectionErrorHandlerBlock([NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorBadURL userInfo:nil], session, @{});
    void (^action)(void) = manager.capturedErrorAlertCompletion;
    [session cancelPendingAuthenticationRecovery];
    NSUInteger stopsAfterReset = coordinator.stopAuthenticationCallCount;
    action();

    XCTAssertNotNil([storage loginHostForHostAddress:badHost]);
    XCTAssertEqualObjects(manager.loginHost, badHost);
    XCTAssertEqual(coordinator.stopAuthenticationCallCount, stopsAfterReset);
    XCTAssertEqual(manager.cancellationNotificationCallCount, 0u);
    XCTAssertEqual(manager.recoveryRestartCallCount, 0u);
    XCTAssertEqual(failureCallCount, 0u);
}

- (void)test_givenHostRecoveryActionInvokedTwice_whenActionsRun_thenHostAndRestartSideEffectsOccurOnce {
    SFSDKAuthGuardTestUserAccountManager *manager = [SFSDKAuthGuardTestUserAccountManager new];
    manager.interceptRecoveryRestart = YES;
    NSString *badHost = @"duplicate-recovery.example.com";
    SFSDKLoginHostStorage *storage = [SFSDKLoginHostStorage sharedInstance];
    [storage addLoginHost:[SFSDKLoginHost hostWithName:@"Duplicate recovery" host:badHost deletable:YES]];
    [self addTeardownBlock:^{
        SFSDKLoginHost *host = [storage loginHostForHostAddress:badHost];
        if (host) {
            [storage removeLoginHostAtIndex:[storage indexOfLoginHost:host]];
        }
    }];
    manager.loginHost = badHost;
    manager.previousLoginHost = @"login.salesforce.com";
    SFSDKAuthRequest *request = [self standardWebRequestForScene:nil];
    request.loginHost = badHost;
    SFSDKAuthSession *session = [[SFSDKAuthSession alloc] initWith:request credentials:nil];
    session.isAuthenticating = YES;
    SFSDKRecoveryStopRecordingCoordinator *coordinator = [[SFSDKRecoveryStopRecordingCoordinator alloc] initWithAuthSession:session];
    session.oauthCoordinator = coordinator;
    session.notifiesDelegatesOfFailure = YES;
    manager.authSessions[session.sceneId] = session;

    manager.errorManager.hostConnectionErrorHandlerBlock([NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorBadURL userInfo:nil], session, @{});
    void (^action)(void) = manager.capturedErrorAlertCompletion;
    action();
    action();

    XCTAssertEqual(coordinator.stopAuthenticationCallCount, 1u);
    XCTAssertEqual(manager.cancellationNotificationCallCount, 1u);
    XCTAssertEqual(manager.recoveryRestartCallCount, 1u);
}

- (void)test_givenOfflineRefreshFallbackPending_whenFailureHandlingReturns_thenSuccessCompletesExactlyOnce {
    SFSDKAuthGuardTestUserAccountManager *manager = [SFSDKAuthGuardTestUserAccountManager new];
    manager.defersDismissalCompletion = YES;
    SFSDKAuthSession *session = [self authenticatingSessionForScene:nil];
    SFOAuthCredentials *credentials = [[SFOAuthCredentials alloc] initWithIdentifier:@"offline-refresh"
                                                                            clientId:@"test-client-id"
                                                                           encrypted:NO];
    credentials.accessToken = @"existing-access-token";
    session.credentials = credentials;
    session.oauthCoordinator.credentials = credentials;
    session.oauthCoordinator.authInfo = [[SFOAuthInfo alloc] initWithAuthType:SFOAuthTypeRefresh];
    session.identityCoordinator = [[SFIdentityCoordinator alloc] initWithAuthSession:session];
    session.identityCoordinator.idData = [self sampleIdentityData];
    __block NSUInteger successCallCount = 0;
    __block NSUInteger failureCallCount = 0;
    [session appendAuthSuccessCallback:^(SFOAuthInfo *authInfo, SFUserAccount *account) {
        successCallCount += 1;
    } failureCallback:^(SFOAuthInfo *authInfo, NSError *error) {
        failureCallCount += 1;
    }];
    session.notifiesDelegatesOfFailure = YES;
    manager.authSessions[session.sceneId] = session;
    NSError *networkError = [NSError errorWithDomain:NSURLErrorDomain
                                                 code:NSURLErrorNotConnectedToInternet
                                             userInfo:nil];

    [manager handleFailure:networkError session:session];

    XCTAssertTrue(session.authenticationRecoveryPending);
    XCTAssertEqual(successCallCount, 0u);
    XCTAssertEqual(failureCallCount, 0u, @"Offline fallback must retain the session until its deferred continuation completes");
    XCTAssertEqual(manager.authSessions[session.sceneId], session);

    [manager fireDismissalCompletion];

    XCTAssertFalse(session.authenticationRecoveryPending);
    XCTAssertEqual(successCallCount, 1u);
    XCTAssertEqual(failureCallCount, 0u);
}

- (void)test_givenOfflineRefreshFallbackCannotFinalize_whenDismissalCompletes_thenFailureCompletesExactlyOnce {
    SFSDKAuthGuardTestUserAccountManager *manager = [SFSDKAuthGuardTestUserAccountManager new];
    manager.defersDismissalCompletion = YES;
    manager.returnsLoggingOutAccount = YES;
    SFSDKAuthSession *session = [self authenticatingSessionForScene:nil];
    SFOAuthCredentials *credentials = [[SFOAuthCredentials alloc] initWithIdentifier:@"offline-refresh-failure"
                                                                            clientId:@"test-client-id"
                                                                           encrypted:NO];
    credentials.accessToken = @"existing-access-token";
    credentials.identityUrl = [NSURL URLWithString:@"https://login.salesforce.com/id/00DS0000000IDdtWAH/005S0000004y9JkCAF"];
    session.credentials = credentials;
    session.oauthCoordinator.credentials = credentials;
    session.oauthCoordinator.authInfo = [[SFOAuthInfo alloc] initWithAuthType:SFOAuthTypeRefresh];
    session.identityCoordinator = [[SFIdentityCoordinator alloc] initWithAuthSession:session];
    session.identityCoordinator.idData = [self sampleIdentityData];
    __block NSUInteger successCallCount = 0;
    __block NSUInteger failureCallCount = 0;
    [session appendAuthSuccessCallback:^(SFOAuthInfo *authInfo, SFUserAccount *account) {
        successCallCount += 1;
    } failureCallback:^(SFOAuthInfo *authInfo, NSError *error) {
        failureCallCount += 1;
    }];
    session.notifiesDelegatesOfFailure = YES;
    manager.authSessions[session.sceneId] = session;
    NSError *networkError = [NSError errorWithDomain:NSURLErrorDomain
                                                 code:NSURLErrorNotConnectedToInternet
                                             userInfo:nil];

    [manager handleFailure:networkError session:session];
    manager.errorManager = [SFSDKAuthErrorManager new];
    [manager fireDismissalCompletion];

    XCTAssertFalse(session.authenticationRecoveryPending);
    XCTAssertEqual(successCallCount, 0u);
    XCTAssertEqual(failureCallCount, 1u);
    XCTAssertNil(manager.authSessions[session.sceneId]);
}

- (void)test_givenOfflineRefreshFallbackLosesOwnership_whenDismissalCompletes_thenNewerSessionIsUnchanged {
    SFSDKAuthGuardTestUserAccountManager *manager = [SFSDKAuthGuardTestUserAccountManager new];
    manager.defersDismissalCompletion = YES;
    SFSDKAuthSession *session = [self authenticatingSessionForScene:nil];
    NSString *routingKey = session.sceneId;
    SFOAuthCredentials *credentials = [[SFOAuthCredentials alloc] initWithIdentifier:@"offline-refresh-stale"
                                                                            clientId:@"test-client-id"
                                                                           encrypted:NO];
    credentials.accessToken = @"existing-access-token";
    session.credentials = credentials;
    session.oauthCoordinator.credentials = credentials;
    session.oauthCoordinator.authInfo = [[SFOAuthInfo alloc] initWithAuthType:SFOAuthTypeRefresh];
    session.identityCoordinator = [[SFIdentityCoordinator alloc] initWithAuthSession:session];
    session.identityCoordinator.idData = [self sampleIdentityData];
    manager.authSessions[routingKey] = session;
    NSError *networkError = [NSError errorWithDomain:NSURLErrorDomain
                                                 code:NSURLErrorNotConnectedToInternet
                                             userInfo:nil];

    [manager handleFailure:networkError session:session];
    SFSDKAuthSession *newerSession = [self authenticatingSessionForScene:nil];
    manager.authSessions[routingKey] = newerSession;
    [manager fireDismissalCompletion];

    XCTAssertFalse(session.authenticationRecoveryPending);
    XCTAssertEqual(manager.authSessions[routingKey], newerSession);
    XCTAssertTrue(newerSession.isAuthenticating);
}

- (void)test_givenUnrecoverableFailure_whenNoHandlerClaimsError_thenFailureCallbackChainFiresExactlyOnce {
    SFSDKAuthGuardTestUserAccountManager *manager = [SFSDKAuthGuardTestUserAccountManager new];
    manager.errorManager = [SFSDKAuthErrorManager new];
    SFSDKAuthSession *session = [self authenticatingSessionForScene:nil];
    __block NSUInteger originalFailureCallCount = 0;
    __block NSUInteger coalescedFailureCallCount = 0;
    [session appendAuthSuccessCallback:nil failureCallback:^(SFOAuthInfo *authInfo, NSError *error) {
        originalFailureCallCount += 1;
    }];
    [session appendAuthSuccessCallback:nil failureCallback:^(SFOAuthInfo *authInfo, NSError *error) {
        coalescedFailureCallCount += 1;
    }];
    session.notifiesDelegatesOfFailure = YES;
    manager.authSessions[session.sceneId] = session;
    NSError *terminalError = [NSError errorWithDomain:@"SFUserAccountManagerTests" code:2 userInfo:nil];

    [manager handleFailure:terminalError session:session];
    [manager handleFailure:terminalError session:session];

    XCTAssertEqual(originalFailureCallCount, 1u);
    XCTAssertEqual(coalescedFailureCallCount, 1u);
    XCTAssertNil(manager.authSessions[session.sceneId]);
}

- (void)test_givenNewerSessionOwnsRoutingKey_whenRestartDismissalCompletes_thenNewerSessionIsPreserved {
    SFSDKAuthGuardTestUserAccountManager *manager = [SFSDKAuthGuardTestUserAccountManager new];
    manager.defersDismissalCompletion = YES;
    SFSDKAuthSession *oldSession = [self authenticatingSessionForScene:nil];
    NSString *routingKey = oldSession.sceneId;
    manager.authSessions[routingKey] = oldSession;

    [manager restartAuthentication:oldSession];

    SFSDKAuthSession *newerSession = [self authenticatingSessionForScene:nil];
    manager.authSessions[routingKey] = newerSession;
    [manager fireDismissalCompletion];

    NSDictionary<NSString *, SFSDKAuthSession *> *sessions = manager.authSessions.dictionary;
    XCTAssertEqual(sessions.count, 1u);
    XCTAssertEqual(sessions[routingKey], newerSession);
    XCTAssertTrue(newerSession.isAuthenticating);
    XCTAssertTrue(oldSession.isAuthenticating);
    XCTAssertEqual(manager.authenticateWithRequestCallCount, 0u);
}

- (void)test_givenNewerSessionOwnsRoutingKey_whenOldSessionResets_thenBothSessionsAreLeftAlone {
    SFSDKAuthGuardTestUserAccountManager *manager = [SFSDKAuthGuardTestUserAccountManager new];
    SFSDKAuthSession *oldSession = [self authenticatingSessionForScene:nil];
    NSString *routingKey = oldSession.sceneId;
    manager.authSessions[routingKey] = oldSession;
    SFSDKAuthSession *newerSession = [self authenticatingSessionForScene:nil];
    manager.authSessions[routingKey] = newerSession;

    [manager resetAuthentication:oldSession];

    XCTAssertEqual(manager.authSessions[routingKey], newerSession);
    XCTAssertTrue(newerSession.isAuthenticating);
    XCTAssertTrue(oldSession.isAuthenticating);
}

- (void)test_givenSessionOwnsRoutingKey_whenSessionResets_thenSessionIsStoppedAndRemoved {
    SFSDKAuthGuardTestUserAccountManager *manager = [SFSDKAuthGuardTestUserAccountManager new];
    SFSDKAuthSession *session = [self authenticatingSessionForScene:nil];
    NSString *routingKey = session.sceneId;
    manager.authSessions[routingKey] = session;

    [manager resetAuthentication:session];

    XCTAssertNil(manager.authSessions[routingKey]);
    XCTAssertFalse(session.isAuthenticating);
}

- (void)test_givenSessionWithTransientFeature_whenSessionResets_thenFeatureOwnershipIsClearedImmediately {
    SFSDKAuthGuardTestUserAccountManager *manager = [SFSDKAuthGuardTestUserAccountManager new];
    SFSDKAuthSession *session = [self authenticatingSessionForScene:nil];
    [session setTransientAuthFeature:kSFAppFeatureWelcomeDiscovery enabled:YES];
    manager.authSessions[session.sceneId] = session;

    [manager resetAuthentication:session];

    XCTAssertEqual(session.transientAuthFeatures.count, 0u);
}

- (void)test_givenSessionWithTransientFeature_whenReplaced_thenOldSessionFeatureOwnershipIsClearedImmediately {
    SFSDKAuthGuardTestUserAccountManager *manager = [SFSDKAuthGuardTestUserAccountManager new];
    UIScene *scene = [self sceneWithIdentifier:@"connected-scene"];
    SFSDKAuthSession *oldSession = [self authenticatingSessionForScene:scene];
    [oldSession setTransientAuthFeature:kSFAppFeatureWelcomeDiscovery enabled:YES];
    manager.authSessions[oldSession.sceneId] = oldSession;
    SFSDKAuthSession *replacement = [self authenticatingSessionForScene:scene];

    [manager setAuthSession:replacement forRoutingKey:oldSession.sceneId];

    XCTAssertEqual(oldSession.transientAuthFeatures.count, 0u);
    XCTAssertEqual(manager.authSessions[replacement.sceneId], replacement);
}

- (void)test_givenDisconnectedSceneOwnsQueuedStandardWebSession_whenDisconnectArrives_thenSessionIsAbandonedWithoutStaleSideEffects {
    SFSDKAuthGuardTestUserAccountManager *manager = [SFSDKAuthGuardTestUserAccountManager new];
    UIScene *scene = [self sceneWithIdentifier:@"disconnected-scene"];
    SFSDKAuthSession *session = [self authenticatingSessionForScene:scene];
    session.credentials.redirectUri = session.oauthRequest.oauthCompletionUrl;
    [session setTransientAuthFeature:kSFAppFeatureSafariBrowserForLogin enabled:YES];
    SFSDKSceneDisconnectPresentationDelegate *delegate = [SFSDKSceneDisconnectPresentationDelegate new];
    session.oauthCoordinator.delegate = delegate;
    __block NSUInteger failureCallbackCount = 0;
    session.authFailureCallback = ^(SFOAuthInfo *authInfo, NSError *error) {
        failureCallbackCount += 1;
    };
    manager.authSessions[session.sceneId] = session;

    [session.oauthCoordinator authenticate];
    [manager sceneDidDisconnect:[NSNotification notificationWithName:UISceneDidDisconnectNotification object:scene]];
    XCTestExpectation *mainQueueDrained = [self expectationWithDescription:@"disconnected scene auth continuation drained"];
    dispatch_async(dispatch_get_main_queue(), ^{
        [mainQueueDrained fulfill];
    });
    [self waitForExpectations:@[mainQueueDrained] timeout:5.0];

    XCTAssertNil(manager.authSessions[@"disconnected-scene"]);
    XCTAssertFalse(session.isAuthenticating);
    XCTAssertEqual(session.transientAuthFeatures.count, 0u);
    XCTAssertEqual(delegate.beginNotificationCount, 0u);
    XCTAssertEqual(delegate.presentationCount, 0u);
    XCTAssertEqual(failureCallbackCount, 0u, @"Scene disconnection abandons authentication without reporting an auth failure");
    XCTAssertFalse([[SFSDKAppFeatureMarkers appFeatures] containsObject:kSFAppFeatureSafariBrowserForLogin]);
}

- (void)test_givenStaleSessionWithTransientFeature_whenResetRequested_thenStaleFeatureOwnershipIsClearedWithoutTouchingNewerSession {
    SFSDKAuthGuardTestUserAccountManager *manager = [SFSDKAuthGuardTestUserAccountManager new];
    UIScene *scene = [self sceneWithIdentifier:@"connected-scene"];
    SFSDKAuthSession *staleSession = [self authenticatingSessionForScene:scene];
    [staleSession setTransientAuthFeature:kSFAppFeatureWelcomeDiscovery enabled:YES];
    SFSDKAuthSession *newerSession = [self authenticatingSessionForScene:scene];
    [newerSession setTransientAuthFeature:kSFAppFeatureWelcomeDiscovery enabled:YES];
    manager.authSessions[newerSession.sceneId] = newerSession;

    [manager resetAuthentication:staleSession];

    XCTAssertEqual(staleSession.transientAuthFeatures.count, 0u);
    XCTAssertTrue([newerSession.transientAuthFeatures containsObject:kSFAppFeatureWelcomeDiscovery]);
    XCTAssertEqual(manager.authSessions[newerSession.sceneId], newerSession);
}

- (void)test_givenAuthenticatingSessionScopedToAnotherScene_whenConnectedSceneAuthenticates_thenOtherSessionIsIgnored {
    SFSDKAuthGuardTestUserAccountManager *manager = [SFSDKAuthGuardTestUserAccountManager new];
    UIScene *otherScene = [self sceneWithIdentifier:@"other-scene"];
    SFSDKAuthSession *session = [self authenticatingSessionForScene:otherScene];
    manager.authSessions[session.sceneId] = session;

    BOOL result = [manager authenticateWithCompletion:nil
                                              failure:nil
                                                scene:[self sceneWithIdentifier:@"connected-scene"]];

    NSDictionary *sessions = manager.authSessions.dictionary;
    XCTAssertTrue(result, @"A session scoped to another scene should not block independent authentication");
    XCTAssertEqual(manager.authenticateWithRequestCallCount, 1u);
    XCTAssertEqual(sessions.count, 1u);
    XCTAssertEqual(sessions[@"other-scene"], session);
    XCTAssertEqual(session.oauthRequest.scene, otherScene);
    XCTAssertEqualObjects(session.sceneId, @"other-scene");
}

- (void)test_givenAuthenticatingSessionStoredUnderStaleKeyForRequestedScene_whenConnectedSceneAuthenticates_thenDuplicateIsBlocked {
    SFSDKAuthGuardTestUserAccountManager *manager = [SFSDKAuthGuardTestUserAccountManager new];
    UIScene *scene = [self sceneWithIdentifier:@"connected-scene"];
    SFSDKAuthSession *session = [self authenticatingSessionForScene:scene];
    manager.authSessions[@"stale-key"] = session;

    BOOL result = [manager authenticateWithCompletion:nil failure:nil scene:scene];

    XCTAssertFalse(result);
    XCTAssertEqual(manager.authenticateWithRequestCallCount, 0u);
    XCTAssertEqual(manager.authSessions[@"stale-key"], session);
    XCTAssertNil(manager.authSessions[@"connected-scene"]);
}

- (void)test_givenPresentedAuthenticatingUnscopedSession_whenConnectedSceneAuthenticates_thenDuplicateIsBlockedWithoutReassociation {
    SFSDKAuthGuardTestUserAccountManager *manager = [SFSDKAuthGuardTestUserAccountManager new];
    SFSDKAuthSession *session = [self authenticatingSessionForScene:nil];
    NSString *synthesizedSceneId = session.sceneId;
    [session.oauthCoordinator setValue:(id)[NSObject new] forKey:@"asWebAuthenticationSession"];
    manager.authSessions[synthesizedSceneId] = session;

    BOOL result = [manager authenticateWithCompletion:nil
                                              failure:nil
                                                scene:[self sceneWithIdentifier:@"connected-scene"]];

    NSDictionary *sessions = manager.authSessions.dictionary;
    XCTAssertFalse(result, @"An already-presented pre-scene authentication should block a duplicate login");
    XCTAssertEqual(manager.authenticateWithRequestCallCount, 0u);
    XCTAssertEqual(sessions[synthesizedSceneId], session);
    XCTAssertNil(session.oauthRequest.scene, @"A browser session that has started should retain its original presentation ownership");
    XCTAssertEqualObjects(session.sceneId, synthesizedSceneId, @"Its callback routing key should remain aligned with the store key");
    XCTAssertNil(sessions[@"connected-scene"]);
}

- (void)test_givenWebViewPresentedAuthenticatingUnscopedSession_whenConnectedSceneAuthenticates_thenDuplicateIsBlockedWithoutReassociation {
    SFSDKAuthGuardTestUserAccountManager *manager = [SFSDKAuthGuardTestUserAccountManager new];
    SFSDKAuthSession *session = [self authenticatingSessionForScene:nil];
    NSString *synthesizedSceneId = session.sceneId;
    manager.authSessions[synthesizedSceneId] = session;
    manager.authViewHandler = [[SFSDKAuthViewHandler alloc] initWithDisplayBlock:^(SFSDKAuthViewHolder *viewHandler) {
    } dismissBlock:^{
    }];
    [session markPresentationStarted];

    BOOL result = [manager authenticateWithCompletion:nil
                                              failure:nil
                                                scene:[self sceneWithIdentifier:@"connected-scene"]];

    NSDictionary *sessions = manager.authSessions.dictionary;
    XCTAssertFalse(result);
    XCTAssertEqual(manager.authenticateWithRequestCallCount, 0u);
    XCTAssertEqual(sessions[synthesizedSceneId], session);
    XCTAssertNil(session.oauthRequest.scene);
    XCTAssertEqualObjects(session.sceneId, synthesizedSceneId);
    XCTAssertNil(sessions[@"connected-scene"]);
}

- (void)test_givenOccupiedSceneKey_whenUnscopedSessionIsFound_thenNeitherSessionIsChanged {
    SFSDKAuthGuardTestUserAccountManager *manager = [SFSDKAuthGuardTestUserAccountManager new];
    SFSDKAuthSession *unscopedSession = [self authenticatingSessionForScene:nil];
    NSString *synthesizedSceneId = unscopedSession.sceneId;
    UIScene *scene = [self sceneWithIdentifier:@"connected-scene"];
    SFSDKAuthSession *inactiveSceneSession = [self authenticatingSessionForScene:scene];
    inactiveSceneSession.isAuthenticating = NO;
    manager.authSessions[synthesizedSceneId] = unscopedSession;
    manager.authSessions[inactiveSceneSession.sceneId] = inactiveSceneSession;

    BOOL result = [manager authenticateWithCompletion:nil failure:nil scene:scene];

    NSDictionary *sessions = manager.authSessions.dictionary;
    XCTAssertFalse(result);
    XCTAssertEqual(manager.authenticateWithRequestCallCount, 0u);
    XCTAssertEqual(sessions[synthesizedSceneId], unscopedSession);
    XCTAssertEqual(sessions[@"connected-scene"], inactiveSceneSession);
    XCTAssertNil(unscopedSession.oauthRequest.scene);
    XCTAssertEqualObjects(unscopedSession.sceneId, synthesizedSceneId);
}

- (void)test_givenUnscopedSourceDisappearsBeforeMove_whenConnectedSceneAuthenticates_thenLoginProceeds {
    SFSDKAuthGuardTestUserAccountManager *manager = [SFSDKAuthGuardTestUserAccountManager new];
    SFSDKAuthGuardRaceDictionary *sessions = [SFSDKAuthGuardRaceDictionary new];
    manager.authSessions = sessions;
    SFSDKAuthSession *unscopedSession = [self authenticatingSessionForScene:nil];
    unscopedSession.oauthRequest.oauthClientId = @"test-client-id";
    [unscopedSession captureStandardWebAuthIntentWithLoginHint:nil frontDoorBridgeUrl:nil codeVerifier:nil];
    NSString *sourceKey = unscopedSession.sceneId;
    sessions[sourceKey] = unscopedSession;
    sessions.sourceKeyToRemoveAfterSnapshot = sourceKey;

    BOOL result = [manager authenticateWithCompletion:nil
                                              failure:nil
                                                scene:[self sceneWithIdentifier:@"connected-scene"]];

    XCTAssertTrue(result);
    XCTAssertEqual(manager.authenticateWithRequestCallCount, 1u);
    XCTAssertEqual(sessions.dictionary.count, 0u);
    XCTAssertNil(unscopedSession.oauthRequest.scene);
}

- (void)test_givenAuthenticatingUnscopedSession_whenNilSceneAuthenticates_thenDuplicateIsBlockedWithoutReassociation {
    SFSDKAuthGuardTestUserAccountManager *manager = [SFSDKAuthGuardTestUserAccountManager new];
    SFSDKAuthSession *session = [self authenticatingSessionForScene:nil];
    NSString *synthesizedSceneId = session.sceneId;
    manager.authSessions[synthesizedSceneId] = session;

    BOOL result = [manager authenticateWithCompletion:nil failure:nil scene:nil];

    NSDictionary *sessions = manager.authSessions.dictionary;
    XCTAssertFalse(result, @"A scene-less login should conflict with any in-flight authentication");
    XCTAssertEqual(manager.authenticateWithRequestCallCount, 0u);
    XCTAssertEqual(sessions.count, 1u);
    XCTAssertEqual(sessions[synthesizedSceneId], session);
    XCTAssertNil(session.oauthRequest.scene, @"A nil incoming scene should not claim the unscoped session");
    XCTAssertEqualObjects(session.sceneId, synthesizedSceneId, @"The synthesized routing key should remain unchanged");
}

- (void)test_givenMultipleAuthenticatingUnscopedSessions_whenConnectedSceneAuthenticates_thenDuplicateIsBlockedWithoutReassociation {
    SFSDKAuthGuardTestUserAccountManager *manager = [SFSDKAuthGuardTestUserAccountManager new];
    SFSDKAuthSession *firstSession = [self authenticatingSessionForScene:nil];
    SFSDKAuthSession *secondSession = [self authenticatingSessionForScene:nil];
    NSString *firstSceneId = firstSession.sceneId;
    NSString *secondSceneId = secondSession.sceneId;
    manager.authSessions[firstSceneId] = firstSession;
    manager.authSessions[secondSceneId] = secondSession;

    BOOL result = [manager authenticateWithCompletion:nil
                                              failure:nil
                                                scene:[self sceneWithIdentifier:@"connected-scene"]];

    NSDictionary *sessions = manager.authSessions.dictionary;
    XCTAssertFalse(result, @"Ambiguous pre-scene sessions should block another authentication");
    XCTAssertEqual(manager.authenticateWithRequestCallCount, 0u);
    XCTAssertEqual(sessions.count, 2u);
    XCTAssertEqual(sessions[firstSceneId], firstSession);
    XCTAssertEqual(sessions[secondSceneId], secondSession);
    XCTAssertNil(firstSession.oauthRequest.scene);
    XCTAssertNil(secondSession.oauthRequest.scene);
    XCTAssertEqualObjects(firstSession.sceneId, firstSceneId);
    XCTAssertEqualObjects(secondSession.sceneId, secondSceneId);
    XCTAssertNil(sessions[@"connected-scene"]);
}

- (void)test_givenQueuedAuthenticationSessionIsReassociatedAndReplaced_whenAppConfigReturns_thenStaleCoordinatorDoesNotStart {
    SFUserAccountManager *manager = [SFUserAccountManager new];
    SFSDKAuthRequest *request = [self standardWebRequestForScene:nil];
    __block void (^deferredAppConfigCallback)(SFSDKAppConfig *);
    XCTestExpectation *appConfigRequested = [self expectationWithDescription:@"App config requested"];
    SalesforceSDKManager *sdkManager = [SalesforceSDKManager sharedManager];
    SFSDKAppConfigRuntimeSelectorBlock originalSelector = sdkManager.appConfigRuntimeSelectorBlock;
    [self addTeardownBlock:^{
        sdkManager.appConfigRuntimeSelectorBlock = originalSelector;
    }];
    sdkManager.appConfigRuntimeSelectorBlock = ^(NSString *loginHost, void (^callback)(SFSDKAppConfig *)) {
        deferredAppConfigCallback = [callback copy];
        [appConfigRequested fulfill];
    };

    XCTAssertTrue([manager authenticateWithRequest:request
                                         loginHint:nil
                                        completion:nil
                                           failure:nil
                                frontDoorBridgeUrl:nil
                                      codeVerifier:nil
                                    routingSceneId:nil]);
    SFSDKAuthSession *staleSession = manager.authSessions.dictionary.allValues.firstObject;
    SFSDKAuthenticationStartRecordingCoordinator *staleCoordinator = [[SFSDKAuthenticationStartRecordingCoordinator alloc] initWithAuthSession:staleSession];
    staleSession.oauthCoordinator = staleCoordinator;
    [self waitForExpectations:@[appConfigRequested] timeout:5];

    NSString *oldSceneId = staleSession.sceneId;
    UIScene *scene = [self sceneWithIdentifier:@"connected-scene"];
    XCTAssertTrue([manager.authSessions moveObject:staleSession
                                           fromKey:oldSceneId
                                             toKey:scene.session.persistentIdentifier
                                 beforeMovingBlock:^BOOL(SFSDKAuthSession *storedSession) {
        return [storedSession associateWithSceneIfUnscoped:scene];
    }]);
    SFSDKAuthSession *replacementSession = [self authenticatingSessionForScene:scene];
    manager.authSessions[replacementSession.sceneId] = replacementSession;

    deferredAppConfigCallback(sdkManager.appConfig);

    XCTAssertEqual(staleCoordinator.authenticateWithCredentialsCallCount, 0u,
                   @"A queued session must not start after it loses ownership of its current routing key");
}

- (void)test_givenQueuedAuthenticationSessionStillOwnsRoutingKey_whenAppConfigReturns_thenCoordinatorStartsOnce {
    SFUserAccountManager *manager = [SFUserAccountManager new];
    SFSDKAuthRequest *request = [self standardWebRequestForScene:nil];
    __block void (^deferredAppConfigCallback)(SFSDKAppConfig *);
    XCTestExpectation *appConfigRequested = [self expectationWithDescription:@"App config requested"];
    SalesforceSDKManager *sdkManager = [SalesforceSDKManager sharedManager];
    SFSDKAppConfigRuntimeSelectorBlock originalSelector = sdkManager.appConfigRuntimeSelectorBlock;
    [self addTeardownBlock:^{
        sdkManager.appConfigRuntimeSelectorBlock = originalSelector;
    }];
    sdkManager.appConfigRuntimeSelectorBlock = ^(NSString *loginHost, void (^callback)(SFSDKAppConfig *)) {
        deferredAppConfigCallback = [callback copy];
        [appConfigRequested fulfill];
    };

    XCTAssertTrue([manager authenticateWithRequest:request
                                         loginHint:nil
                                        completion:nil
                                           failure:nil
                                frontDoorBridgeUrl:nil
                                      codeVerifier:nil
                                    routingSceneId:nil]);
    SFSDKAuthSession *session = manager.authSessions.dictionary.allValues.firstObject;
    SFSDKAuthenticationStartRecordingCoordinator *coordinator = [[SFSDKAuthenticationStartRecordingCoordinator alloc] initWithAuthSession:session];
    session.oauthCoordinator = coordinator;
    [self waitForExpectations:@[appConfigRequested] timeout:5];

    deferredAppConfigCallback(sdkManager.appConfig);

    XCTAssertEqual(coordinator.authenticateWithCredentialsCallCount, 1u);
}

- (void)test_givenQueuedAuthenticationSessionLosesOwnershipAfterFinalCheck_whenCoordinatorIsInvoked_thenStaleCoordinatorDoesNotStart {
    SFSDKStartupGapTestUserAccountManager *manager = [SFSDKStartupGapTestUserAccountManager new];
    SFSDKAuthRequest *request = [self standardWebRequestForScene:nil];
    __block void (^deferredAppConfigCallback)(SFSDKAppConfig *);
    XCTestExpectation *appConfigRequested = [self expectationWithDescription:@"App config requested"];
    SalesforceSDKManager *sdkManager = [SalesforceSDKManager sharedManager];
    SFSDKAppConfigRuntimeSelectorBlock originalSelector = sdkManager.appConfigRuntimeSelectorBlock;
    [self addTeardownBlock:^{
        sdkManager.appConfigRuntimeSelectorBlock = originalSelector;
    }];
    sdkManager.appConfigRuntimeSelectorBlock = ^(NSString *loginHost, void (^callback)(SFSDKAppConfig *)) {
        deferredAppConfigCallback = [callback copy];
        [appConfigRequested fulfill];
    };

    XCTAssertTrue([manager authenticateWithRequest:request
                                         loginHint:nil
                                        completion:nil
                                           failure:nil
                                frontDoorBridgeUrl:nil
                                      codeVerifier:nil
                                    routingSceneId:nil]);
    SFSDKAuthSession *staleSession = manager.authSessions.dictionary.allValues.firstObject;
    SFSDKAuthenticationStartRecordingCoordinator *staleCoordinator = [[SFSDKAuthenticationStartRecordingCoordinator alloc] initWithAuthSession:staleSession];
    staleSession.oauthCoordinator = staleCoordinator;
    [self waitForExpectations:@[appConfigRequested] timeout:5];
    __weak SFSDKStartupGapTestUserAccountManager *weakManager = manager;
    manager.beforeCoordinatorStartup = ^(SFSDKAuthSession *checkedSession) {
        [weakManager resetAuthentication:checkedSession];
    };

    deferredAppConfigCallback(sdkManager.appConfig);

    XCTAssertEqual(staleCoordinator.authenticateWithCredentialsCallCount, 0u,
                   @"A reset between the final ownership check and coordinator invocation must revoke queued startup");
}

- (UIScene *)sceneWithIdentifier:(NSString *)identifier {
    SFSDKTestSceneSession *session = [SFSDKTestSceneSession new];
    session.persistentIdentifier = identifier;
    SFSDKTestScene *scene = [SFSDKTestScene new];
    scene.session = session;
    return (UIScene *)scene;
}

- (SFSDKAuthSession *)authenticatingSessionForScene:(UIScene *)scene {
    SFSDKAuthRequest *request = [self standardWebRequestForScene:scene];
    SFSDKAuthSession *session = [[SFSDKAuthSession alloc] initWith:request credentials:nil];
    [session captureStandardWebAuthIntentWithLoginHint:nil frontDoorBridgeUrl:nil codeVerifier:nil];
    session.isAuthenticating = YES;
    return session;
}

- (SFSDKAuthRequest *)standardWebRequestForScene:(UIScene *)scene {
    SFSDKAuthRequest *request = [[SFSDKAuthRequest alloc] init];
    request.oauthClientId = @"testClientId";
    request.oauthCompletionUrl = @"testapp://callback";
    request.loginHost = @"login.salesforce.com";
    request.scene = scene;
    return request;
}

- (NSURL *)frontDoorBridgeURLWithClientId:(NSString *)clientId identifier:(NSString *)identifier {
    NSString *startURL = [NSString stringWithFormat:@"https://login.salesforce.com/services/oauth2/authorize?client_id=%@&state=%@", clientId, identifier];
    NSString *encodedStartURL = [startURL stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    return [NSURL URLWithString:[NSString stringWithFormat:@"https://login.salesforce.com/bridge?startURL=%@", encodedStartURL]];
}

- (void)testMigrateRefreshAuthRequest {
    // Setup SFSDKAppConfig with test data
    NSString *testConsumerKey = @"TestConsumerKey123";
    NSString *testRedirectURI = @"testapp://oauth/callback";
    
    NSDictionary *configDict = @{
        @"remoteAccessConsumerKey": testConsumerKey,
        @"oauthRedirectURI": testRedirectURI,
        @"oauthScopes": @[@"api", @"refresh_token"]
    };
    
    SFSDKAppConfig *appConfig = [[SFSDKAppConfig alloc] initWithDict:configDict];
    XCTAssertNotNil(appConfig, @"Failed to create SFSDKAppConfig");
    
    // Call migrateRefreshAuthRequest
    SFSDKAuthRequest *request = [self.uam migrateRefreshAuthRequest:appConfig];
    
    // Verify the request properties
    XCTAssertNotNil(request, @"Request should not be nil");
    XCTAssertEqualObjects(request.oauthClientId, testConsumerKey, @"OAuth client ID should match app config");
    XCTAssertEqualObjects(request.oauthCompletionUrl, testRedirectURI, @"OAuth redirect URI should match app config");
    XCTAssertEqualObjects(request.loginHost, self.uam.loginHost, @"Login host should match user account manager");
    XCTAssertEqualObjects(request.additionalOAuthParameterKeys, self.uam.additionalOAuthParameterKeys, @"Additional OAuth parameter keys should match user account manager");
    XCTAssertNotNil(request.scene, @"Scene should be set");
}

- (void)testMigrateRefreshToken {
    // Create a test user account
    SFUserAccount *testUser = [self createNewUserWithIndex:0];
    testUser.credentials.refreshToken = @"oldRefreshToken123";
    [self.uam setCurrentUserInternal:testUser];
    
    // Setup SFSDKAppConfig
    NSString *testConsumerKey = @"NewConsumerKey456";
    NSString *testRedirectURI = @"newapp://oauth/callback";
    NSDictionary *configDict = @{
        @"remoteAccessConsumerKey": testConsumerKey,
        @"oauthRedirectURI": testRedirectURI,
        @"oauthScopes": @[@"api", @"refresh_token"]
    };
    SFSDKAppConfig *appConfig = [[SFSDKAppConfig alloc] initWithDict:configDict];
    
    __block BOOL successCallbackInvoked = NO;
    __block BOOL failureCallbackInvoked = NO;
    __block SFOAuthInfo *capturedAuthInfo = nil;
    __block SFUserAccount *capturedUserAccount = nil;
    __block NSError *capturedError = nil;
    
    // Call migrateRefreshToken - this sets up the auth session but doesn't execute the async dispatch
    [self.uam migrateRefreshToken:testUser
                     newAppConfig:appConfig
                          success:^(SFOAuthInfo *authInfo, SFUserAccount *userAccount) {
                              successCallbackInvoked = YES;
                              capturedAuthInfo = authInfo;
                              capturedUserAccount = userAccount;
                          }
                          failure:^(SFOAuthInfo *authInfo, NSError *error) {
                              failureCallbackInvoked = YES;
                              capturedError = error;
                          }];
    
    // Get the auth session that was created - use the first one in the dictionary
    NSArray *allKeys = self.uam.authSessions.allKeys;
    XCTAssertTrue(allKeys.count > 0, @"Auth session should have been created");
    NSString *sceneId = allKeys.firstObject;
    SFSDKAuthSession *authSession = self.uam.authSessions[sceneId];
    
    // Verify the auth session was created and configured correctly
    XCTAssertNotNil(authSession, @"Auth session should be created");
    XCTAssertTrue(authSession.isAuthenticating, @"Auth session should be in authenticating state");
    XCTAssertNotNil(authSession.authSuccessCallback, @"Success callback should be set");
    XCTAssertNotNil(authSession.authFailureCallback, @"Failure callback should be set");
    XCTAssertEqualObjects(authSession.oauthRequest.oauthClientId, testConsumerKey, @"OAuth client ID should match");
    XCTAssertEqualObjects(authSession.oauthRequest.oauthCompletionUrl, testRedirectURI, @"OAuth redirect URI should match");
    XCTAssertEqual(authSession.oauthCoordinator.delegate, self.uam, @"OAuth coordinator delegate should be user account manager");
    
    // Test the success callback with same refresh token (no revocation)
    SFOAuthInfo *testAuthInfo = [[SFOAuthInfo alloc] initWithAuthType:SFOAuthTypeRefresh];
    SFUserAccount *newUserAccount = [self createNewUserWithIndex:1];
    newUserAccount.credentials.refreshToken = @"oldRefreshToken123"; // Same token
    
    authSession.authSuccessCallback(testAuthInfo, newUserAccount);
    
    XCTAssertTrue(successCallbackInvoked, @"Success callback should be invoked");
    XCTAssertEqual(capturedAuthInfo, testAuthInfo, @"Auth info should be passed through");
    XCTAssertEqual(capturedUserAccount, newUserAccount, @"User account should be passed through");
    XCTAssertFalse(failureCallbackInvoked, @"Failure callback should not be invoked");
    
    // Reset for next test
    successCallbackInvoked = NO;
    capturedAuthInfo = nil;
    capturedUserAccount = nil;
    
    // Test the success callback with different refresh token (should trigger revocation)
    // Clean up previous session
    [self.uam.authSessions removeObject:sceneId];
    
    // Create a new session since we need to test fresh callback
    [self.uam migrateRefreshToken:testUser
                     newAppConfig:appConfig
                          success:^(SFOAuthInfo *authInfo, SFUserAccount *userAccount) {
                              successCallbackInvoked = YES;
                              capturedAuthInfo = authInfo;
                              capturedUserAccount = userAccount;
                          }
                          failure:^(SFOAuthInfo *authInfo, NSError *error) {
                              failureCallbackInvoked = YES;
                              capturedError = error;
                          }];
    
    // Get the new auth session
    allKeys = self.uam.authSessions.allKeys;
    sceneId = allKeys.firstObject;
    authSession = self.uam.authSessions[sceneId];
    
    SFUserAccount *newUserAccountWithDifferentToken = [self createNewUserWithIndex:2];
    newUserAccountWithDifferentToken.credentials.refreshToken = @"newRefreshToken789"; // Different token
    
    authSession.authSuccessCallback(testAuthInfo, newUserAccountWithDifferentToken);
    
    XCTAssertTrue(successCallbackInvoked, @"Success callback should be invoked");
    XCTAssertEqual(capturedAuthInfo, testAuthInfo, @"Auth info should be passed through");
    XCTAssertEqual(capturedUserAccount, newUserAccountWithDifferentToken, @"User account should be passed through");
    
    // Test the failure callback
    failureCallbackInvoked = NO;
    successCallbackInvoked = NO;
    
    NSError *testError = [NSError errorWithDomain:@"TestErrorDomain" code:123 userInfo:@{@"message": @"Test error"}];
    authSession.authFailureCallback(testAuthInfo, testError);
    
    XCTAssertTrue(failureCallbackInvoked, @"Failure callback should be invoked");
    XCTAssertEqual(capturedError, testError, @"Error should be passed through");
    XCTAssertFalse(successCallbackInvoked, @"Success callback should not be invoked");
    
    // Clean up
    [self.uam.authSessions removeObject:sceneId];
}

- (void)testNotifyLoginCompletion_PostsMigrateRefreshTokenNotification {
    // Given
    SFUserAccount *testUser = [self createNewUserWithIndex:0];

    SFOAuthInfo *authInfo = [[SFOAuthInfo alloc] initWithAuthType:SFOAuthTypeRefreshTokenMigration];

    __block BOOL notificationReceived = NO;
    __block NSDictionary *receivedUserInfo = nil;

    // Set up notification observer
    id observer = [[NSNotificationCenter defaultCenter] addObserverForName:kSFNotificationUserDidMigrateRefreshToken
                                                                    object:self.uam
                                                                     queue:nil
                                                                usingBlock:^(NSNotification *notification) {
        notificationReceived = YES;
        receivedUserInfo = notification.userInfo;
    }];

    // When
    [self.uam notifyLoginCompletion:testUser authInfo:authInfo];

    // Then
    XCTAssertTrue(notificationReceived, @"Should have received kSFNotificationUserDidMigrateRefreshToken notification");
    XCTAssertNotNil(receivedUserInfo, @"Notification userInfo should not be nil");
    XCTAssertEqual(receivedUserInfo[kSFNotificationUserInfoAccountKey], testUser, @"User account should match in notification userInfo");
    XCTAssertEqual(receivedUserInfo[kSFNotificationUserInfoAuthTypeKey], authInfo, @"Auth info should match in notification userInfo");

    // Clean up
    [[NSNotificationCenter defaultCenter] removeObserver:observer];
}
@end
