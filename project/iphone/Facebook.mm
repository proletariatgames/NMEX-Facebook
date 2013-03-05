/*
 * Copyright 2012 Proletariat Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include <DeprecatedHeaders/Facebook.h>
#include "Facebook.h"
#include "FBEvent.h"

namespace nme {
  void PauseAnimation();
  void ResumeAnimation();
}

extern "C" void facebook_send_event(FBEvent &event);
extern "C" void facebook_send_callback(const char *tId, const char *data, const char *error);
@interface NMEAppDelegate : NSObject <UIApplicationDelegate>
{
  UIWindow *window;
  UIViewController *controller;
  BOOL isRunning;
  BOOL isPaused;
}
@end

@interface NMEAppDelegate (FacebookExtensions)
  - (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation;
@end

@implementation NMEAppDelegate (FacebookExtensions)
  // TODO do not use a category here. This is dangerous if you have multiple categories for UIApplicationDelegate with openURL defined
  - (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
  {
    printf("Facebook.mm::openURL\n");
    return [FBSession.activeSession handleOpenURL:url];
  }
@end

@interface FacebookAppDelegate:NSObject
  - (void)applicationActivated:(id)sender;
  -(void)applicationWillTerminate:(id)sender;
@end

@implementation FacebookAppDelegate
  - (id)init {
    self = [super init];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationActivated:)
      name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate:)
      name:UIApplicationWillTerminateNotification object:nil];
    return self;
  }

  - (void)applicationActivated:(id)sender {
    printf("Facebook.mm::applicationDidBecomeActive\n");
    [[FBSession activeSession] handleDidBecomeActive];
  }

  -(void)applicationWillTerminate:(id)sender {
    printf("Facebook.mm::applicationWillTerminate\n");
    [[FBSession activeSession] close];
  }

  - (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
  }
@end

@interface InviteDialogDelegate : NSObject <FBDialogDelegate>
{
  const char *transactionId;
}
@end

@implementation InviteDialogDelegate
  - (id)init:(const char *)tid {
    self = [super init];
    if (self) {
      transactionId = tid;
    }
    return self;
  }

  - (void) dialogCompleteWithUrl:(NSURL *)url {
    facebook_send_callback(transactionId, "", "");
  }

  - (void ) dialogDidComplete:(FBDialog *)dialog {
    nme::ResumeAnimation();
  }

  - (void)dealloc {
    [super dealloc];
  }
@end

@interface FeedDialogDelegate : NSObject <FBDialogDelegate>
{
  const char *transactionId;
}
@end

@implementation FeedDialogDelegate
  - (id)init:(const char *)tid {
    self = [super init];
    if (self) {
      transactionId = tid;
    }
    return self;
  }

  - (void)dialogDidComplete:(FBDialog *)dialog {
    facebook_send_callback(transactionId, "", "");
    nme::ResumeAnimation();
  }

  - (void)dialogDidNotComplete:(FBDialog *)dialog {
    nme::ResumeAnimation();
  }

  - (void)dealloc {
    [super dealloc];
  }
@end

namespace facebook
{
  Facebook *facebook;
  static bool haveRequestedPublishPermissions = false;
  static bool startingSession = false;
  FacebookAppDelegate *nmeAppActivator;

  void init(const char *i_appId);
  void startSession();
  void closeSession();
  bool sessionActive();
  void requestWritePermissions();
  void requestForMe();
  void graphRequest(const char *transactionId, const char *i_graphPath, const char *i_httpMethod,
      const char *i_paramsJSON);
  void invite(const char *transactionId, const char *i_msg);
  void feedPost(const char *transactionId, const char *i_paramsJSON);
  void dispatchHaxeEvent(EventType eventId);
  void checkForOAuthError(NSError *error);

  void init(const char *i_appId) {
    NSString *appId = [[NSString alloc] initWithUTF8String:i_appId];
    [FBSession setDefaultAppID:appId];
    facebook = [[Facebook alloc] initWithAppId:appId andDelegate:nil];
    [facebook retain];
    nmeAppActivator = [[FacebookAppDelegate alloc]init];
    [nmeAppActivator retain];
  }

  void startSession() {
    if ( !startingSession ) {
      startingSession = true;
      @try {
        [FBSession openActiveSessionWithReadPermissions:nil allowLoginUI:YES
          completionHandler:^(FBSession *session, FBSessionState status, NSError *error) {
            if (!error) {
              switch (status) {
                case FBSessionStateOpen:
                  facebook.accessToken = [FBSession activeSession].accessToken;
                  facebook.expirationDate = [FBSession activeSession].expirationDate;
                  dispatchHaxeEvent(START_SESSION_OPEN);
                  break;
                case FBSessionStateClosed:
                case FBSessionStateClosedLoginFailed:
                  closeSession();
                  dispatchHaxeEvent(START_SESSION_CLOSED);
                  break;
                default:
                  break;
              }
            } else {
              NSLog(@"openActiveSessionWithReadPermissions error %@", error);
              dispatchHaxeEvent(START_SESSION_ERROR);
            }
            startingSession = false;
          }];
      } @catch (NSException * e) {
        NSLog(@"could not log in to facebook %@", e);
        startingSession = false;
      }
    }
  }

  void closeSession() {
    @try {
      [[FBSession activeSession] closeAndClearTokenInformation];
      [FBSession setActiveSession:nil];
    } @catch (NSException * e) {
      NSLog(@"could not log out of facebook %@", e);
    }
  }

  void requestWritePermissions() {
    if ( !sessionActive() ) {
      dispatchHaxeEvent(WRITE_PERMISSIONS_FAILED);
      return;
    }

    if (!haveRequestedPublishPermissions) {
      NSArray *permissions = [[NSArray alloc] initWithObjects: @"publish_actions", @"publish_stream", nil];
      [[FBSession activeSession] reauthorizeWithPublishPermissions:permissions defaultAudience:FBSessionDefaultAudienceFriends
        completionHandler:^(FBSession *session, NSError* error) {
          if (!error) {
            dispatchHaxeEvent(WRITE_PERMISSIONS_GRANTED);
          } else {
            checkForOAuthError(error);
            dispatchHaxeEvent(WRITE_PERMISSIONS_FAILED);
          }
        }];
      haveRequestedPublishPermissions = true;
    }
  }

  void requestForMe() {
    if ( !sessionActive() ) {
      dispatchHaxeEvent(REQUEST_FOR_ME_FAIL);
      return;
    }

    // FIXME hack to get profile picture
    //[[FBRequest requestForMe] startWithCompletionHandler:
    NSDictionary *params = [[NSDictionary alloc] initWithObjectsAndKeys:@"id,name,first_name,last_name,username,picture",
                 @"fields", nil];
    [FBRequestConnection startWithGraphPath:@"me" parameters:params HTTPMethod:@"GET" 
      completionHandler:^(FBRequestConnection *connection, NSDictionary<FBGraphUser> *user, NSError *error) {
        if (!error) {
          NSError *e = nil;
          NSData *data = [NSJSONSerialization dataWithJSONObject:user options:nil error: &e];
          if (!e) {
            NSString *jsonStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            FBEvent evt(REQUEST_FOR_ME_SUCCESS, 0, 0, [jsonStr UTF8String]);
            facebook_send_event(evt);
          } else {
            dispatchHaxeEvent(REQUEST_FOR_ME_FAIL);
          }
        } else {
          checkForOAuthError(error);
          dispatchHaxeEvent(REQUEST_FOR_ME_FAIL);
        }
      }];
  }

  void graphRequest(const char *transactionId, const char *i_graphPath, const char *i_httpMethod,
      const char *i_paramsJSON) {
    if ( !sessionActive() ) {
      dispatchHaxeEvent(GRAPH_REQUEST_FAIL);
      return;
    }

    NSError *e = nil;
    NSData *data = [[[NSString alloc] initWithUTF8String:i_paramsJSON] dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableDictionary *params = [NSJSONSerialization JSONObjectWithData:data
      options:NSJSONReadingMutableContainers error: &e];

    NSString* graphPath = [[NSString alloc] initWithUTF8String:i_graphPath];
    NSString* method = [[NSString alloc] initWithUTF8String:i_httpMethod];

    [FBRequestConnection startWithGraphPath:graphPath parameters:params HTTPMethod:method
      completionHandler:^(FBRequestConnection *connection, id result, NSError *error) {
        NSString *jsonStr = [[NSString alloc] initWithString:@""];
        if (!error) {
          NSError *e = nil;
          NSData *resultData = [NSJSONSerialization dataWithJSONObject:result options:nil error: &e];
          if (!e) {
            jsonStr = [[NSString alloc] initWithData:resultData encoding:NSUTF8StringEncoding];
            FBEvent evt(GRAPH_REQUEST_SUCCESS, 0, 0, [jsonStr UTF8String]);
            facebook_send_event(evt);
          } else {
            dispatchHaxeEvent(GRAPH_REQUEST_FAIL);
          }
        } else {
          checkForOAuthError(error);
          dispatchHaxeEvent(GRAPH_REQUEST_FAIL);
        }

        const char *errorStr = (error != nil) ? [[error domain] UTF8String] : "";
        facebook_send_callback(transactionId, [jsonStr UTF8String], errorStr);
      }];
  }

  void invite(const char *transactionId, const char *i_msg) {
    nme::PauseAnimation();
    InviteDialogDelegate *delegate = [[InviteDialogDelegate alloc] init:transactionId];
    NSMutableDictionary* params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
      [[NSString alloc] initWithUTF8String:i_msg], @"message", nil];
    [facebook dialog:@"apprequests" andParams:params andDelegate:delegate];
  }

  void feedPost(const char *transactionId, const char *i_paramsJSON) {
    NSError *e = nil;
    NSData *data = [[[NSString alloc] initWithUTF8String:i_paramsJSON] dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableDictionary *params = [NSJSONSerialization JSONObjectWithData:data
      options:NSJSONReadingMutableContainers error: &e];

    /* TODO : add iOS 6 style feed posts
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    UIViewController *rootViewController = window.rootViewController;

    bool bDisplayedDialog = [FBNativeDialogs presentShareDialogModallyFrom:rootViewController
      initialText:@"Checkout my Friend Smash greatness!"
      image:nil url:nil handler:^(FBNativeDialogResult result, NSError *error) {}];
      */
    bool bDisplayedDialog = false;

    if (!bDisplayedDialog) {
      nme::PauseAnimation();
      FeedDialogDelegate *delegate = [[FeedDialogDelegate alloc] init:transactionId];
      [facebook dialog:@"feed" andParams:params andDelegate:delegate];
    }
  }

  void checkForOAuthError(NSError *error) {
    NSDictionary *userinfo= [error userInfo];
    if (userinfo) {
      NSDictionary *errorData = [userinfo valueForKey:@"com.facebook.sdk:ParsedJSONResponseKey"];
      NSString *type = [[[errorData valueForKey:@"body"] valueForKey:@"error"] valueForKey:@"type"];
      if([type isEqualToString:@"OAuthException"]){
        //closeSession();
        //startSession();
        dispatchHaxeEvent(START_SESSION_CLOSED);
        // TODO handle logging back in
      }
    }
  }

  bool sessionActive() {
    return [FBSession activeSession] != nil && [[FBSession activeSession] isOpen];
  }

  void dispatchHaxeEvent(EventType eventId) {
    FBEvent evt(eventId);
    facebook_send_event(evt);
  }

  void destroy() {
    [facebook release];
    [nmeAppActivator release];
  }

}
