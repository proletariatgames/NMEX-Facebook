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

package facebook;

import nme.events.EventDispatcher;
import nme.events.Event;

class Facebook extends EventDispatcher {

  public static inline var HTTP_POST:String = "POST";
  public static inline var HTTP_GET:String = "GET";
  private var callbacks:Hash< Dynamic -> String -> Void >;

  private static var s_instance:Facebook;

  function new() {
    super();
    facebook_set_event_handle(externEventHandle);
    facebook_set_callback_handle(externCallbackHandle);
    callbacks = new Hash< Dynamic -> String -> Void >();
  }

  public static function getInstance() : Facebook {
    if (s_instance == null) {
      s_instance = new Facebook();
    }
    return s_instance;
  }

  public function init(i_appId:String) : Void {
    facebook_init(i_appId);
  }

  public function startSession() : Void {
    facebook_start_session();
  }

  public function closeSession() : Void {
    facebook_close_session();
  }

  public function invite(i_msg:String, callbackFn:String -> String -> Void=null) : Void {
    var transactionId:String = addTransactionCallback(callbackFn);
    facebook_invite(transactionId, i_msg);
  }

  public function requestWritePermissions() : Void {
    facebook_request_write_permissions();
  }

  public function feedPost(params:Hash<String>, callbackFn:String -> String -> Void=null) : Void {
    var transactionId:String = addTransactionCallback(callbackFn);
    params = params != null ? params : new Hash<String>();
    facebook_feed_post(transactionId, haxe.Json.stringify(params));
  }

  public function graphRequest(i_graphPath:String, i_httpMethod:String=HTTP_GET, i_params:Hash<String>=null,
      callbackFn:String -> String -> Void=null) : Void {
    var transactionId:String = addTransactionCallback(callbackFn);
    i_params = i_params != null ? i_params : new Hash<String>();
    facebook_graph_request(transactionId, i_graphPath, i_httpMethod, haxe.Json.stringify(i_params));
  }

  public function requestForMe() : Void {
    facebook_request_for_me();
  }

  function createTransactionID() : String {
    // we do it this way to avoid scientific notation
    var tId:String = Std.string(Date.now().getTime()/1000) + Std.string(Math.random());
    var attempts:Int = 0;
    while ( callbacks.exists(tId) && attempts < 100 ) {
      tId = Std.string(Date.now().getTime()/1000) + Std.string(Math.random());
      attempts++;
    }
    return tId;
  }

  // adds callback and returns the transaction Id
  function addTransactionCallback(callbackFunction:String -> String -> Void) : String {
    if (callbackFunction != null) {
      var tId = createTransactionID();
      callbacks.set( tId, callbackFunction );
      return tId;
    }
    return null;
  }

  function externCallbackHandle(transactionId:String, data:String, error:String) {
    if (transactionId != null && callbacks.exists(transactionId)) {
      callbacks.get(transactionId)(data, error);
      callbacks.remove(transactionId);
    }
  }

  private function externEventHandle(inEvent:Dynamic){
    var type:Int = Std.int(Reflect.field( inEvent, "type" ) );
    var code:Int = Std.int(Reflect.field( inEvent, "code" ) );
    var value:Int = Std.int(Reflect.field( inEvent, "value" ) );
    var data:String = Std.string(Reflect.field( inEvent, "data" ) );
    var event:FBEvent = null;
    switch(type){
      case 0: event = new FBEvent(FBEvent.START_SESSION_OPEN, code, value, data);
      case 1: event = new FBEvent(FBEvent.START_SESSION_CLOSED, code, value, data);
      case 2: event = new FBEvent(FBEvent.START_SESSION_FAILED, code, value, data);
      case 3: event = new FBEvent(FBEvent.START_SESSION_ERROR, code, value, data);
      case 4: event = new FBEvent(FBEvent.REQUEST_FOR_ME_SUCCESS, code, value, data);
      case 5: event = new FBEvent(FBEvent.REQUEST_FOR_ME_FAIL, code, value, data);
      case 6: event = new FBEvent(FBEvent.GRAPH_REQUEST_SUCCESS, code, value, data);
      case 7: event = new FBEvent(FBEvent.GRAPH_REQUEST_FAIL, code, value, data);
      case 8: event = new FBEvent(FBEvent.WRITE_PERMISSIONS_GRANTED, code, value, data);
      case 9: event = new FBEvent(FBEvent.WRITE_PERMISSIONS_FAILED, code, value, data);
    }

    dispatchEvent(event);
  }

  static var facebook_set_event_handle = nme.Loader.load("facebook_set_event_handle",1);
  static var facebook_set_callback_handle = nme.Loader.load("facebook_set_callback_handle",1);
  static var facebook_init = nme.Loader.load("facebook_init",1);
  static var facebook_session_active = nme.Loader.load("facebook_session_active" ,0);
  static var facebook_write_enabled = nme.Loader.load("facebook_write_enabled" ,0);
  static var facebook_start_session = nme.Loader.load("facebook_start_session",0);
  static var facebook_close_session = nme.Loader.load("facebook_close_session",0);
  static var facebook_feed_post = nme.Loader.load("facebook_feed_post", 2);
  static var facebook_invite = nme.Loader.load("facebook_invite",2);
  static var facebook_request_write_permissions = nme.Loader.load("facebook_request_write_permissions", 0);
  static var facebook_graph_request = nme.Loader.load("facebook_graph_request", 4);
  static var facebook_request_for_me = nme.Loader.load("facebook_request_for_me", 0);
}
