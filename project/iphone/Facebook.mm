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

#include "FacebookSDK.h"
#include "Facebook.h"
#include "FBEvent.h"

namespace nme {
  void PauseAnimation();
  void ResumeAnimation();
}

namespace facebook {
  static bool sessionStarted = false;
  static bool facebookInitialized = false;
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
    if (facebook::facebookInitialized) {
      return [[FBSession activeSession] handleOpenURL:url];
    } else {
      return NO;
    }
  }
@end

@interface FacebookAppDelegate:NSObject
{
  const char *appId;
}
-(void)applicationActivated:(id)sender;
-(void)applicationWillTerminate:(id)sender;
@end

@implementation FacebookAppDelegate
  - (id)init:(const char *)aid {
    self = [super init];
    if (self) {
      appId = aid;
    }

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationActivated:)
      name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate:)
      name:UIApplicationWillTerminateNotification object:nil];
    return self;
  }

  - (void)applicationActivated:(id)sender {
    printf("Facebook.mm::applicationDidBecomeActive\n");
    [[FBSession activeSession] handleDidBecomeActive];
    [FBSettings publishInstall:[[NSString alloc] initWithUTF8String:appId]];
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

namespace facebook
{
  static bool haveRequestedPublishPermissions = false;
  static bool startingSession = false;
  FacebookAppDelegate *nmeAppActivator;
  NSMutableArray *connections;

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
  void checkFacebookError(NSError *error);

  void init(const char *i_appId) {
    connections = [[NSMutableArray alloc] init];
    [connections retain];
    NSString *appId = [[NSString alloc] initWithUTF8String:i_appId];
    [FBSession setDefaultAppID:appId];
    nmeAppActivator = [[FacebookAppDelegate alloc]init];
    [nmeAppActivator retain];
    facebookInitialized = true;
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
                  sessionStarted = true;
                  dispatchHaxeEvent(START_SESSION_OPEN);
                  break;
                case FBSessionStateClosed:
                case FBSessionStateClosedLoginFailed:
                  [session closeAndClearTokenInformation];
                  dispatchHaxeEvent(START_SESSION_CLOSED);
                  break;
                default:
                  break;
              }
            } else {
              checkFacebookError(error);
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

      [[FBSession activeSession] requestNewPublishPermissions:permissions defaultAudience:FBSessionDefaultAudienceFriends
        completionHandler:^(FBSession *session, NSError* error) {
          if (!error) {
            dispatchHaxeEvent(WRITE_PERMISSIONS_GRANTED);
          } else {
            checkFacebookError(error);
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

    NSDictionary *params = [[NSDictionary alloc] initWithObjectsAndKeys:@"id,name,first_name,last_name,username,picture",
                 @"fields", nil];
    FBRequestConnection *requestConnection = [FBRequestConnection startWithGraphPath:@"me"
      parameters:params HTTPMethod:@"GET"
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
          checkFacebookError(error);
          dispatchHaxeEvent(REQUEST_FOR_ME_FAIL);
        }

        // release connection
        [connections removeObject:connection];
        [connection release];
      }];

    [requestConnection retain];
    [connections addObject:requestConnection];
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

    NSString *graphPath = [[NSString alloc] initWithUTF8String:i_graphPath];
    NSString *method = [[NSString alloc] initWithUTF8String:i_httpMethod];

    FBRequestConnection *requestConnection = [FBRequestConnection startWithGraphPath:graphPath
      parameters:params HTTPMethod:method
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
          checkFacebookError(error);
          dispatchHaxeEvent(GRAPH_REQUEST_FAIL);
        }
        const char *errorStr = (error != nil) ? [[error domain] UTF8String] : "";
        facebook_send_callback(transactionId, [jsonStr UTF8String], errorStr);

        // release connection
        [connections removeObject:connection];
        [connection release];
      }];

    [requestConnection retain];
    [connections addObject:requestConnection];
  }

  NSDictionary *parseURLParams(NSString *query) {
    NSArray *pairs = [query componentsSeparatedByString:@"&"];
    NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
    for (NSString *pair in pairs) {
      NSArray *kv = [pair componentsSeparatedByString:@"="];
      NSString *val = [[kv objectAtIndex:1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
      [params setObject:val forKey:[kv objectAtIndex:0]];
    }
    return params;
  }

  void invite(const char *transactionId, const char *i_msg) {
    // passing FBSession is broken on ios 5
    FBSession *session = nil;
    float currentVersion = 6.0;
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= currentVersion) {
      session = [FBSession activeSession];
    }

    nme::PauseAnimation();
    [FBWebDialogs presentRequestsDialogModallyWithSession:session
      message:[[NSString alloc] initWithUTF8String:i_msg] title:nil parameters:nil
      handler:^(FBWebDialogResult result, NSURL *resultURL, NSError *error) {
        if (!error) {
          if (result != FBWebDialogResultDialogNotCompleted) {
            NSDictionary *urlParams = parseURLParams([resultURL query]);
            if ([urlParams valueForKey:@"request"]) {
              facebook_send_callback(transactionId, "", "");
            }
          }
        }
        nme::ResumeAnimation();
      }];
  }

  void feedPost(const char *transactionId, const char *i_paramsJSON) {
    // passing FBSession is broken on ios 5
    FBSession *session = nil;
    float currentVersion = 6.0;
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= currentVersion) {
      session = [FBSession activeSession];
    }

    NSError *e = nil;
    NSData *data = [[[NSString alloc] initWithUTF8String:i_paramsJSON] dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableDictionary *params = [NSJSONSerialization JSONObjectWithData:data
      options:NSJSONReadingMutableContainers error: &e];

    nme::PauseAnimation();
    [FBWebDialogs presentFeedDialogModallyWithSession:session parameters:params
      handler:^(FBWebDialogResult result, NSURL *resultURL, NSError *error) {
        if (!error) {
          if (result != FBWebDialogResultDialogNotCompleted) {
            NSDictionary *urlParams = parseURLParams([resultURL query]);
            if ([urlParams valueForKey:@"request"]) {
              facebook_send_callback(transactionId, "", "");
            }
          }
        }
        nme::ResumeAnimation();
      }];


    /* TODO : add iOS 6 style feed posts
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    UIViewController *rootViewController = window.rootViewController;

    bool bDisplayedDialog = [FBNativeDialogs presentShareDialogModallyFrom:rootViewController
      initialText:@"Checkout my Friend Smash greatness!"
      image:nil url:nil handler:^(FBNativeDialogResult result, NSError *error) {}];
    */
  }

  void checkFacebookError(NSError *error) {
    NSString *alertMessage;
    NSString *alertTitle;
    if (error.fberrorShouldNotifyUser) {
      alertTitle = @"Facebook Error";
      alertMessage = error.fberrorUserMessage;
    } else if (error.fberrorCategory == FBErrorCategoryUserCancelled) {
      NSLog(@"User denied permission to your app.");
    } else if (error.fberrorCategory == FBErrorCategoryAuthenticationReopenSession) {
      alertTitle = @"Facebook Error";
      alertMessage = @"Your current Facebook session is no longer valid. Please log in again.";
      // Tell client session is no longer valid
      closeSession();
      dispatchHaxeEvent(START_SESSION_CLOSED);
    } else {
      NSLog(@"Unexpected Facebook Error:%@", error);
    }

    if (alertMessage) {
      [[[UIAlertView alloc] initWithTitle:alertTitle message:alertMessage delegate:nil cancelButtonTitle:@"OK"
        otherButtonTitles:nil] show];
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
    [connections release];
    [nmeAppActivator release];
  }

}
