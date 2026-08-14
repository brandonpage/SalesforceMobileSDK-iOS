/*
Copyright (c) 2019-present, salesforce.com, inc. All rights reserved.

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

#import "SFSDKAuthSession.h"
#import "SFSDKAuthRequest.h"
#import "SFOAuthCredentials+Internal.h"
#import "SFUserAccountManager+Internal.h"
#import "SFOAuthCoordinator+Internal.h"
#import "SFIdentityCoordinator.h"
#import "SalesforceSDKManager+Internal.h"
#import "SFSDKLoginViewControllerConfig.h"
#import "SFSDKAppFeatureMarkers.h"

// Prefix for the synthesized scene id used when a login starts before any UIScene has connected.
static NSString * const kSFSDKAuthSessionUnscopedSceneIdPrefix = @"com.salesforce.mobilesdk.unscopedAuthSession-";

@interface SFSDKStandardWebAuthIntent : NSObject

@property (nonatomic, copy) NSString *oauthClientId;
@property (nonatomic, copy) NSString *oauthCompletionUrl;
@property (nonatomic, copy) NSString *loginHost;
@property (nonatomic, copy) NSString *effectiveLoginHost;
@property (nonatomic, copy) NSString *loginHint;
@property (nonatomic, copy) NSURL *frontDoorBridgeUrl;
@property (nonatomic, copy) NSString *codeVerifier;
@property (nonatomic, copy) NSSet<NSString *> *scopes;
@property (nonatomic, copy) NSArray<NSString *> *additionalOAuthParameterKeys;
@property (nonatomic, copy) NSDictionary<NSString *, id> *additionalTokenRefreshParams;
@property (nonatomic, copy) NSString *brandLoginPath;
@property (nonatomic, assign) BOOL retryLoginAfterFailure;
@property (nonatomic, assign) BOOL useBrowserAuth;
@property (nonatomic, assign) BOOL loginAsAdmin;
@property (nonatomic, copy) NSString *loginAsAdminMyDomain;
@property (nonatomic, copy) NSString *loginAsAdminLoginHint;
@property (nonatomic, strong) SFSDKLoginViewControllerConfig *loginViewControllerConfig;
@property (nonatomic, strong) UIFont *navBarFont;
@property (nonatomic, strong) UIColor *navBarTintColor;
@property (nonatomic, strong) UIColor *navBarColor;
@property (nonatomic, strong) UIColor *navBarTitleColor;
@property (nonatomic, assign) BOOL showNavbar;
@property (nonatomic, assign) BOOL showSettingsIcon;
@property (nonatomic, assign) BOOL showServerPicker;
@property (nonatomic, assign) BOOL shouldDisplayBackButton;
@property (nonatomic, weak) id<SFLoginViewControllerDelegate> loginViewControllerDelegate;
@property (nonatomic, copy) SFLoginViewControllerCreationBlock loginViewControllerCreationBlock;
@property (nonatomic, assign) BOOL forceAdvancedAuthentication;
@property (nonatomic, assign) BOOL useEphemeralSessionForAdvancedAuth;
@property (nonatomic, assign) BOOL useWebServerAuthentication;
@property (nonatomic, assign) BOOL useHybridAuthentication;
@property (nonatomic, assign) BOOL useDPoP;
@property (nonatomic, assign) BOOL appAttestationEnabled;
@property (nonatomic, copy) WKNavigationActionPolicy (^navigationPolicyForAction)(WKWebView *, WKNavigationAction *);
@property (nonatomic, copy) WKWebView *(^createWebview)(WKWebView *, WKWebViewConfiguration *, WKNavigationAction *, WKWindowFeatures *);
@property (nonatomic, assign) BOOL showAuthWindowWhileLoading;
@property (nonatomic, assign) BOOL loginWebviewInspectable;
@property (nonatomic, copy) SFSDKAppConfigRuntimeSelectorBlock appConfigRuntimeSelectorBlock;

@end

@implementation SFSDKStandardWebAuthIntent
@end

@interface SFSDKAuthSession ()

@property (nonatomic, assign) BOOL presentationStarted;
@property (nonatomic, assign) BOOL participatesInStandardWebSceneReassociation;
@property (nonatomic, strong) id authenticationRecoveryToken;
@property (nonatomic, strong) NSError *authenticationRecoveryError;
@property (nonatomic, assign) BOOL authenticationRecoveryClaimed;
@property (nonatomic, assign) BOOL authenticationStartupClaimRequired;
@property (nonatomic, assign) BOOL authenticationStartupClaimed;
@property (nonatomic, assign) BOOL authenticationStartupStarted;
@property (nonatomic, assign) BOOL authenticationCompleted;
@property (nonatomic, strong) SFOAuthInfo *terminalAuthInfo;
@property (nonatomic, strong) SFUserAccount *terminalUserAccount;
@property (nonatomic, strong) NSError *terminalError;
@property (nonatomic, copy) void (^primaryAuthSuccessCallback)(SFOAuthInfo *, SFUserAccount *);
@property (nonatomic, copy) void (^primaryAuthFailureCallback)(SFOAuthInfo *, NSError *);
@property (nonatomic, strong) NSMutableArray *additionalAuthSuccessCallbacks;
@property (nonatomic, strong) NSMutableArray *additionalAuthFailureCallbacks;
@property (nonatomic, strong) NSMutableArray *pendingTerminalCallbacks;
@property (nonatomic, assign) BOOL deliveringTerminalCallbacks;
@property (nonatomic, strong) SFSDKStandardWebAuthIntent *standardWebAuthIntent;
@property (nonatomic, assign) BOOL forceAdvancedAuthenticationAtStart;
@property (nonatomic, strong) NSMutableSet<NSString *> *mutableTransientAuthFeatures;
@property (nonatomic, assign) BOOL presentationContinuationsRevoked;

@end

@interface SFSDKAppFeatureMarkers (AuthSessionOwnership)

+ (void)registerAuthSessionFeature:(NSString *)appFeature;
+ (void)unregisterAuthSessionFeature:(NSString *)appFeature;

@end

@implementation SFSDKAuthSession

-(instancetype)initWith:(SFSDKAuthRequest *)request {
    return [self initWith:request credentials:nil];
}

-(instancetype)initWith:(SFSDKAuthRequest *)request credentials:(SFOAuthCredentials *)creds {
    return [self initWith:request credentials:creds routingSceneId:nil];
}

-(instancetype)initWith:(SFSDKAuthRequest *)request credentials:(SFOAuthCredentials *)creds routingSceneId:(NSString *)routingSceneId {
    if (self = [self initWith:request credentials:creds spAppCredentials:nil]) {
        if (!request.scene && routingSceneId.length > 0) {
            _sceneId = [routingSceneId copy];
        }
    }
    return self;
}

-(instancetype)initWith:(SFSDKAuthRequest *)request credentials:(SFOAuthCredentials *)creds spAppCredentials:(SFOAuthCredentials *)spAppCredentials {
    if (self = [super init]) {
        _oauthRequest = request;
        _credentials = (creds == nil) ? [self newClientCredentials] : creds;
        _credentials.jwt = request.jwtToken;
        _spAppCredentials = spAppCredentials;
        // When no scene is connected yet, persistentIdentifier is nil; synthesize a unique per-session id
        // so this session gets its own authSessions[] key and the browser callback can key back to it.
        _sceneId = request.scene.session.persistentIdentifier ?: [kSFSDKAuthSessionUnscopedSceneIdPrefix stringByAppendingString:[[NSUUID UUID] UUIDString]];
        _additionalAuthSuccessCallbacks = [NSMutableArray array];
        _additionalAuthFailureCallbacks = [NSMutableArray array];
        _pendingTerminalCallbacks = [NSMutableArray array];
        _forceAdvancedAuthenticationAtStart = [SalesforceSDKManager sharedManager].sdk_forceAdvancedAuthentication;
        _mutableTransientAuthFeatures = [NSMutableSet set];
        [self initCoordinator];
    }
    return self;
}

-(BOOL)associateWithSceneIfUnscoped:(UIScene *)scene {
    @synchronized (self) {
        if (!self.participatesInStandardWebSceneReassociation || self.oauthRequest.scene || !scene || self.presentationStarted || self.oauthCoordinator.asWebAuthenticationSession) {
            return NO;
        }
        self.oauthRequest.scene = scene;
        _sceneId = scene.session.persistentIdentifier;
        return YES;
    }
}

-(void)captureStandardWebAuthIntentWithLoginHint:(NSString *)loginHint
                              frontDoorBridgeUrl:(NSURL *)frontDoorBridgeUrl
                                    codeVerifier:(NSString *)codeVerifier {
    @synchronized (self) {
        SFSDKAuthCoordinatorFrontdoorBridgeLoginOverride *bridgeOverride = frontDoorBridgeUrl == nil ? nil :
            [[SFSDKAuthCoordinatorFrontdoorBridgeLoginOverride alloc] initWithFrontdoorBridgeUrl:frontDoorBridgeUrl
                                                                                codeVerifier:codeVerifier];
        BOOL usesLfaOverride = self.oauthRequest.loginAsAdmin && self.oauthRequest.loginAsAdminMyDomain.length > 0;
        SFSDKLoginViewControllerConfig *config = self.oauthRequest.loginViewControllerConfig;
        SalesforceSDKManager *sdkManager = [SalesforceSDKManager sharedManager];
        SFSDKStandardWebAuthIntent *intent = [SFSDKStandardWebAuthIntent new];
        intent.oauthClientId = self.oauthRequest.oauthClientId;
        intent.oauthCompletionUrl = self.oauthRequest.oauthCompletionUrl;
        intent.loginHost = self.oauthRequest.loginHost;
        intent.effectiveLoginHost = usesLfaOverride ? self.oauthRequest.loginAsAdminMyDomain : self.oauthRequest.loginHost;
        intent.loginHint = usesLfaOverride ? self.oauthRequest.loginAsAdminLoginHint : loginHint;
        intent.frontDoorBridgeUrl = bridgeOverride.frontdoorBridgeUrl;
        intent.codeVerifier = bridgeOverride.codeVerifier;
        intent.scopes = self.oauthRequest.scopes;
        intent.additionalOAuthParameterKeys = self.oauthRequest.additionalOAuthParameterKeys;
        intent.additionalTokenRefreshParams = self.oauthRequest.additionalTokenRefreshParams;
        intent.brandLoginPath = self.oauthRequest.brandLoginPath;
        intent.retryLoginAfterFailure = self.oauthRequest.retryLoginAfterFailure;
        intent.useBrowserAuth = self.oauthRequest.useBrowserAuth || self.oauthRequest.loginAsAdmin;
        intent.loginAsAdmin = self.oauthRequest.loginAsAdmin;
        intent.loginAsAdminMyDomain = self.oauthRequest.loginAsAdminMyDomain;
        intent.loginAsAdminLoginHint = self.oauthRequest.loginAsAdminLoginHint;
        intent.loginViewControllerConfig = config;
        intent.navBarFont = config.navBarFont;
        intent.navBarTintColor = config.navBarTintColor;
        intent.navBarColor = config.navBarColor;
        intent.navBarTitleColor = config.navBarTitleColor;
        intent.showNavbar = config.showNavbar;
        intent.showSettingsIcon = config.showSettingsIcon;
        intent.showServerPicker = config.showServerPicker;
        intent.shouldDisplayBackButton = config.shouldDisplayBackButton;
        intent.loginViewControllerDelegate = config.delegate;
        intent.loginViewControllerCreationBlock = config.loginViewControllerCreationBlock;
        intent.forceAdvancedAuthentication = sdkManager.sdk_forceAdvancedAuthentication;
        intent.useEphemeralSessionForAdvancedAuth = sdkManager.useEphemeralSessionForAdvancedAuth;
        intent.useWebServerAuthentication = sdkManager.useWebServerAuthentication;
        intent.useHybridAuthentication = sdkManager.useHybridAuthentication;
        intent.useDPoP = sdkManager.useDPoP;
        intent.appAttestationEnabled = [SFUserAccountManager sharedInstance].appAttestationEnabled;
        intent.navigationPolicyForAction = [SFUserAccountManager sharedInstance].navigationPolicyForAction;
        intent.createWebview = [SFUserAccountManager sharedInstance].createWebview;
        intent.showAuthWindowWhileLoading = [SFUserAccountManager sharedInstance].showAuthWindowWhileLoading;
        intent.loginWebviewInspectable = sdkManager.isLoginWebviewInspectable;
        intent.appConfigRuntimeSelectorBlock = sdkManager.appConfigRuntimeSelectorBlock;
        self.standardWebAuthIntent = intent;
        self.participatesInStandardWebSceneReassociation = YES;
    }
}

-(NSSet<NSString *> *)transientAuthFeatures {
    @synchronized (self) {
        return [self.mutableTransientAuthFeatures copy];
    }
}

-(void)setTransientAuthFeature:(NSString *)feature enabled:(BOOL)enabled {
    if (feature.length == 0) {
        return;
    }
    @synchronized (self) {
        BOOL containsFeature = [self.mutableTransientAuthFeatures containsObject:feature];
        if (containsFeature == enabled) {
            return;
        }
        if (enabled) {
            [self.mutableTransientAuthFeatures addObject:feature];
            [SFSDKAppFeatureMarkers registerAuthSessionFeature:feature];
        } else {
            [self.mutableTransientAuthFeatures removeObject:feature];
            [SFSDKAppFeatureMarkers unregisterAuthSessionFeature:feature];
        }
    }
}

-(void)clearTransientAuthFeatures {
    for (NSString *feature in self.transientAuthFeatures) {
        [self setTransientAuthFeature:feature enabled:NO];
    }
}

-(void)markPresentationStarted {
    @synchronized (self) {
        self.presentationStarted = YES;
    }
}

-(BOOL)performPresentationContinuation:(void (^)(void))continuationBlock {
    BOOL continuationAccepted = YES;
    @synchronized (self) {
        if (self.participatesInStandardWebSceneReassociation && self.presentationContinuationsRevoked) {
            continuationAccepted = NO;
        }
    }
    if (continuationAccepted && continuationBlock) {
        continuationBlock();
    }
    return continuationAccepted;
}

-(void)revokePresentationContinuations {
    @synchronized (self) {
        self.presentationContinuationsRevoked = YES;
    }
}

-(BOOL)claimAuthenticationStartup {
    @synchronized (self) {
        if (!self.isAuthenticating || self.authenticationStartupClaimed || self.authenticationStartupStarted) {
            return NO;
        }
        self.authenticationStartupClaimRequired = YES;
        self.authenticationStartupClaimed = YES;
        return YES;
    }
}

-(void)cancelAuthenticationStartup {
    @synchronized (self) {
        self.authenticationStartupClaimed = NO;
    }
}

-(void)performClaimedAuthenticationStartup:(void (^)(void))startupBlock {
    @synchronized (self) {
        if (!self.authenticationStartupClaimRequired) {
            startupBlock();
            return;
        }
        if (!self.authenticationStartupClaimed || !self.isAuthenticating || self.authenticationStartupStarted) {
            return;
        }
        self.authenticationStartupClaimed = NO;
        self.authenticationStartupStarted = YES;
        startupBlock();
    }
}

- (BOOL)authenticationRecoveryPending {
    @synchronized (self) {
        return self.authenticationRecoveryToken != nil;
    }
}

- (void)setAuthenticationRecoveryPending:(BOOL)authenticationRecoveryPending {
    @synchronized (self) {
        if (authenticationRecoveryPending) {
            if (!self.authenticationRecoveryToken) {
                self.authenticationRecoveryToken = [NSObject new];
            }
        } else {
            self.authenticationRecoveryToken = nil;
            self.authenticationRecoveryError = nil;
            self.authenticationRecoveryClaimed = NO;
        }
    }
}

- (id)beginAuthenticationRecoveryWithError:(NSError *)error {
    @synchronized (self) {
        if (self.authenticationCompleted || self.authenticationRecoveryToken) {
            return nil;
        }
        self.authenticationRecoveryToken = [NSObject new];
        self.authenticationRecoveryError = error;
        self.authenticationRecoveryClaimed = NO;
        return self.authenticationRecoveryToken;
    }
}

- (BOOL)claimAuthenticationRecoveryWithToken:(id)recoveryToken {
    @synchronized (self) {
        if (!recoveryToken || self.authenticationRecoveryToken != recoveryToken || self.authenticationRecoveryClaimed) {
            return NO;
        }
        self.authenticationRecoveryClaimed = YES;
        return YES;
    }
}

- (BOOL)performClaimedAuthenticationRecoveryWithToken:(id)recoveryToken block:(void (^)(void))block {
    @synchronized (self) {
        if (!recoveryToken || self.authenticationRecoveryToken != recoveryToken || !self.authenticationRecoveryClaimed) {
            return NO;
        }
        if (block) {
            block();
        }
        return YES;
    }
}

- (void)revokeAuthenticationRecoveryClaim {
    @synchronized (self) {
        self.authenticationRecoveryClaimed = NO;
    }
}

- (NSError *)endAuthenticationRecoveryWithToken:(id)recoveryToken {
    @synchronized (self) {
        if (!recoveryToken || self.authenticationRecoveryToken != recoveryToken) {
            return nil;
        }
        NSError *error = self.authenticationRecoveryError;
        self.authenticationRecoveryToken = nil;
        self.authenticationRecoveryError = nil;
        self.authenticationRecoveryClaimed = NO;
        return error;
    }
}

- (NSError *)endPendingAuthenticationRecovery {
    @synchronized (self) {
        if (!self.authenticationRecoveryToken) {
            return nil;
        }
        NSError *error = self.authenticationRecoveryError;
        self.authenticationRecoveryToken = nil;
        self.authenticationRecoveryError = nil;
        self.authenticationRecoveryClaimed = NO;
        return error;
    }
}

- (BOOL)cancelPendingAuthenticationRecovery {
    @synchronized (self) {
        if (!self.authenticationRecoveryToken) {
            return NO;
        }
        self.authenticationRecoveryToken = nil;
        self.authenticationRecoveryError = nil;
        self.authenticationRecoveryClaimed = NO;
        self.isAuthenticating = NO;
        [self clearAuthCallbacks];
        return YES;
    }
}

- (void)releaseAuthCallbacks {
    @synchronized (self) {
        [self clearAuthCallbacks];
    }
}

-(void)appendAuthSuccessCallback:(void (^)(SFOAuthInfo *, SFUserAccount *))successCallback
                 failureCallback:(void (^)(SFOAuthInfo *, NSError *))failureCallback {
    void (^terminalCallback)(void) = [self registerAuthSuccessCallback:successCallback failureCallback:failureCallback];
    if (terminalCallback) {
        terminalCallback();
    }
}

-(void (^)(SFOAuthInfo *, SFUserAccount *))authSuccessCallback {
    @synchronized (self) {
        if (self.additionalAuthSuccessCallbacks.count == 0) {
            return self.primaryAuthSuccessCallback;
        }
        NSArray *callbacks = [self successCallbacksSnapshot];
        return ^(SFOAuthInfo *authInfo, SFUserAccount *userAccount) {
            for (void (^callback)(SFOAuthInfo *, SFUserAccount *) in callbacks) {
                callback(authInfo, userAccount);
            }
        };
    }
}

-(void)setAuthSuccessCallback:(void (^)(SFOAuthInfo *, SFUserAccount *))authSuccessCallback {
    @synchronized (self) {
        self.primaryAuthSuccessCallback = authSuccessCallback;
        [self.additionalAuthSuccessCallbacks removeAllObjects];
    }
}

-(void (^)(SFOAuthInfo *, NSError *))authFailureCallback {
    @synchronized (self) {
        if (self.additionalAuthFailureCallbacks.count == 0) {
            return self.primaryAuthFailureCallback;
        }
        NSArray *callbacks = [self failureCallbacksSnapshot];
        return ^(SFOAuthInfo *authInfo, NSError *error) {
            for (void (^callback)(SFOAuthInfo *, NSError *) in callbacks) {
                callback(authInfo, error);
            }
        };
    }
}

-(void)setAuthFailureCallback:(void (^)(SFOAuthInfo *, NSError *))authFailureCallback {
    @synchronized (self) {
        self.primaryAuthFailureCallback = authFailureCallback;
        [self.additionalAuthFailureCallbacks removeAllObjects];
    }
}

-(void (^)(void))registerAuthSuccessCallback:(void (^)(SFOAuthInfo *, SFUserAccount *))successCallback
                             failureCallback:(void (^)(SFOAuthInfo *, NSError *))failureCallback {
    SFOAuthInfo *terminalAuthInfo = nil;
    SFUserAccount *terminalUserAccount = nil;
    NSError *terminalError = nil;
    @synchronized (self) {
        if (self.authenticationCompleted) {
            terminalAuthInfo = self.terminalAuthInfo;
            terminalUserAccount = self.terminalUserAccount;
            terminalError = self.terminalError;
        } else if (successCallback) {
            if (self.primaryAuthSuccessCallback) {
                [self.additionalAuthSuccessCallbacks addObject:[successCallback copy]];
            } else {
                self.primaryAuthSuccessCallback = successCallback;
            }
        }
        if (!self.authenticationCompleted && failureCallback) {
            if (self.primaryAuthFailureCallback) {
                [self.additionalAuthFailureCallbacks addObject:[failureCallback copy]];
            } else {
                self.primaryAuthFailureCallback = failureCallback;
            }
        }
    }
    if (terminalUserAccount && successCallback) {
        return ^{
            [self enqueueTerminalCallback:^{
                successCallback(terminalAuthInfo, terminalUserAccount);
            }];
        };
    }
    if (terminalError && failureCallback) {
        return ^{
            [self enqueueTerminalCallback:^{
                failureCallback(terminalAuthInfo, terminalError);
            }];
        };
    }
    return nil;
}

-(void)completeAuthenticationWithAuthInfo:(SFOAuthInfo *)authInfo userAccount:(SFUserAccount *)userAccount {
    BOOL shouldDrain = NO;
    @synchronized (self) {
        if (self.authenticationCompleted) {
            return;
        }
        self.authenticationCompleted = YES;
        self.isAuthenticating = NO;
        self.terminalAuthInfo = authInfo;
        self.terminalUserAccount = userAccount;
        for (void (^successCallback)(SFOAuthInfo *, SFUserAccount *) in [self successCallbacksSnapshot]) {
            [self.pendingTerminalCallbacks addObject:[^{
                successCallback(authInfo, userAccount);
            } copy]];
        }
        [self clearAuthCallbacks];
        shouldDrain = [self beginTerminalCallbackDeliveryIfNeeded];
    }
    if (shouldDrain) {
        [self drainTerminalCallbacks];
    }
}

-(void)completeAuthenticationWithAuthInfo:(SFOAuthInfo *)authInfo error:(NSError *)error {
    BOOL shouldDrain = NO;
    @synchronized (self) {
        if (self.authenticationCompleted) {
            return;
        }
        self.authenticationCompleted = YES;
        self.isAuthenticating = NO;
        self.terminalAuthInfo = authInfo;
        self.terminalError = error;
        for (void (^failureCallback)(SFOAuthInfo *, NSError *) in [self failureCallbacksSnapshot]) {
            [self.pendingTerminalCallbacks addObject:[^{
                failureCallback(authInfo, error);
            } copy]];
        }
        [self clearAuthCallbacks];
        shouldDrain = [self beginTerminalCallbackDeliveryIfNeeded];
    }
    if (shouldDrain) {
        [self drainTerminalCallbacks];
    }
}

-(NSArray *)successCallbacksSnapshot {
    NSMutableArray *callbacks = [NSMutableArray array];
    if (self.primaryAuthSuccessCallback) {
        [callbacks addObject:self.primaryAuthSuccessCallback];
    }
    [callbacks addObjectsFromArray:self.additionalAuthSuccessCallbacks];
    return callbacks;
}

-(NSArray *)failureCallbacksSnapshot {
    NSMutableArray *callbacks = [NSMutableArray array];
    if (self.primaryAuthFailureCallback) {
        [callbacks addObject:self.primaryAuthFailureCallback];
    }
    [callbacks addObjectsFromArray:self.additionalAuthFailureCallbacks];
    return callbacks;
}

-(void)clearAuthCallbacks {
    self.primaryAuthSuccessCallback = nil;
    self.primaryAuthFailureCallback = nil;
    [self.additionalAuthSuccessCallbacks removeAllObjects];
    [self.additionalAuthFailureCallbacks removeAllObjects];
}

-(void)enqueueTerminalCallback:(void (^)(void))callback {
    BOOL shouldDrain = NO;
    @synchronized (self) {
        [self.pendingTerminalCallbacks addObject:[callback copy]];
        shouldDrain = [self beginTerminalCallbackDeliveryIfNeeded];
    }
    if (shouldDrain) {
        [self drainTerminalCallbacks];
    }
}

-(BOOL)beginTerminalCallbackDeliveryIfNeeded {
    if (self.deliveringTerminalCallbacks || self.pendingTerminalCallbacks.count == 0) {
        return NO;
    }
    self.deliveringTerminalCallbacks = YES;
    return YES;
}

-(void)drainTerminalCallbacks {
    while (YES) {
        NSArray *callbacks = nil;
        @synchronized (self) {
            if (self.pendingTerminalCallbacks.count == 0) {
                self.deliveringTerminalCallbacks = NO;
                return;
            }
            callbacks = [self.pendingTerminalCallbacks copy];
            [self.pendingTerminalCallbacks removeAllObjects];
        }
        for (void (^callback)(void) in callbacks) {
            callback();
        }
    }
}

-(BOOL)matchesStandardWebRequest:(SFSDKAuthRequest *)request
                       loginHint:(NSString *)loginHint
              frontDoorBridgeUrl:(NSURL *)frontDoorBridgeUrl
                    codeVerifier:(NSString *)codeVerifier {
    @synchronized (self) {
        SFSDKStandardWebAuthIntent *intent = self.standardWebAuthIntent;
        SFSDKAuthCoordinatorFrontdoorBridgeLoginOverride *requestedBridgeOverride = frontDoorBridgeUrl == nil ? nil :
            [[SFSDKAuthCoordinatorFrontdoorBridgeLoginOverride alloc] initWithFrontdoorBridgeUrl:frontDoorBridgeUrl
                                                                                codeVerifier:codeVerifier];
        BOOL hasRejectedRawBridgeRequest = frontDoorBridgeUrl != nil && requestedBridgeOverride.frontdoorBridgeUrl == nil;
        BOOL requestedUsesLfaOverride = request.loginAsAdmin && request.loginAsAdminMyDomain.length > 0;
        NSString *requestedEffectiveLoginHost = requestedUsesLfaOverride ? request.loginAsAdminMyDomain : request.loginHost;
        NSString *requestedLoginHint = requestedUsesLfaOverride ? request.loginAsAdminLoginHint : loginHint;
        SalesforceSDKManager *sdkManager = [SalesforceSDKManager sharedManager];
        SFUserAccountManager *userAccountManager = [SFUserAccountManager sharedInstance];
        return self.participatesInStandardWebSceneReassociation && intent != nil &&
            !hasRejectedRawBridgeRequest &&
            [self nullableObject:intent.oauthClientId isEqualTo:request.oauthClientId] &&
            [self nullableObject:intent.oauthCompletionUrl isEqualTo:request.oauthCompletionUrl] &&
            [self nullableObject:intent.loginHost isEqualTo:request.loginHost] &&
            [self nullableObject:intent.effectiveLoginHost isEqualTo:requestedEffectiveLoginHost] &&
            [self nullableObject:intent.loginHint isEqualTo:requestedLoginHint] &&
            [self nullableObject:intent.frontDoorBridgeUrl isEqualTo:requestedBridgeOverride.frontdoorBridgeUrl] &&
            [self nullableObject:intent.codeVerifier isEqualTo:requestedBridgeOverride.codeVerifier] &&
            [self nullableObject:intent.scopes isEqualTo:request.scopes] &&
            [self nullableObject:intent.additionalOAuthParameterKeys isEqualTo:request.additionalOAuthParameterKeys] &&
            [self nullableObject:intent.additionalTokenRefreshParams isEqualTo:request.additionalTokenRefreshParams] &&
            [self nullableObject:intent.brandLoginPath isEqualTo:request.brandLoginPath] &&
            intent.retryLoginAfterFailure == request.retryLoginAfterFailure &&
            intent.useBrowserAuth == (request.useBrowserAuth || request.loginAsAdmin) &&
            intent.loginAsAdmin == request.loginAsAdmin &&
            [self nullableObject:intent.loginAsAdminMyDomain isEqualTo:request.loginAsAdminMyDomain] &&
            [self nullableObject:intent.loginAsAdminLoginHint isEqualTo:request.loginAsAdminLoginHint] &&
            [self loginViewControllerConfig:request.loginViewControllerConfig matchesIntent:intent] &&
            intent.forceAdvancedAuthentication == sdkManager.sdk_forceAdvancedAuthentication &&
            intent.useEphemeralSessionForAdvancedAuth == sdkManager.useEphemeralSessionForAdvancedAuth &&
            intent.useWebServerAuthentication == sdkManager.useWebServerAuthentication &&
            intent.useHybridAuthentication == sdkManager.useHybridAuthentication &&
            intent.useDPoP == sdkManager.useDPoP &&
            intent.appAttestationEnabled == userAccountManager.appAttestationEnabled &&
            intent.navigationPolicyForAction == userAccountManager.navigationPolicyForAction &&
            intent.createWebview == userAccountManager.createWebview &&
            intent.showAuthWindowWhileLoading == userAccountManager.showAuthWindowWhileLoading &&
            intent.loginWebviewInspectable == sdkManager.isLoginWebviewInspectable &&
            intent.appConfigRuntimeSelectorBlock == sdkManager.appConfigRuntimeSelectorBlock;
    }
}

-(void)dealloc {
    [self clearTransientAuthFeatures];
}

-(BOOL)loginViewControllerConfig:(SFSDKLoginViewControllerConfig *)config matchesIntent:(SFSDKStandardWebAuthIntent *)intent {
    return intent.loginViewControllerConfig == config &&
        [self nullableObject:intent.navBarFont isEqualTo:config.navBarFont] &&
        [self nullableObject:intent.navBarTintColor isEqualTo:config.navBarTintColor] &&
        [self nullableObject:intent.navBarColor isEqualTo:config.navBarColor] &&
        [self nullableObject:intent.navBarTitleColor isEqualTo:config.navBarTitleColor] &&
        intent.showNavbar == config.showNavbar &&
        intent.showSettingsIcon == config.showSettingsIcon &&
        intent.showServerPicker == config.showServerPicker &&
        intent.shouldDisplayBackButton == config.shouldDisplayBackButton &&
        intent.loginViewControllerDelegate == config.delegate &&
        intent.loginViewControllerCreationBlock == config.loginViewControllerCreationBlock;
}

-(BOOL)nullableObject:(id)firstObject isEqualTo:(id)secondObject {
    return firstObject == secondObject || [firstObject isEqual:secondObject];
}

-(void)initCoordinator {
    self.oauthCoordinator = [[SFOAuthCoordinator alloc] initWithAuthSession:self];
    self.oauthCoordinator.spAppCredentials = self.spAppCredentials;
    self.oauthCoordinator.additionalOAuthParameterKeys = self.oauthRequest.additionalOAuthParameterKeys;
    self.oauthCoordinator.additionalTokenRefreshParams = self.oauthRequest.additionalTokenRefreshParams;
    self.oauthCoordinator.scopes = self.oauthRequest.scopes;
    self.oauthCoordinator.brandLoginPath = self.oauthRequest.brandLoginPath;
    self.oauthCoordinator.useBrowserAuth = self.oauthRequest.useBrowserAuth || self.oauthRequest.loginAsAdmin;
    if (_spAppCredentials && _spAppCredentials.domain) {
        self.oauthCoordinator.credentials.domain = _spAppCredentials.domain;
    }
}

- (SFOAuthCredentials *)newClientCredentials {
    NSString *identifier = [[SFUserAccountManager sharedInstance]  uniqueUserAccountIdentifier:self.oauthRequest.oauthClientId];
    SFOAuthCredentials *creds = [[SFOAuthCredentials alloc] initWithIdentifier:identifier clientId:self.oauthRequest.oauthClientId encrypted:YES];
    creds.clientId = self.oauthRequest.oauthClientId;
    creds.redirectUri = self.oauthRequest.oauthCompletionUrl;
    creds.domain = self.oauthRequest.loginHost;
    creds.scopes = [self.oauthRequest.scopes allObjects];
    creds.accessToken = nil;
    return creds;
}

@end
