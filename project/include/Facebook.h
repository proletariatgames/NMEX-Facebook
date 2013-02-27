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

#ifndef FACEBOOK
#define FACEBOOK

namespace facebook
{
  void init(const char* i_appId);
  bool sessionActive();
  void startSession();
  void closeSession();
  void requestWritePermissions();

  void feedPost(const char *transactionId, const char *i_paramsJSON);
  void invite(const char *transactionId, const char *i_msg);
  void requestForMe();
  void graphRequest(const char *transactionId, const char *i_graphPath, const char *i_httpMethod,
      const char *i_paramsJSON);
}

#endif
