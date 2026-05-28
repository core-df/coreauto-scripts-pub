// Copyright Core DF
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

//go:build !ibmmq

package ibmmqclient

import "github.com/core-df/coreauto-scripts-pub/queues/ibmmq/Go/internal/result"

func mqPut(_ string, _ []byte) result.Result {
	return result.MQUnavailable()
}

func mqGet(_ string, _ float64, _ int) result.Result {
	return result.MQUnavailable()
}
