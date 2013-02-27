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

#include <stdio.h>
#include <hx/CFFI.h>
#include "Facebook.h"
#include "FBEvent.h"

using namespace facebook;

AutoGCRoot *facebookEventHandler = 0;
AutoGCRoot *facebookCallbackHandler = 0;

static value facebook_set_event_handle(value onEvent)
{
  facebookEventHandler = new AutoGCRoot(onEvent);
  return alloc_bool(true);
}
DEFINE_PRIM(facebook_set_event_handle,1);

static value facebook_set_callback_handle(value onCallback)
{
  facebookCallbackHandler = new AutoGCRoot(onCallback);
  return alloc_bool(true);
}
DEFINE_PRIM(facebook_set_callback_handle,1);

static value facebook_init(value i_appId) {
  printf("ExternalInterface::facebook_init()\n");
  init(val_string(i_appId));
  return alloc_null();
}
DEFINE_PRIM(facebook_init, 1);

static value facebook_session_active() {
  printf("ExternalInterface::facebook_session_active()\n");
  return alloc_bool(sessionActive());
}
DEFINE_PRIM(facebook_session_active, 0);

static value facebook_start_session() {
  printf("ExternalInterface::facebook_start_session()\n");
  startSession();
  return alloc_null();
}
DEFINE_PRIM(facebook_start_session, 0);

static value facebook_close_session() {
  printf("ExternalInterface::facebook_close_session()\n");
  closeSession();
  return alloc_null();
}
DEFINE_PRIM(facebook_close_session, 0);

static value facebook_invite(value transactionId, value i_msg) {
  printf("ExternalInterface::facebook_invite()\n");
  invite(val_string(transactionId), val_string(i_msg));
  return alloc_null();
}
DEFINE_PRIM(facebook_invite, 2);

static value facebook_request_write_permissions() {
  printf("ExternalInterface::facebook_request_write_permissions()\n");
  requestWritePermissions();
  return alloc_null();
}
DEFINE_PRIM(facebook_request_write_permissions,0);

static value facebook_feed_post(value transactionId, value i_paramsJSON) {
  printf("ExternalInterface::facebook_feed_post()\n");
  feedPost(val_string(transactionId), val_string(i_paramsJSON));
  return alloc_null();
}
DEFINE_PRIM(facebook_feed_post,2);

static value facebook_graph_request(value transactionId, value i_graphPath, value i_httpMethod, value i_paramsJSON) {
  printf("ExternalInterface::facebook_graph_request()\n");
  graphRequest(val_string(transactionId), val_string(i_graphPath), val_string(i_httpMethod), val_string(i_paramsJSON));
  return alloc_null();
}
DEFINE_PRIM(facebook_graph_request,4);

static value facebook_request_for_me() {
  printf("ExternalInterface::facebook_request_for_me()\n");
  requestForMe();
  return alloc_null();
}
DEFINE_PRIM(facebook_request_for_me,0);

extern "C"
{
  void facebook_main() {
  }

  int facebook_register_prims() {
    facebook_main();
    return 0;
  }

  void facebook_send_event(FBEvent &event) {
    printf("Send Event: %i\n",event.type);

    value o = alloc_empty_object();
    alloc_field(o,val_id("type"),alloc_int(event.type));
    alloc_field(o,val_id("code"),alloc_int(event.code));
    alloc_field(o,val_id("value"),alloc_int(event.value));
    alloc_field(o,val_id("data"),alloc_string(event.data));

    val_call1(facebookEventHandler->get(),o);
  }

  void facebook_send_callback(const char *tId, const char *data, const char *error) {
    val_call3(facebookCallbackHandler->get(), alloc_string(tId), alloc_string(data), alloc_string(error) );
  }
}
