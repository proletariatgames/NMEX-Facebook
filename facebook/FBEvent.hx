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

import nme.events.Event;

class FBEvent extends Event {

  public static inline var START_SESSION_OPEN:String = "start_session_open";
  public static inline var START_SESSION_CLOSED:String = "start_session_closed";
  public static inline var START_SESSION_FAILED:String = "start_session_failed";
  public static inline var START_SESSION_ERROR:String = "start_session_error";
  public static inline var REQUEST_FOR_ME_SUCCESS:String = "request_for_me_success";
  public static inline var REQUEST_FOR_ME_FAIL:String = "request_for_me_fail";
  public static inline var GRAPH_REQUEST_SUCCESS:String = "graph_request_success";
  public static inline var GRAPH_REQUEST_FAIL:String = "graph_request_fail";
  public static inline var WRITE_PERMISSIONS_GRANTED:String = "write_permissions_granted";
  public static inline var WRITE_PERMISSIONS_FAILED:String = "write_permissions_failed";

  public var EventID:Int;
  public var code:Int;
  public var value:Int;
  public var data:String;

  public function new(type:String, code:Int, value:Int, data:String) {
    super(type);
    this.code = code;
    this.value = value;
    this.data = data;
  }
}
