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

#ifndef FBEVENT
#define FBEVENT

enum EventType{
   START_SESSION_OPEN,
   START_SESSION_CLOSED,
   START_SESSION_FAILED,
   START_SESSION_ERROR,
   REQUEST_FOR_ME_SUCCESS,
   REQUEST_FOR_ME_FAIL,
   GRAPH_REQUEST_SUCCESS,
   GRAPH_REQUEST_FAIL,
   WRITE_PERMISSIONS_GRANTED,
   WRITE_PERMISSIONS_FAILED,
};

struct FBEvent{

   FBEvent(EventType inType,int inCode=0,int inValue=0,const char *inData = "")
     :type(inType), code(inCode), value(inValue), data(inData){}

   EventType type;
   int       code;
   int       value;
   const char *data;
};

#endif
