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

//go:build ibmmq

package ibmmqclient

import (
	"fmt"
	"os"

	"github.com/core-df/coreauto-scripts-pub/queues/ibmmq/Go/internal/result"
	"github.com/ibm-messaging/mq-golang/v5/ibmmq"
)

func mqConnect() (ibmmq.MQQueueManager, error) {
	host := os.Getenv("MQ_HOST")
	port := os.Getenv("MQ_PORT")
	if port == "" {
		port = "1414"
	}
	qmgrName := os.Getenv("MQ_QUEUE_MANAGER")
	channel := os.Getenv("MQ_CHANNEL")
	if channel == "" {
		channel = "SYSTEM.DEF.SVRCONN"
	}
	user := os.Getenv("MQ_USER")
	password := os.Getenv("MQ_PASSWORD")

	if host == "" || qmgrName == "" {
		return ibmmq.MQQueueManager{}, fmt.Errorf("MQ_HOST and MQ_QUEUE_MANAGER required")
	}

	connName := fmt.Sprintf("%s(%s)", host, port)
	cd := ibmmq.NewMQCD()
	cd.ChannelName = channel
	cd.ConnectionName = connName
	cd.ChannelType = ibmmq.MQCHT_CLNT
	cd.TransportType = ibmmq.MQXPT_TCP

	if user != "" {
		return ibmmq.Conn(qmgrName, cd, user, password)
	}
	return ibmmq.Conn(qmgrName, cd)
}

func mqPut(qname string, payload []byte) result.Result {
	qmgr, err := mqConnect()
	if err != nil {
		return result.TransportError(err.Error())
	}
	defer qmgr.Disc()

	mqod := ibmmq.NewMQOD()
	mqod.ObjectType = ibmmq.MQOT_Q
	mqod.ObjectName = qname
	qObject, err := qmgr.Open(mqod, ibmmq.MQOO_OUTPUT)
	if err != nil {
		return result.TransportError(err.Error())
	}
	defer qObject.Close(0)

	putmqmd := ibmmq.NewMQMD()
	pmo := ibmmq.NewMQPMO()
	pmo.Options = ibmmq.MQPMO_NO_SYNCPOINT

	if err := qObject.Put(putmqmd, pmo, payload); err != nil {
		return result.TransportError(err.Error())
	}
	return result.Result{StatusCode: 200}
}

func mqGet(qname string, timeoutSec float64, maxMessages int) result.Result {
	qmgr, err := mqConnect()
	if err != nil {
		return result.TransportError(err.Error())
	}
	defer qmgr.Disc()

	mqod := ibmmq.NewMQOD()
	mqod.ObjectType = ibmmq.MQOT_Q
	mqod.ObjectName = qname
	qObject, err := qmgr.Open(mqod, ibmmq.MQOO_INPUT_SHARED)
	if err != nil {
		return result.TransportError(err.Error())
	}
	defer qObject.Close(0)

	gmo := ibmmq.NewMQGMO()
	gmo.Options = ibmmq.MQGMO_WAIT | ibmmq.MQGMO_NO_SYNCPOINT
	gmo.WaitInterval = int32(timeoutSec * 1000)

	messages := make([]map[string]any, 0, maxMessages)
	buffer := make([]byte, 32768)

	for i := 0; i < maxMessages; i++ {
		getmqmd := ibmmq.NewMQMD()
		datalen, err := qObject.Get(getmqmd, gmo, buffer)
		if err != nil {
			if mqret, ok := err.(*ibmmq.MQReturn); ok && mqret.MQRC == ibmmq.MQRC_NO_MSG_AVAILABLE {
				break
			}
			return result.TransportError(err.Error())
		}
		messages = append(messages, map[string]any{
			"queue": qname,
			"value": decode(buffer[:datalen]),
		})
		// After first message, use shorter wait for additional messages.
		if i == 0 {
			waitMs := int(timeoutSec * 1000)
			if waitMs < 100 {
				waitMs = 100
			}
			gmo.WaitInterval = int32(waitMs)
		}
	}
	return result.Result{StatusCode: 200, Messages: messages}
}
