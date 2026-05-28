/*
 * Copyright Core DF
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#ifndef COREAUTO_RESULT_H
#define COREAUTO_RESULT_H

#ifdef __cplusplus
extern "C" {
#endif

char *coreauto_missing_env(const char *vars);
char *coreauto_transport_error(const char *message);
void coreauto_json_free(char *json);

#ifdef __cplusplus
}
#endif

#endif
